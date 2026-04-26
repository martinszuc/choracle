from rest_framework import serializers
from .models import (
    Household, Member, DefaultChore, Chore, MemberStats,
    FavoriteItem, ShoppingItem, Transaction, Debt,
)


class MemberSerializer(serializers.ModelSerializer):
    class Meta:
        model = Member
        fields = ['id', 'name', 'color', 'household']
        read_only_fields = ['id', 'color']


class HouseholdSerializer(serializers.ModelSerializer):
    members = MemberSerializer(many=True, read_only=True)

    class Meta:
        model = Household
        fields = ['id', 'name', 'members']


class MemberNestedSerializer(serializers.ModelSerializer):
    class Meta:
        model = Member
        fields = ['id', 'name', 'color']


class DefaultChoreSerializer(serializers.ModelSerializer):
    assigned_to = MemberNestedSerializer(read_only=True)
    assigned_to_id = serializers.UUIDField(write_only=True, required=False, allow_null=True)

    class Meta:
        model = DefaultChore
        fields = ['id', 'name', 'assigned_to', 'assigned_to_id', 'frequency_days', 'start_date', 'last_generated', 'household']
        read_only_fields = ['id', 'last_generated']

    def create(self, validated_data):
        assigned_id = validated_data.pop('assigned_to_id', None)
        member = Member.objects.get(id=assigned_id) if assigned_id else None
        return DefaultChore.objects.create(assigned_to=member, **validated_data)


class ChoreSerializer(serializers.ModelSerializer):
    assigned_to = MemberNestedSerializer(read_only=True)
    assigned_to_id = serializers.UUIDField(write_only=True, required=False, allow_null=True)
    original_assigned_to = MemberNestedSerializer(read_only=True)
    completed_by = MemberNestedSerializer(read_only=True)

    class Meta:
        model = Chore
        fields = [
            'id', 'name', 'household',
            'assigned_to', 'assigned_to_id',
            'original_assigned_to',
            'completed', 'completed_by', 'completed_at',
            'week_identifier', 'created_at',
        ]
        read_only_fields = ['id', 'completed', 'completed_by', 'completed_at', 'week_identifier', 'created_at', 'original_assigned_to']

    def create(self, validated_data):
        assigned_id = validated_data.pop('assigned_to_id', None)
        member = Member.objects.get(id=assigned_id) if assigned_id else None
        chore = Chore.objects.create(
            assigned_to=member,
            original_assigned_to=member,
            **validated_data,
        )
        return chore


class MemberStatsSerializer(serializers.ModelSerializer):
    class Meta:
        model = MemberStats
        fields = ['member', 'completed_count', 'taken_over_count', 'weekly_history', 'daily_history']


class FavoriteItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = FavoriteItem
        fields = ['id', 'name', 'household']
        read_only_fields = ['id']


class ShoppingItemSerializer(serializers.ModelSerializer):
    created_by = MemberNestedSerializer(read_only=True)
    created_by_id = serializers.UUIDField(write_only=True)
    purchased_by = MemberNestedSerializer(read_only=True)

    class Meta:
        model = ShoppingItem
        fields = [
            'id', 'name', 'quantity', 'purchased',
            'created_by', 'created_by_id',
            'purchased_by',
            'debt_option', 'linked_transaction',
            'household', 'created_at',
        ]
        read_only_fields = ['id', 'purchased_by', 'linked_transaction', 'created_at']

    def create(self, validated_data):
        created_by_id = validated_data.pop('created_by_id')
        member = Member.objects.get(id=created_by_id)
        return ShoppingItem.objects.create(created_by=member, **validated_data)


class TransactionSerializer(serializers.ModelSerializer):
    creditor = MemberNestedSerializer(read_only=True)
    creditor_id = serializers.UUIDField(write_only=True)
    participants = MemberNestedSerializer(many=True, read_only=True)
    participant_ids = serializers.ListField(
        child=serializers.UUIDField(), write_only=True
    )
    per_person_share = serializers.SerializerMethodField()

    class Meta:
        model = Transaction
        fields = [
            'id', 'household',
            'creditor', 'creditor_id',
            'participants', 'participant_ids',
            'amount', 'description',
            'is_recurring', 'recurrence_interval',
            'next_payment_date', 'start_date',
            'is_settlement', 'created_at',
            'per_person_share',
        ]
        read_only_fields = ['id', 'is_settlement', 'created_at', 'next_payment_date']

    def get_per_person_share(self, obj):
        count = obj.participants.count()
        if count == 0:
            return str(obj.amount)
        return str(round(obj.amount / count, 2))

    def create(self, validated_data):
        creditor_id = validated_data.pop('creditor_id')
        participant_ids = validated_data.pop('participant_ids', [])
        creditor = Member.objects.get(id=creditor_id)
        transaction = Transaction.objects.create(creditor=creditor, **validated_data)
        participants = Member.objects.filter(id__in=participant_ids)
        transaction.participants.set(participants)
        return transaction

    def update(self, instance, validated_data):
        creditor_id = validated_data.pop('creditor_id', None)
        participant_ids = validated_data.pop('participant_ids', None)
        if creditor_id:
            instance.creditor = Member.objects.get(id=creditor_id)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if participant_ids is not None:
            instance.participants.set(Member.objects.filter(id__in=participant_ids))
        return instance


class DebtAggregatedSerializer(serializers.Serializer):
    debtor_id = serializers.UUIDField()
    debtor_name = serializers.CharField()
    debtor_color = serializers.CharField()
    creditor_id = serializers.UUIDField()
    creditor_name = serializers.CharField()
    creditor_color = serializers.CharField()
    amount = serializers.DecimalField(max_digits=10, decimal_places=2)
