// lib/screens/all_student.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_student.dart';
import 'edit_student.dart';
import 'main.dart';

class AllStudentScreen extends StatefulWidget {
  const AllStudentScreen({super.key});

  @override
  State<AllStudentScreen> createState() => _AllStudentScreenState();
}

class _AllStudentScreenState extends State<AllStudentScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = false;
  List<Map<String, dynamic>> _studentsWithSchedule = [];

  @override
  void initState() {
    super.initState();
    _fetchStudentsWithSchedule();
  }

  Future<void> _fetchStudentsWithSchedule() async {
    setState(() => _isLoading = true);

    try {
      final studentsResponse = await supabase
          .from('student')
          .select('*')
          .order('id', ascending: true);

      if (studentsResponse.isEmpty) {
        setState(() {
          _studentsWithSchedule = [];
          _isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> result = [];

      for (final student in studentsResponse) {
        // Получаем расписание для каждого ученика
        final scheduleResponse = await supabase
            .from('weekly_schedule')
            .select('*')
            .eq('student_id', student['id'])
            .order('day_of_week', ascending: true);

        final singleLessonsResponse = await supabase
            .from('single_lessons')
            .select('*')
            .eq('student_id', student['id'])
            .order('date', ascending: true);

        // Получаем исключения расписания через расписание
        final scheduleExceptions = [];
        for (final schedule in scheduleResponse) {
          final scheduleId = schedule['id'] as int;
          final exceptionsResponse = await supabase
              .from('schedule_exceptions')
              .select('*')
              .eq('schedule_id', scheduleId);

          for (final exception in exceptionsResponse) {
            scheduleExceptions.add({
              'id': exception['id'],
              'schedule_id': scheduleId,
              'day_of_week': schedule['day_of_week'],
              'start_time': schedule['start_time'],
              'end_time': schedule['end_time'],
              'status': exception['status'],
              'date': exception['date'], // ДОБАВЛЯЕМ ДАТУ ИСКЛЮЧЕНИЯ
              'new_day': exception['new_day'],
              'new_start_time': exception['new_start_time'],
              'new_end_time': exception['new_end_time'],
            });
          }
        }

        // Формируем объект ученика с расписанием
        final studentWithSchedule = {
          'student': {
            'id': student['id'],
            'name': student['name'],
            'description': student['description'],
            'price_30_min': student['price_30_min'],
          },
          'schedule': scheduleResponse.map((schedule) {
            return {
              'id': schedule['id'],
              'day_of_week': schedule['day_of_week'],
              'start_time': schedule['start_time'],
              'end_time': schedule['end_time'],
            };
          }).toList(),
          'single_lessons': singleLessonsResponse.map((lesson) {
            return {
              'id': lesson['id'],
              'date': lesson['date'],
              'start_time': lesson['start_time'],
              'end_time': lesson['end_time'],
              'type': 'single',
            };
          }).toList(),
          'schedule_exceptions': scheduleExceptions,
        };

        result.add(studentWithSchedule);
      }

      setState(() {
        _studentsWithSchedule = result;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки: $e');
      setState(() => _isLoading = false);
    }
  }

  // УДАЛЕНИЕ УЧЕНИКА
  Future<void> _deleteStudent(int studentId, String studentName) async {
    // Показываем диалог подтверждения
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение удаления'),
        content: Text('Вы уверены, что хотите удалить ученика "$studentName"?\n\nЭто действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Удаляем ученика (все связанные записи удалятся каскадно из-за ON DELETE CASCADE)
      await supabase
          .from('student')
          .delete()
          .eq('id', studentId);

      // Обновляем список
      await _fetchStudentsWithSchedule();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ученик "$studentName" успешно удален'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Ошибка удаления: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка удаления ученика: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  String _getDayName(int dayNumber) {
    switch (dayNumber) {
      case 1:
        return 'ПН';
      case 2:
        return 'ВТ';
      case 3:
        return 'СР';
      case 4:
        return 'ЧТ';
      case 5:
        return 'ПТ';
      case 6:
        return 'СБ';
      case 7:
        return 'ВС';
      default:
        return '';
    }
  }

  String _formatTime(String time) {
    if (time.length >= 5) {
      return time.substring(0, 5);
    }
    return time;
  }

  String _formatDate(String dateString) {
    try {
      final parts = dateString.split('-');
      if (parts.length >= 3) {
        return '${parts[2]}.${parts[1]}';
      }
      return dateString;
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateWithWeekday(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '--.--';

    try {
      final date = DateTime.parse(dateString);
      final dayOfWeek = date.weekday;
      final dayName = _getDayName(dayOfWeek);
      final formattedDate = _formatDate(dateString);

      return '$dayName $formattedDate';
    } catch (e) {
      return _formatDate(dateString);
    }
  }

  String _formatExceptionDate(String? dateString) {
    if (dateString == null) return '--.--';
    return _formatDate(dateString);
  }

  // Расчет стоимости занятия
  double _calculateLessonCost(
      double pricePer30Min,
      String startTime,
      String endTime,
      ) {
    try {
      // Конвертируем время в минуты
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');

      if (startParts.length >= 2 && endParts.length >= 2) {
        final startHour = int.tryParse(startParts[0]) ?? 0;
        final startMinute = int.tryParse(startParts[1]) ?? 0;
        final endHour = int.tryParse(endParts[0]) ?? 0;
        final endMinute = int.tryParse(endParts[1]) ?? 0;

        final startTotal = startHour * 60 + startMinute;
        final endTotal = endHour * 60 + endMinute;

        final duration = endTotal - startTotal;
        if (duration <= 0) return 0;

        final cost = (duration / 30) * pricePer30Min;
        return cost;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Получение иконки для статуса исключения
  IconData _getExceptionIcon(String status) {
    switch (status) {
      case 'declined':
        return Icons.cancel;
      case 'replaced':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  // Получение цвета для статуса исключения
  Color _getExceptionColor(String status) {
    switch (status) {
      case 'declined':
        return Colors.red;
      case 'replaced':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  // Получение текста статуса исключения
  String _getExceptionStatusText(String status) {
    switch (status) {
      case 'declined':
        return 'Отменено';
      case 'replaced':
        return 'Перенесено';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Все ученики')),
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
              selected: true,
              onTap: () {
                Navigator.pop(context);
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
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _studentsWithSchedule.isEmpty
          ? const Center(child: Text('Нет учеников'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _studentsWithSchedule.length,
        itemBuilder: (context, index) {
          final studentData = _studentsWithSchedule[index];
          final student = studentData['student'] as Map<String, dynamic>;
          final schedule = studentData['schedule'] as List<dynamic>;
          final singleLessons =
          studentData['single_lessons'] as List<dynamic>;
          final scheduleExceptions =
          studentData['schedule_exceptions'] as List<dynamic>;
          final pricePer30Min = (student['price_30_min'] as num)
              .toDouble();

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Верхняя часть с именем и кнопками
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 0),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                crossAxisAlignment:
                                CrossAxisAlignment.center,
                                children: [
                                  // Имя слева
                                  Flexible(
                                    fit: FlexFit.loose,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Text(
                                        student['name'] ?? 'Без имени',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Кнопки
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 12),

                                      // Цена
                                      Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius:
                                          BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${student['price_30_min']} BYN',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.blue[800],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),

                                      IconButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => EditStudentScreen(studentId: student['id']),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                          size: 24,
                                        ),
                                        padding: const EdgeInsets.only(
                                          bottom: 0,
                                        ),
                                        constraints:
                                        const BoxConstraints(),
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteStudent(
                                          student['id'] as int,
                                          student['name'] as String,
                                        ),
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          size: 24,
                                        ),
                                        padding: const EdgeInsets.only(
                                          bottom: 0,
                                        ),
                                        constraints:
                                        const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Описание
                            if (student['description'] != null &&
                                (student['description'] as String)
                                    .isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(
                                  student['description'] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),

                  // Разделительная линия
                  if (schedule.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: Colors.grey),
                    ),

                  // Заголовок списка занятий
                  if (schedule.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Расписание занятий:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Список занятий
                  if (schedule.isNotEmpty)
                    ...schedule.map((item) {
                      final day = item['day_of_week'] as int;
                      final startTime = _formatTime(
                        item['start_time'] as String,
                      );
                      final endTime = _formatTime(
                        item['end_time'] as String,
                      );
                      final cost = _calculateLessonCost(
                        pricePer30Min,
                        item['start_time'] as String,
                        item['end_time'] as String,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            // День недели
                            Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getDayName(day),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[800],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Время начала
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Начало',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    startTime,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Время окончания
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Конец',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    endTime,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Стоимость
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Стоимость',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${cost.toStringAsFixed(2)} BYN',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                  // Разделительная линия для отдельных занятий
                  if (singleLessons.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: Colors.grey),
                    ),

                  // Заголовок отдельных занятий
                  if (singleLessons.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Отдельные занятия:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Список отдельных занятий
                  if (singleLessons.isNotEmpty)
                    ...singleLessons.map((item) {
                      final date = _formatDate(item['date'] as String);
                      final startTime = _formatTime(
                        item['start_time'] as String,
                      );
                      final endTime = _formatTime(
                        item['end_time'] as String,
                      );
                      final cost = _calculateLessonCost(
                        pricePer30Min,
                        item['start_time'] as String,
                        item['end_time'] as String,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            // Дата (вместо дня недели)
                            Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                date,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange[800],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Время начала
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Начало',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    startTime,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Время окончания
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Конец',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    endTime,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Стоимость
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Стоимость',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${cost.toStringAsFixed(2)} BYN',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                  // Разделительная линия для исключений
                  if (scheduleExceptions.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1, color: Colors.grey),
                    ),

                  // Заголовок исключений
                  if (scheduleExceptions.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Исключения в расписании:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Список исключений
                  if (scheduleExceptions.isNotEmpty)
                    ...scheduleExceptions.map((item) {
                      final day = item['day_of_week'] as int;
                      final startTime = _formatTime(
                        item['start_time'] as String,
                      );
                      final endTime = _formatTime(
                        item['end_time'] as String,
                      );
                      final status = item['status'] as String;
                      final exceptionDate = item['date'] as String?; // ДАТА ИСКЛЮЧЕНИЯ
                      final newDay = item['new_day'] as String?;
                      final newStartTime = item['new_start_time'] != null
                          ? _formatTime(item['new_start_time'] as String)
                          : null;
                      final newEndTime = item['new_end_time'] != null
                          ? _formatTime(item['new_end_time'] as String)
                          : null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getExceptionColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getExceptionColor(status).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Верхняя строка с информацией о расписании и статусом
                            Row(
                              children: [
                                // Иконка статуса
                                Icon(
                                  _getExceptionIcon(status),
                                  size: 20,
                                  color: _getExceptionColor(status),
                                ),
                                const SizedBox(width: 8),

                                // ТОЛЬКО ДАТА ИСКЛЮЧЕНИЯ (без повторного дня недели)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    exceptionDate != null
                                        ? _formatDateWithWeekday(exceptionDate) // Здесь уже будет "ПН 15.01"
                                        : '--.--',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[800],
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Время оригинального расписания
                                Expanded(
                                  child: Text(
                                    '$startTime-$endTime',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                                // Статус
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getExceptionColor(status),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getExceptionStatusText(status),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Если перенесено, показываем новое время
                            if (status == 'replaced' &&
                                newDay != null &&
                                newStartTime != null &&
                                newEndTime != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                      color: Colors.purple,
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.purple[50],
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _formatDateWithWeekday(newDay),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.purple[800],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$newStartTime-$newEndTime',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.purple[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Если отменено, показываем текст "Занятие отменено"
                            if (status == 'declined')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.block,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Занятие отменено',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red[800],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchStudentsWithSchedule,
        tooltip: 'Обновить',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}