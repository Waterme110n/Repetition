import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_student.dart';
import 'all_student.dart';
import 'main.dart';

class WeeklyStat {
  final DateTime weekStartDate;
  final double totalEarned;
  final int totalLessons;
  final bool assumedly;

  WeeklyStat({
    required this.weekStartDate,
    required this.totalEarned,
    required this.totalLessons,
    required this.assumedly,
  });

  factory WeeklyStat.fromJson(Map<String, dynamic> json) {
    return WeeklyStat(
      weekStartDate: DateTime.parse(json['week_start_date'] as String),
      totalEarned: (json['total_earned'] as num).toDouble(),
      totalLessons: json['total_lessons'] as int,
      assumedly: json['assumedly'] as bool,
    );
  }
}

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<WeeklyStat> _stats = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('weekly_stats')
          .select()
          .order('week_start_date', ascending: false); // новые сверху

      final List<dynamic> data = response;

      setState(() {
        _stats = data.map((json) => WeeklyStat.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки статистики: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDateRange(DateTime start) {
    final end = start.add(const Duration(days: 6));
    final formatter = DateFormat('d MMMM', 'ru');
    final year = start.year;
    return '${formatter.format(start)} — ${formatter.format(end)} $year';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: const Text('Статистика'),
        centerTitle: true,
        elevation: 0,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.pinkAccent),
              child: Text(
                'Меню',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Календарь'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CalendarPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Все ученики'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AllStudentScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Добавить ученика'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddStudentScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Статистика'),
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      )
          : _stats.isEmpty
          ? const Center(
        child: Text(
          'Нет данных за недели',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _stats.length,
          itemBuilder: (context, index) {
            final stat = _stats[index];
            return _buildStatCard(stat);
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(WeeklyStat stat) {
    final isForecast = stat.assumedly;

    final backgroundColor = isForecast
        ? Colors.amber.shade50
        : Colors.green.shade50;

    final borderColor = isForecast
        ? Colors.amber.shade400
        : Colors.green.shade400;

    final textColor = isForecast
        ? Colors.amber.shade900
        : Colors.green.shade900;

    final labelColor = isForecast
        ? Colors.amber.shade700
        : Colors.green.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _formatDateRange(stat.weekStartDate),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isForecast ? Colors.amber : Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isForecast ? 'Прогноз' : 'Факт',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  icon: Icons.event,
                  label: 'Занятий',
                  value: stat.totalLessons.toString(),
                  labelColor: labelColor,
                  valueColor: textColor,
                ),
                _buildInfoItem(
                  icon: Icons.payments,
                  label: 'Сумма',
                  value: '${stat.totalEarned.toStringAsFixed(2)} BYN',
                  labelColor: labelColor,
                  valueColor: textColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color labelColor,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: labelColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: labelColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}