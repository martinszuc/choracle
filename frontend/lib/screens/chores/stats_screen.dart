import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/chores_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/shared/loading_spinner.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    final memberId = context.read<AppProvider>().currentMember?.id;
    if (memberId != null) {
      context.read<ChoresProvider>().fetchStats(memberId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chores = context.watch<ChoresProvider>();
    final stats = chores.stats;

    return Scaffold(
      appBar: AppBar(title: const Text('Your Stats')),
      body: chores.isLoading
          ? const LoadingSpinner()
          : stats == null
              ? const EmptyState(icon: Icons.bar_chart_outlined, message: 'No data yet')
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _statsRow('Total completed', stats.completedCount.toString()),
                    _statsRow('Taken over', stats.takenOverCount.toString()),
                    const SizedBox(height: 24),
                    const Text('Weekly completions', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(height: 180, child: _WeeklyChart(history: stats.weeklyHistory)),
                    const SizedBox(height: 24),
                    const Text('Original vs Taken Over', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(height: 180, child: _PieChart(stats: stats.completedCount, takenOver: stats.takenOverCount)),
                    const SizedBox(height: 24),
                    const Text('Daily completions (last 7 days)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(height: 180, child: _DailyChart(history: stats.dailyHistory)),
                  ],
                ),
    );
  }

  Widget _statsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final Map<String, int> history;
  const _WeeklyChart({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const EmptyState(icon: Icons.show_chart, message: 'No weekly data yet');
    }
    final sorted = history.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final spots = sorted
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value.toDouble()))
        .toList();

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: kPrimaryColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= sorted.length) return const SizedBox();
                return Text(sorted[i].key.substring(5), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

class _PieChart extends StatelessWidget {
  final int stats;
  final int takenOver;
  const _PieChart({required this.stats, required this.takenOver});

  @override
  Widget build(BuildContext context) {
    final original = stats - takenOver;
    if (stats == 0) {
      return const EmptyState(icon: Icons.pie_chart_outline, message: 'No data yet');
    }
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
            value: original.toDouble(),
            title: 'Original\n$original',
            color: kPrimaryColor,
            radius: 70,
            titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
          ),
          PieChartSectionData(
            value: takenOver.toDouble(),
            title: 'Taken\n$takenOver',
            color: kSecondaryColor,
            radius: 70,
            titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
        sectionsSpace: 2,
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  final Map<String, int> history;
  const _DailyChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final last7 = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    if (history.isEmpty) {
      return const EmptyState(icon: Icons.bar_chart, message: 'No daily data yet');
    }

    final groups = last7.asMap().entries.map((e) {
      final key = DateFormat('yyyy-MM-dd').format(e.value);
      final count = history[key] ?? 0;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(toY: count.toDouble(), color: kPrimaryColor, width: 16, borderRadius: BorderRadius.circular(4)),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        barGroups: groups,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= last7.length) return const SizedBox();
                return Text(DateFormat('E').format(last7[i]), style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
