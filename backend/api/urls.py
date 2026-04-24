from django.urls import path
from . import views

urlpatterns = [
    # Household & Members
    path('household/', views.household_detail),
    path('members/', views.member_create),
    path('members/<uuid:pk>/', views.member_delete),

    # Chores
    path('chores/', views.chore_list_create),
    path('chores/<uuid:pk>/complete/', views.chore_complete),
    path('chores/<uuid:pk>/assign/', views.chore_assign),
    path('chores/<uuid:pk>/', views.chore_delete),

    # Default Chores
    path('default-chores/', views.default_chore_list_create),
    path('default-chores/<uuid:pk>/', views.default_chore_delete),

    # Stats
    path('stats/', views.stats_detail),

    # Shopping
    path('shopping-items/', views.shopping_item_list_create),
    path('shopping-items/<uuid:pk>/', views.shopping_item_detail),

    # Favorites
    path('favorite-items/', views.favorite_item_list_create),
    path('favorite-items/<uuid:pk>/', views.favorite_item_delete),

    # Transactions
    path('transactions/', views.transaction_list_create),
    path('transactions/recurring/', views.transaction_recurring_list),
    path('transactions/<uuid:pk>/', views.transaction_detail),
    path('transactions/<uuid:pk>/can-edit/', views.transaction_can_edit),

    # Debts
    path('debts/', views.debt_list),
    path('debts/settle/', views.debt_settle),
]
