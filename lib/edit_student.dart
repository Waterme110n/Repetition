// lib/screens/edit_student_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'all_student.dart';
import 'main.dart';

class EditStudentScreen extends StatefulWidget {
  final int studentId;

  const EditStudentScreen({super.key, required this.studentId});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _costController = TextEditingController();

  final List<Map<String, dynamic>> _schedule = [];
  final List<Map<String, dynamic>> _singleLessons = [];
  final List<Map<String, dynamic>> _scheduleExceptions = [];

  bool _isLoading = false;
  bool _isInitialized = false;

  final supabase = Supabase.instance.client;

  // Дни недели
  final List<Map<String, dynamic>> _days = [
    {'name': 'ПН', 'value': 1},
    {'name': 'ВТ', 'value': 2},
    {'name': 'СР', 'value': 3},
    {'name': 'ЧТ', 'value': 4},
    {'name': 'ПТ', 'value': 5},
    {'name': 'СБ', 'value': 6},
  ];

  // Время начала: 11:00 – 22:00 каждые 30 мин
  final List<String> _startTimes = List.generate(23, (i) {
    final hour = 11 + (i ~/ 2);
    final minute = (i % 2) * 30;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  });

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  // Загрузка данных ученика
  Future<void> _loadStudentData() async {
    setState(() => _isLoading = true);
    try {
      // Загружаем основные данные ученика
      final studentData = await supabase
          .from('student')
          .select('*')
          .eq('id', widget.studentId)
          .single();

      _nameController.text = studentData['name'] as String;
      _descController.text = studentData['description'] as String? ?? '';
      final price = studentData['price_30_min'] as num?;
      _costController.text = price != null ? price.toStringAsFixed(2) : '0.00';

      // Загружаем расписание
      final scheduleData = await supabase
          .from('weekly_schedule')
          .select('*')
          .eq('student_id', widget.studentId);

      for (final item in scheduleData) {
        final startTime = item['start_time'] as String;
        final endTime = item['end_time'] as String;

        _schedule.add({
          'id': item['id'], // сохраняем ID для обновления
          'day': item['day_of_week'],
          'start': startTime.substring(0, 5), // убираем секунды
          'end': endTime.substring(0, 5), // убираем секунды
        });
      }

      // Загружаем отдельные занятия
      final singleLessonsData = await supabase
          .from('single_lessons')
          .select('*')
          .eq('student_id', widget.studentId);

      for (final item in singleLessonsData) {
        final startTime = item['start_time'] as String;
        final endTime = item['end_time'] as String;
        final dateStr = item['date'] as String;
        final dateParts = dateStr.split('-');

        _singleLessons.add({
          'id': item['id'],
          'date': DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          ),
          'start': startTime.substring(0, 5),
          'end': endTime.substring(0, 5),
        });
      }

      // Загружаем исключения расписания
      for (final schedule in scheduleData) {
        final scheduleId = schedule['id'] as int;

        // Загружаем исключения для этого расписания
        final exceptionsData = await supabase
            .from('schedule_exceptions')
            .select('*')
            .eq('schedule_id', scheduleId);

        for (final exception in exceptionsData) {
          _scheduleExceptions.add({
            'id': exception['id'],
            'schedule_id': scheduleId,
            'status': exception['status'],
            'date': exception['date'] != null
                ? DateTime.parse(exception['date'] as String)
                : null,
            'original_date': exception['date'] != null
                ? DateTime.parse(exception['date'] as String)
                : null,
            'new_date': exception['new_day'] != null
                ? DateTime.parse(exception['new_day'] as String)
                : null,
            'new_start_time': exception['new_start_time'] != null
                ? (exception['new_start_time'] as String).substring(0, 5)
                : null,
            'new_end_time': exception['new_end_time'] != null
                ? (exception['new_end_time'] as String).substring(0, 5)
                : null,
          });
        }
      }

      setState(() => _isInitialized = true);
    } catch (e) {
      print('Ошибка загрузки данных: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка загрузки данных: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addScheduleRow() {
    setState(() {
      _schedule.add({
        'id': null, // новый элемент
        'day': _days.first['value'],
        'start': null as String?,
        'end': null as String?,
      });
    });
  }

  void _addSingleLessonRow() {
    setState(() {
      _singleLessons.add({
        'id': null, // новый элемент
        'date': DateTime.now(),
        'start': null as String?,
        'end': null as String?,
      });
    });
  }

  void _addScheduleExceptionRow() {
    // Проверяем есть ли расписание с ID
    final existingSchedules = _schedule.where((s) => s['id'] != null).toList();

    if (existingSchedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сначала сохраните расписание (оно должно появиться в базе)',
          ),
        ),
      );
      return;
    }

    // Показываем выбор расписания
    _showSchedulePickerForException();
  }

  void _showSchedulePickerForException() {
    final existingSchedules = _schedule.where((s) => s['id'] != null).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выберите расписание для исключения'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: existingSchedules.length,
              itemBuilder: (context, index) {
                final schedule = existingSchedules[index];
                final dayOfWeek = schedule['day'] as int;
                final dayName = _getDayName(dayOfWeek);
                final start = schedule['start'] as String? ?? '--:--';
                final end = schedule['end'] as String? ?? '--:--';

                // Вычисляем ближайшую дату для этого дня недели
                final suggestedDate = _getNextDateForDay(dayOfWeek);
                final dateWithDay = _formatDateWithDay(suggestedDate);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text('$dayName, $dateWithDay'),
                    subtitle: Text('$start - $end'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      _showDateSelectionDialog(
                        schedule: schedule,
                        suggestedDate: suggestedDate,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  DateTime _getNextDateForDay(int dayOfWeek) {
    final now = DateTime.now();

    // Вычисляем сколько дней до нужного дня недели
    int daysUntil = dayOfWeek - now.weekday;
    if (daysUntil <= 0) {
      daysUntil +=
          7; // Если день уже прошел на этой неделе, берем следующую неделю
    }

    return DateTime(now.year, now.month, now.day + daysUntil);
  }

  void _showDateSelectionDialog({
    required Map<String, dynamic> schedule,
    required DateTime suggestedDate,
  }) {
    final dayName = _getDayName(schedule['day'] as int);
    final start = schedule['start'] as String? ?? '--:--';
    final end = schedule['end'] as String? ?? '--:--';
    final formattedSuggestedDate = _formatDateFull(suggestedDate);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выберите дату для исключения'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Информация о расписании
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Расписание:',
                      style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                    ),
                    Text(
                      '$dayName $start-$end',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const Text(
                'Выберите, когда отменить/перенести это занятие:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Карточка с ближайшей датой
              Card(
                elevation: 3,
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.blue),
                  title: const Text('Ближайшая дата'),
                  subtitle: Text(formattedSuggestedDate),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                  onTap: () {
                    Navigator.pop(context);
                    _addExceptionWithDate(
                      schedule: schedule,
                      selectedDate: suggestedDate,
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // Разделитель "ИЛИ"
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'или',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),

              const SizedBox(height: 8),

              // Кнопка выбора другой даты
              ElevatedButton.icon(
                onPressed: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: suggestedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    locale: const Locale('ru', 'RU'),
                  );

                  if (selectedDate != null) {
                    Navigator.pop(context);
                    _addExceptionWithDate(
                      schedule: schedule,
                      selectedDate: selectedDate,
                    );
                  }
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text('Выбрать другую дату'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addExceptionWithDate({
    required Map<String, dynamic> schedule,
    required DateTime selectedDate,
  }) {
    final dayName = _getDayName(schedule['day'] as int);
    final dateWithDay = _formatDateFull(selectedDate);

    setState(() {
      _scheduleExceptions.add({
        'id': null,
        'schedule_id': schedule['id'],
        'schedule_info': '$dayName ${schedule['start']}-${schedule['end']}',
        'original_date': selectedDate,
        'date': selectedDate,
        'status': 'declined',
        'new_day': null,
        'new_start_time': null,
        'new_end_time': null,
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Добавлено исключение на $dateWithDay')),
    );
  }

  // Удаление строки
  void _removeScheduleRow(int index) {
    setState(() {
      _schedule.removeAt(index);
    });
  }

  void _removeSingleLessonRow(int index) {
    setState(() {
      _singleLessons.removeAt(index);
    });
  }

  void _removeScheduleExceptionRow(int index) {
    setState(() {
      _scheduleExceptions.removeAt(index);
    });
  }

  // Расчёт времени окончания
  List<String> _getEndTimeOptions(String start) {
    final parts = start.split(':');
    if (parts.length != 2) return [];

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final totalMin = hour * 60 + minute;

    return [30, 60, 90].map((add) {
      final endTotal = totalMin + add;
      final endHour = endTotal ~/ 60;
      final endMin = endTotal % 60;
      return '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
    }).toList();
  }

  // Сохранение изменений
  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;

    // Проверка расписания
    for (final item in _schedule) {
      if (item['start'] == null || item['end'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Выберите начало и окончание в каждом дне расписания',
            ),
          ),
        );
        return;
      }
    }

    // Проверка отдельных занятий
    for (final item in _singleLessons) {
      if (item['start'] == null || item['end'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Выберите начало и окончание в каждом отдельном занятии',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final String studentName = _nameController.text.trim();

      // Проверяем, есть ли другой ученик с таким именем
      final existingStudent = await supabase
          .from('student')
          .select('id')
          .eq('name', studentName)
          .neq('id', widget.studentId)
          .maybeSingle();

      if (existingStudent != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Другой ученик с таким именем уже существует'),
          ),
        );
        return;
      }

      final priceText = _costController.text
          .trim()
          .replaceAll(' ', '')
          .replaceAll(',', '.');

      final price = double.tryParse(priceText) ?? 0.0;

      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите корректную цену больше 0')),
        );
        return;
      }

      await supabase
          .from('student')
          .update({
            'name': studentName,
            'description': _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            'price_30_min': price,
          })
          .eq('id', widget.studentId);

      // 1. ОБРАБАТЫВАЕМ РАСПИСАНИЕ
      // Собираем ID расписаний, которые остались
      final existingScheduleIds = _schedule
          .where((item) => item['id'] != null)
          .map((item) => item['id'] as int)
          .toList();

      // Удаляем расписания, которые были удалены из UI
      if (existingScheduleIds.isNotEmpty) {
        await supabase
            .from('weekly_schedule')
            .delete()
            .eq('student_id', widget.studentId)
            .not('id', 'in', existingScheduleIds);
      } else {
        // Если все расписания новые (нет ID), удаляем все старые
        await supabase
            .from('weekly_schedule')
            .delete()
            .eq('student_id', widget.studentId);
      }

      // Сохраняем все расписания (новые и обновленные)
      for (final item in _schedule) {
        final scheduleId = item['id'] as int?;
        final start = item['start'] as String;
        final end = item['end'] as String;

        final scheduleData = {
          'student_id': widget.studentId,
          'day_of_week': item['day'],
          'start_time': '$start:00',
          'end_time': '$end:00',
        };

        if (scheduleId == null) {
          // СОЗДАЕМ НОВОЕ РАСПИСАНИЕ
          await supabase.from('weekly_schedule').insert(scheduleData);
        } else {
          // ОБНОВЛЯЕМ СУЩЕСТВУЮЩЕЕ РАСПИСАНИЕ
          await supabase
              .from('weekly_schedule')
              .update(scheduleData)
              .eq('id', scheduleId);
        }
      }

      // 2. ОБРАБАТЫВАЕМ ОТДЕЛЬНЫЕ ЗАНЯТИЯ
      // Собираем ID занятий, которые остались
      final existingLessonIds = _singleLessons
          .where((item) => item['id'] != null)
          .map((item) => item['id'] as int)
          .toList();

      // Удаляем занятия, которые были удалены из UI
      if (existingLessonIds.isNotEmpty) {
        await supabase
            .from('single_lessons')
            .delete()
            .eq('student_id', widget.studentId)
            .not('id', 'in', existingLessonIds);
      } else {
        // Если все занятия новые (нет ID), удаляем все старые
        await supabase
            .from('single_lessons')
            .delete()
            .eq('student_id', widget.studentId);
      }

      // Сохраняем все занятия (новые и обновленные)
      for (final item in _singleLessons) {
        final lessonId = item['id'] as int?;
        final start = item['start'] as String;
        final end = item['end'] as String;
        final date = item['date'] as DateTime;

        final lessonData = {
          'student_id': widget.studentId,
          'date':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'start_time': '$start:00',
          'end_time': '$end:00',
        };

        if (lessonId == null) {
          // СОЗДАЕМ НОВОЕ ЗАНЯТИЕ
          await supabase.from('single_lessons').insert(lessonData);
        } else {
          // ОБНОВЛЯЕМ СУЩЕСТВУЮЩЕЕ ЗАНЯТИЕ
          await supabase
              .from('single_lessons')
              .update(lessonData)
              .eq('id', lessonId);
        }
      }

      // 3. ОБРАБАТЫВАЕМ ИСКЛЮЧЕНИЯ РАСПИСАНИЯ
      // Сначала получаем ID всех расписаний ученика (после сохранения)
      final allSchedules = await supabase
          .from('weekly_schedule')
          .select('id')
          .eq('student_id', widget.studentId);

      final allScheduleIds = allSchedules.map((s) => s['id'] as int).toList();

      // Собираем ID исключений, которые остались
      final existingExceptionIds = _scheduleExceptions
          .where((item) => item['id'] != null)
          .map((item) => item['id'] as int)
          .toList();

      // Удаляем исключения, которые были удалены из UI
      if (allScheduleIds.isNotEmpty && existingExceptionIds.isNotEmpty) {
        await supabase
            .from('schedule_exceptions')
            .delete()
            .inFilter('schedule_id', allScheduleIds)
            .not('id', 'in', existingExceptionIds);
      } else if (allScheduleIds.isNotEmpty) {
        // Если все исключения новые (нет ID), удаляем все старые
        await supabase
            .from('schedule_exceptions')
            .delete()
            .inFilter('schedule_id', allScheduleIds);
      }

      // Сохраняем все исключения (новые и обновленные)
      for (final exception in _scheduleExceptions) {
        final exceptionId = exception['id'] as int?;
        final status = exception['status'] as String;
        final scheduleId = exception['schedule_id'] as int?;

        // Пропускаем исключения без расписания
        if (scheduleId == null) continue;

        Map<String, dynamic> exceptionData = {
          'schedule_id': scheduleId,
          'status': status,
        };

        // ДОБАВЛЯЕМ ДАТУ
        if (exception['date'] != null) {
          final date = exception['date'] as DateTime;
          exceptionData['date'] =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        }

        if (status == 'declined') {
          // Для отмены: сохраняем оригинальную дату в new_day
          if (exception['date'] != null) {
            final originalDate = exception['date'] as DateTime;
            exceptionData['new_day'] =
                '${originalDate.year}-${originalDate.month.toString().padLeft(2, '0')}-${originalDate.day.toString().padLeft(2, '0')}';
          }
          // Очищаем поля переноса (на всякий случай)
          exceptionData['new_start_time'] = null;
          exceptionData['new_end_time'] = null;
        } else if (status == 'replaced') {
          final newDate = exception['new_date'] as DateTime?;
          final newStart = exception['new_start_time'] as String?;
          final newEnd = exception['new_end_time'] as String?;

          if (newDate != null && newStart != null && newEnd != null) {
            exceptionData['new_day'] =
                '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
            exceptionData['new_start_time'] = '$newStart:00';
            exceptionData['new_end_time'] = '$newEnd:00';
          }
        }

        if (exceptionId == null) {
          // СОЗДАЕМ НОВОЕ ИСКЛЮЧЕНИЕ
          await supabase.from('schedule_exceptions').insert(exceptionData);
        } else {
          // ОБНОВЛЯЕМ СУЩЕСТВУЮЩЕЕ ИСКЛЮЧЕНИЕ
          await supabase
              .from('schedule_exceptions')
              .update(exceptionData)
              .eq('id', exceptionId);
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Данные успешно обновлены')));

      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AllStudentScreen()),
      );
    } catch (e) {
      print('Ошибка сохранения: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDateWithDay(DateTime date) {
    final dayNames = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];
    final dayIndex = date.weekday - 1;
    final dayName = dayNames[dayIndex];

    return '$dayName ${date.day}.${date.month}';
  }

  String _getDayName(int dayValue) {
    return _days.firstWhere(
          (d) => d['value'] == dayValue,
          orElse: () => {'name': ''},
        )['name']
        as String;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
  }

  String _formatDateFull(DateTime date) {
    final weekdayNames = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];
    final monthNames = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    final weekday = weekdayNames[date.weekday - 1];
    final month = monthNames[date.month - 1];

    return '$weekday ${date.day} $month';
  }

  String _getScheduleInfo(int? scheduleId) {
    if (scheduleId == null) return 'Без расписания';

    try {
      final schedule = _schedule.firstWhere(
        (s) => s['id'] == scheduleId,
        orElse: () => {'day': 0, 'start': '--:--', 'end': '--:--'},
      );
      final dayName = _getDayName(schedule['day'] as int);
      final start = schedule['start'] as String? ?? '--:--';
      final end = schedule['end'] as String? ?? '--:--';

      return '$dayName $start-$end';
    } catch (e) {
      return 'Расписание не найдено';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _costController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать ученика')),
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
                  MaterialPageRoute(
                    builder: (context) => const AllStudentScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Добавить ученика'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: _isLoading && !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Имя
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Имя ученика',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v?.trim().isEmpty ?? true ? 'Обязательно' : null,
                    ),
                    const SizedBox(height: 20),

                    // Описание
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Описание / заметки',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Цена
                    TextFormField(
                      controller: _costController,
                      decoration: const InputDecoration(
                        labelText: 'Цена за 30 минут',
                        border: OutlineInputBorder(),
                        prefixText: 'BYN ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),

                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Обязательно';
                        }
                        final cleaned = value
                            .trim()
                            .replaceAll(' ', '')
                            .replaceAll(',', '.');
                        final numValue = double.tryParse(cleaned);
                        if (numValue == null || numValue <= 0) {
                          return 'Введите корректную цену > 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Расписание
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Расписание',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.green,
                            size: 32,
                          ),
                          onPressed: _addScheduleRow,
                          tooltip: 'Добавить день',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_schedule.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Нажмите + чтобы добавить день занятия',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),

                    // Карточки расписания
                    ..._schedule.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;

                      final endOptions = item['start'] != null
                          ? _getEndTimeOptions(item['start'])
                          : _startTimes;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 1. День недели
                              SizedBox(
                                width: 76,
                                child: DropdownButtonFormField<int>(
                                  value: item['day'] as int?,
                                  decoration: const InputDecoration(
                                    labelText: 'День',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: _days.map((d) {
                                    return DropdownMenuItem<int>(
                                      value: d['value'] as int,
                                      child: Text(d['name'] as String),
                                    );
                                  }).toList(),
                                  onChanged: (v) =>
                                      setState(() => item['day'] = v),
                                  validator: (v) =>
                                      v == null ? 'Выберите день' : null,
                                ),
                              ),

                              const SizedBox(width: 8),

                              // 2. Время начала
                              Expanded(
                                flex: 7,
                                child: DropdownButtonFormField<String>(
                                  value: item['start'],
                                  isDense: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Начало',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: _startTimes.map((t) {
                                    return DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() {
                                    item['start'] = v;
                                    item['end'] = null;
                                  }),
                                  validator: (v) =>
                                      v == null ? 'Обязательно' : null,
                                ),
                              ),

                              const SizedBox(width: 8),

                              // 3. Время окончания
                              Expanded(
                                flex: 6,
                                child: IgnorePointer(
                                  ignoring: item['start'] == null,
                                  child: DropdownButtonFormField<String>(
                                    value: item['end'],
                                    isDense: true,
                                    decoration: InputDecoration(
                                      labelText: 'Конец',
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                      filled: true,
                                    ),
                                    items: endOptions.map((e) {
                                      return DropdownMenuItem<String>(
                                        value: e,
                                        child: Text(e),
                                      );
                                    }).toList(),
                                    onChanged: (v) {
                                      setState(() => item['end'] = v);
                                    },
                                    validator: (v) =>
                                        v == null ? 'Обязательно' : null,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // 4. Кнопка удаления
                              Expanded(
                                flex: 2,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Удалить',
                                  onPressed: () => _removeScheduleRow(index),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Отдельные занятия',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.orange,
                            size: 32,
                          ),
                          onPressed: _addSingleLessonRow,
                          tooltip: 'Добавить отдельное занятие',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_singleLessons.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Нажмите + чтобы добавить отдельное занятие',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),

                    // Карточки отдельных занятий
                    ..._singleLessons.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;

                      final endOptions = item['start'] != null
                          ? _getEndTimeOptions(item['start'] as String)
                          : <String>[];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.orange[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 1. Дата
                              SizedBox(
                                width: 80,
                                child: TextFormField(
                                  readOnly: true,
                                  controller: TextEditingController(
                                    text: _formatDate(item['date'] as DateTime),
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Дата',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  onTap: () async {
                                    final selectedDate = await showDatePicker(
                                      context: context,
                                      initialDate: item['date'] as DateTime,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(2100),
                                      locale: const Locale('ru', 'RU'),
                                    );
                                    if (selectedDate != null) {
                                      setState(() {
                                        item['date'] = selectedDate;
                                      });
                                    }
                                  },
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Выберите дату'
                                      : null,
                                ),
                              ),

                              const SizedBox(width: 8),

                              // 2. Время начала
                              Expanded(
                                flex: 6,
                                child: DropdownButtonFormField<String>(
                                  value: item['start'],
                                  isDense: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Начало',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: _startTimes.map((t) {
                                    return DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() {
                                    item['start'] = v;
                                    item['end'] = null;
                                  }),
                                  validator: (v) =>
                                      v == null ? 'Обязательно' : null,
                                ),
                              ),

                              const SizedBox(width: 8),

                              // 3. Время окончания
                              Expanded(
                                flex: 6,
                                child: IgnorePointer(
                                  ignoring: item['start'] == null,
                                  child: DropdownButtonFormField<String>(
                                    value: item['end'],
                                    isDense: true,
                                    decoration: InputDecoration(
                                      labelText: 'Конец',
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                      filled: item['start'] == null,
                                    ),
                                    items: endOptions.map((e) {
                                      return DropdownMenuItem<String>(
                                        value: e,
                                        child: Text(e),
                                      );
                                    }).toList(),
                                    onChanged: (v) {
                                      setState(() => item['end'] = v);
                                    },
                                    validator: (v) =>
                                        v == null ? 'Обязательно' : null,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // 4. Кнопка удаления
                              Expanded(
                                flex: 2,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Удалить занятие',
                                  onPressed: () =>
                                      _removeSingleLessonRow(index),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    // Раздел "Исключения в расписании"
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Исключения в расписании',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.purple,
                            size: 32,
                          ),
                          onPressed: _addScheduleExceptionRow,
                          tooltip: 'Добавить исключение',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_scheduleExceptions.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          child: Text(
                            'Нажмите + чтобы добавить исключение (отмена/перенос занятия)',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),

                    // Карточки исключений
                    ..._scheduleExceptions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isReplaced = item['status'] == 'replaced';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: isReplaced ? Colors.purple[50] : Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              // ИНФОРМАЦИЯ О РАСПИСАНИИ
                              if (item['schedule_id'] != null &&
                                  item['original_date'] != null)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue[100]!,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.blue[800],
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Исключение для расписания:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue[600],
                                              ),
                                            ),
                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: _getScheduleInfo(
                                                      item['schedule_id'],
                                                    ), // "ПН 10:00-11:00"
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue[800],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: ' с ',
                                                    style: TextStyle(
                                                      color: Colors.blue[800],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: _formatDate(
                                                      item['original_date']
                                                          as DateTime,
                                                    ), // "15.01"
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.green[800],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // 1. Статус
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: item['status'] as String,
                                      decoration: const InputDecoration(
                                        labelText: 'Статус',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'declined',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.cancel,
                                                color: Colors.red,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Отменено'),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'replaced',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.schedule,
                                                color: Colors.purple,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('Перенесено'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          item['status'] = v;
                                          if (v == 'declined') {
                                            item['new_date'] = null;
                                            item['new_start_time'] = null;
                                            item['new_end_time'] = null;
                                          } else if (v == 'replaced') {
                                            item['new_date'] = DateTime.now();
                                          }
                                        });
                                      },
                                      validator: (v) =>
                                          v == null ? 'Выберите статус' : null,
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // 2. Кнопка удаления
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Удалить исключение',
                                    onPressed: () =>
                                        _removeScheduleExceptionRow(index),
                                  ),
                                ],
                              ),

                              // Поля для переноса
                              if (isReplaced) ...[
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                const Text(
                                  'Новое время занятия:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                Row(
                                  children: [
                                    // Новая дата
                                    Expanded(
                                      child: TextFormField(
                                        readOnly: true,
                                        controller: TextEditingController(
                                          text: item['new_date'] != null
                                              ? _formatDate(
                                                  item['new_date'] as DateTime,
                                                )
                                              : '',
                                        ),
                                        decoration: const InputDecoration(
                                          labelText: 'Новая дата',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                        ),
                                        onTap: () async {
                                          final selectedDate =
                                              await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    item['new_date']
                                                        as DateTime? ??
                                                    DateTime.now(),
                                                firstDate: DateTime.now(),
                                                lastDate: DateTime(2100),
                                                locale: const Locale(
                                                  'ru',
                                                  'RU',
                                                ),
                                              );
                                          if (selectedDate != null) {
                                            setState(() {
                                              item['new_date'] = selectedDate;
                                            });
                                          }
                                        },
                                        validator: isReplaced
                                            ? (v) => v == null || v.isEmpty
                                                  ? 'Выберите новую дату'
                                                  : null
                                            : null,
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // Новое время начала
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: item['new_start_time'],
                                        decoration: const InputDecoration(
                                          labelText: 'Новое начало',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                        ),
                                        items: _startTimes.map((t) {
                                          return DropdownMenuItem(
                                            value: t,
                                            child: Text(t),
                                          );
                                        }).toList(),
                                        onChanged: (v) => setState(() {
                                          item['new_start_time'] = v;
                                          item['new_end_time'] = null;
                                        }),
                                        validator: isReplaced
                                            ? (v) => v == null
                                                  ? 'Выберите новое время начала'
                                                  : null
                                            : null,
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // Новое время окончания
                                    Expanded(
                                      child: IgnorePointer(
                                        ignoring:
                                            item['new_start_time'] == null,
                                        child: DropdownButtonFormField<String>(
                                          value: item['new_end_time'],
                                          decoration: InputDecoration(
                                            labelText: 'Новый конец',
                                            border: const OutlineInputBorder(),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 8,
                                                ),
                                            filled:
                                                item['new_start_time'] == null,
                                          ),
                                          items: item['new_start_time'] != null
                                              ? _getEndTimeOptions(
                                                      item['new_start_time']
                                                          as String,
                                                    )
                                                    .map(
                                                      (e) =>
                                                          DropdownMenuItem<
                                                            String
                                                          >(
                                                            value: e,
                                                            child: Text(e),
                                                          ),
                                                    )
                                                    .toList()
                                              : [],
                                          onChanged: (v) => setState(
                                            () => item['new_end_time'] = v,
                                          ),
                                          validator: isReplaced
                                              ? (v) => v == null
                                                    ? 'Выберите новое время окончания'
                                                    : null
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 32),

                    // Кнопка сохранения
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveAll,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isLoading ? 'Сохранение...' : 'Сохранить изменения',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 56),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
