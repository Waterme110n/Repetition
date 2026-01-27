// lib/screens/add_student_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'all_student.dart';
import 'main.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _costController = TextEditingController();

  final List<Map<String, dynamic>> _schedule = [];
  final List<Map<String, dynamic>> _singleLessons = [];

  bool _isLoading = false;

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

  void _addScheduleRow() {
    setState(() {
      _schedule.add({
        'day': _days.first['value'],
        'start': null as String?,
        'end': null as String?,
      });
    });
  }

  void _addSingleLessonRow() {
    setState(() {
      _singleLessons.add({
        'date': DateTime.now(),
        'start': null as String?,
        'end': null as String?,
      });
    });
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

  // Проверка занятости времени для расписания
  Future<bool> _isTimeSlotAvailable(int day, String startTime, String endTime) async {
    try {
      final startMinutes = _timeToMinutes(startTime);
      final endMinutes = _timeToMinutes(endTime);

      // Получаем все занятия на этот день
      final existingSchedules = await supabase
          .from('weekly_schedule')
          .select('start_time, end_time')
          .eq('day_of_week', day);

      // Проверяем каждое существующее занятие на пересечение
      for (final schedule in existingSchedules) {
        final existingStart = _timeToMinutes(schedule['start_time'] as String);
        final existingEnd = _timeToMinutes(schedule['end_time'] as String);

        // Проверка пересечения интервалов
        final isOverlap =
        (startMinutes < existingEnd && endMinutes > existingStart);

        if (isOverlap) {
          return false; // Время занято
        }
      }

      return true; // Время свободно
    } catch (e) {
      print('Ошибка проверки времени: $e');
      return false;
    }
  }

  // Проверка занятости времени для отдельных занятий
  Future<bool> _isSingleLessonTimeAvailable(DateTime date, String startTime, String endTime) async {
    try {
      final startMinutes = _timeToMinutes(startTime);
      final endMinutes = _timeToMinutes(endTime);

      // 1. Проверяем пересечение с другими отдельными занятиями в эту дату
      final formattedDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final existingSingleLessons = await supabase
          .from('single_lessons')
          .select('start_time, end_time')
          .eq('date', formattedDate);

      for (final lesson in existingSingleLessons) {
        final existingStart = _timeToMinutes(lesson['start_time'] as String);
        final existingEnd = _timeToMinutes(lesson['end_time'] as String);

        final isOverlap = (startMinutes < existingEnd && endMinutes > existingStart);
        if (isOverlap) {
          return false;
        }
      }

      // 2. Проверяем пересечение с расписанием в этот день недели
      final dayOfWeek = date.weekday;
      final existingSchedules = await supabase
          .from('weekly_schedule')
          .select('start_time, end_time')
          .eq('day_of_week', dayOfWeek);

      for (final schedule in existingSchedules) {
        final existingStart = _timeToMinutes(schedule['start_time'] as String);
        final existingEnd = _timeToMinutes(schedule['end_time'] as String);

        final isOverlap = (startMinutes < existingEnd && endMinutes > existingStart);
        if (isOverlap) {
          return false;
        }
      }

      return true; // Время свободно
    } catch (e) {
      print('Ошибка проверки времени отдельного занятия: $e');
      return false;
    }
  }

  // Вспомогательная функция для конвертации времени в минуты
  int _timeToMinutes(String time) {
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        return hours * 60 + minutes;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

// Сохранение всего
  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;

    // Проверка расписания
    for (final item in _schedule) {
      if (item['start'] == null || item['end'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Выберите начало и окончание в каждом дне расписания'),
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
            content: Text('Выберите начало и окончание в каждом отдельном занятии'),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final String studentName = _nameController.text.trim();

      // Проверяем, есть ли уже ученик с таким именем
      final existingStudent = await supabase
          .from('student')
          .select('id')
          .eq('name', studentName)
          .maybeSingle();

      if (existingStudent != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ученик с таким именем уже существует'),
          ),
        );
        return;
      }

      // Проверяем расписание на пересечение
      if (_schedule.isNotEmpty) {
        for (final item in _schedule) {
          final start = item['start'] as String;
          final end = item['end'] as String;
          final day = item['day'] as int;

          final startTime = '$start:00';
          final endTime = '$end:00';

          final isAvailable = await _isTimeSlotAvailable(day, startTime, endTime);

          if (!isAvailable) {
            if (!mounted) return;
            final dayName = _getDayName(day);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Это время в $dayName уже занято'),
              ),
            );
            return;
          }
        }
      }

      // Проверяем отдельные занятия на пересечение
      if (_singleLessons.isNotEmpty) {
        for (final item in _singleLessons) {
          final start = item['start'] as String;
          final end = item['end'] as String;
          final date = item['date'] as DateTime;

          final startTime = '$start:00';
          final endTime = '$end:00';

          final isAvailableZan = await _isSingleLessonTimeAvailable(date, startTime, endTime);

          if (!isAvailableZan) {
            if (!mounted) return;
            final formattedDate = '${date.day}.${date.month}.${date.year}';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Это время $formattedDate уже занято'),
              ),
            );
            return;
          }
        }
      }

      // Добавляем ученика
      final price = int.tryParse(_costController.text.trim()) ?? 0;

      final studentRes = await supabase
          .from('student')
          .insert({
        'name': studentName,
        'description': _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        'price_30_min': price,
      })
          .select('id')
          .single();

      final studentId = studentRes['id'] as int;

      // Добавляем расписание (если есть)
      if (_schedule.isNotEmpty) {
        final scheduleRows = _schedule.map((item) {
          final start = item['start'] as String;
          final end = item['end'] as String;

          return {
            'student_id': studentId,
            'day_of_week': item['day'],
            'start_time': '$start:00',
            'end_time': '$end:00',
          };
        }).toList();

        await supabase.from('weekly_schedule').insert(scheduleRows);
      }

      // Добавляем отдельные занятия (если есть)
      if (_singleLessons.isNotEmpty) {
        final lessonRows = _singleLessons.map((item) {
          final start = item['start'] as String;
          final end = item['end'] as String;
          final date = item['date'] as DateTime;

          return {
            'student_id': studentId,
            'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            'start_time': '$start:00',
            'end_time': '$end:00',
          };
        }).toList();

        await supabase.from('single_lessons').insert(lessonRows);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ученик, расписание и отдельные занятия успешно сохранены')),
      );

      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AllStudentScreen()),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getDayName(int dayValue) {
    return _days.firstWhere(
          (d) => d['value'] == dayValue,
      orElse: () => {'name': ''},
    )['name'] as String;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
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
      appBar: AppBar(title: const Text('Добавить ученика')),
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
              selected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Padding(
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
                  labelText: 'Цена за пол часа',
                  border: OutlineInputBorder(),
                  prefixText: 'BYN '
                ),
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Обязательно' : null,
              ),
              const SizedBox(height: 20),

              // Расписание
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Расписание',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            items: _days.map((d) {
                              return DropdownMenuItem<int>(
                                value: d['value'] as int,
                                child: Text(d['name'] as String),
                              );
                            }).toList(),
                            onChanged: (v) => setState(() => item['day'] = v),
                            validator: (v) => v == null ? 'Выберите день' : null,
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
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            items: _startTimes.map((t) {
                              return DropdownMenuItem(value: t, child: Text(t));
                            }).toList(),
                            onChanged: (v) => setState(() {
                              item['start'] = v;
                              item['end'] = null;
                            },),validator: (v) => v == null ? 'Обязательно' : null,
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                filled: true,
                              ),
                              items: endOptions.map((e) {
                                return DropdownMenuItem<String>(value: e, child: Text(e));
                              }).toList(),
                              onChanged: (v) {
                                setState(() => item['end'] = v);
                              },
                              validator: (v) => v == null ? 'Обязательно' : null,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // 4. Кнопка удаления
                    Expanded(
                      flex: 2,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Удалить',
                        onPressed: () => _removeScheduleRow(index),
                      ),)

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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                            validator: (v) => v == null || v.isEmpty ? 'Выберите дату' : null,
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
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            items: _startTimes.map((t) {
                              return DropdownMenuItem(value: t, child: Text(t));
                            }).toList(),
                            onChanged: (v) => setState(() {
                              item['start'] = v;
                              item['end'] = null;
                            }),
                            validator: (v) => v == null ? 'Обязательно' : null,
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                filled: item['start'] == null,
                              ),
                              items: endOptions.map((e) {
                                return DropdownMenuItem<String>(value: e, child: Text(e));
                              }).toList(),
                              onChanged: (v) {
                                setState(() => item['end'] = v);
                              },
                              validator: (v) => v == null ? 'Обязательно' : null,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // 4. Кнопка удаления
                        Expanded(
                          flex: 2,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Удалить занятие',
                            onPressed: () => _removeSingleLessonRow(index),
                          ),
                        )
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
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isLoading
                      ? 'Сохранение...'
                      : 'Сохранить ученика и расписание',
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
