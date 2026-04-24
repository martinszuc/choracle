class MemberStats {
  final String memberId;
  final int completedCount;
  final int takenOverCount;
  final Map<String, int> weeklyHistory;
  final Map<String, int> dailyHistory;

  const MemberStats({
    required this.memberId,
    required this.completedCount,
    required this.takenOverCount,
    required this.weeklyHistory,
    required this.dailyHistory,
  });

  factory MemberStats.fromJson(Map<String, dynamic> json) => MemberStats(
        memberId: json['member'] as String,
        completedCount: json['completed_count'] as int,
        takenOverCount: json['taken_over_count'] as int,
        weeklyHistory: Map<String, int>.from(
          (json['weekly_history'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ),
        ),
        dailyHistory: Map<String, int>.from(
          (json['daily_history'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ),
        ),
      );
}
