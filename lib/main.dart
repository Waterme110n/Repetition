import 'package:flutter/material.dart';
import 'package:for_repets/all_student.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_student.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'edit_student.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://aeactvsdzatqtknqhzid.supabase.co',
    anonKey: 'sb_publishable_l5Li_pkjb2bsR2hY56XqkA_SLdCmEbC',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Занятия',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ru', 'RU'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: const CalendarPage(),
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class Student {
  final int id;
  final String name;
  final String? description;
  final double price30Min;

  Student({
    required this.id,
    required this.name,
    this.description,
    required this.price30Min,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price30Min: json['price_30_min'],
    );
  }

  double calculateLessonCost(TimeOfDay startTime, TimeOfDay endTime) {
    final startMinutes = startTime.hour * 60 + startTime.minute;
    final endMinutes = endTime.hour * 60 + endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    if (durationMinutes <= 0) return 0;

    return (durationMinutes / 30) * price30Min.toDouble();
  }
}

class BaseLesson {
  final int id;
  final int studentId;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  BaseLesson({
    required this.id,
    required this.studentId,
    required this.startTime,
    required this.endTime,
  });

  int get startMinutes => startTime.hour * 60 + startTime.minute;
  int get endMinutes => endTime.hour * 60 + endTime.minute;
}

class WeeklyLesson extends BaseLesson {
  final int dayOfWeek;

  WeeklyLesson({
    required int id,
    required int studentId,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required this.dayOfWeek,
  }) : super(
    id: id,
    studentId: studentId,
    startTime: startTime,
    endTime: endTime,
  );

  factory WeeklyLesson.fromJson(Map<String, dynamic> json) {
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return WeeklyLesson(
      id: json['id'],
      studentId: json['student_id'],
      dayOfWeek: json['day_of_week'],
      startTime: parseTime(json['start_time']),
      endTime: parseTime(json['end_time']),
    );
  }
}

class SingleLesson extends BaseLesson {
  final DateTime date;

  SingleLesson({
    required int id,
    required int studentId,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required this.date,
  }) : super(
    id: id,
    studentId: studentId,
    startTime: startTime,
    endTime: endTime,
  );

  factory SingleLesson.fromJson(Map<String, dynamic> json) {
    TimeOfDay parseTime(String timeStr) {
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return SingleLesson(
      id: json['id'],
      studentId: json['student_id'],
      date: DateTime.parse(json['date']),
      startTime: parseTime(json['start_time']),
      endTime: parseTime(json['end_time']),
    );
  }

  int get dayOfWeek => date.weekday;
}

class ScheduleException {
  final int id;
  final DateTime? date;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String status;
  final int? scheduleId;
  final DateTime? newDate;
  final TimeOfDay? newStartTime;
  final TimeOfDay? newEndTime;

  ScheduleException({
    required this.id,
    this.date,
    this.startTime,
    this.endTime,
    required this.status,
    this.scheduleId,
    this.newDate,
    this.newStartTime,
    this.newEndTime,
  });

  factory ScheduleException.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? timeStr) {
      if (timeStr == null) return null;
      final parts = timeStr.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    DateTime? parseDate(String? dateStr) {
      if (dateStr == null) return null;
      return DateTime.parse(dateStr);
    }

    return ScheduleException(
      id: json['id'],
      date: parseDate(json['date']),
      startTime: parseTime(json['start_time']),
      endTime: parseTime(json['end_time']),
      status: json['status'],
      scheduleId: json['schedule_id'],
      newDate: parseDate(json['new_day']),
      newStartTime: parseTime(json['new_start_time']),
      newEndTime: parseTime(json['new_end_time']),
    );
  }

  int? get newDayOfWeek {
    if (newDate == null) return null;
    return newDate!.weekday;
  }
}

class _CalendarPageState extends State<CalendarPage> {
  late PageController _pageController;
  final DateTime _currentDate = DateTime.now();

  late ScrollController _timeScrollController;
  late ScrollController _contentScrollController;

  static const int _pageCount = 120;
  static const int _initialPage = _pageCount ~/ 2;

  List<WeeklyLesson> _weeklyLessons = [];
  List<ScheduleException> _exceptions = [];
  List<SingleLesson> _singleLessons = [];
  Map<int, Student> _studentsMap = {};

  bool _isLoading = true;
  int _currentPageIndex = _initialPage;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
    _timeScrollController = ScrollController();
    _contentScrollController = ScrollController();

    _loadEssentialData();

    _pageController.addListener(() {
      setState(() {
        _currentPageIndex = _pageController.page?.round() ?? _initialPage;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentScrollController.addListener(() {
        if (_timeScrollController.hasClients && _contentScrollController.hasClients) {
          _timeScrollController.jumpTo(_contentScrollController.offset);
        }
      });
    });
  }

  Future<void> _loadEssentialData() async {
    setState(() => _isLoading = true);
    await _fetchStudents();
    await Future.wait([
      _fetchWeeklyLessons(),
      _fetchSingleLessons(),
      _fetchExceptions(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchWeeklyLessons() async {
    try {
      final client = Supabase.instance.client;
      final response = await client.from('weekly_schedule').select();

      if (response is List) {
        final List<dynamic> data = response;
        print('=== FETCHED ${data.length} WEEKLY LESSONS ===');

        setState(() {
          _weeklyLessons = data.map((json) => WeeklyLesson.fromJson(json)).toList();
        });
      } else {
        print('Weekly lessons response is not a List: $response');
      }
    } catch (e) {
      print('Error fetching weekly lessons: $e');
    }
  }

  Future<void> _fetchExceptions() async {
    try {
      final client = Supabase.instance.client;
      final response = await client.from('schedule_exceptions').select();

      if (response is List) {
        final List<dynamic> data = response;
        print('=== FETCHED ${data.length} EXCEPTIONS ===');

        setState(() {
          _exceptions = data.map((json) => ScheduleException.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        print('Exceptions response is not a List: $response');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching exceptions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSingleLessons() async {
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('single_lessons')
          .select()
          .order('date', ascending: true);

      if (response is List) {
        final List<dynamic> data = response;
        print('=== FETCHED ${data.length} SINGLE LESSONS ===');

        setState(() {
          _singleLessons = data.map((json) => SingleLesson.fromJson(json)).toList();
        });
      } else {
        print('Single lessons response is not a List: $response');
      }
    } catch (e) {
      print('Error fetching single lessons: $e');
    }
  }

  Future<void> _fetchStudents() async {
    try {
      final response = await Supabase.instance.client.from('student').select('*');
      print('Получено студентов: ${response.length}');

      final Map<int, Student> map = {};
      for (var item in response) {
        try {
          final s = Student.fromJson(item);
          map[s.id] = s;
          print('Добавлен студент: ${s.id} — ${s.name}');
        } catch (e) {
          print('Ошибка парсинга студента ${item['id']}: $e');
          print('Сырые данные: $item');
        }
      }

      setState(() {
        _studentsMap = map;
        print('Всего в карте студентов: ${map.length}');
      });
    } catch (e) {
      print('Ошибка загрузки студентов: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timeScrollController.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  DateTime _getDateFromIndex(int index) {
    final daysOffset = index - _initialPage;
    return DateTime(
      _currentDate.year,
      _currentDate.month,
      _currentDate.day + daysOffset,
    );
  }

  int _getDayOfWeek(DateTime date) {
    return date.weekday;
  }

  List<BaseLesson> _getLessonsForDate(DateTime date) {
    final dayOfWeek = _getDayOfWeek(date);
    final List<BaseLesson> result = [];

    // 1. Собираем информацию об исключениях
    final Set<int> cancelledIds = {};
    final Set<int> movedFromThisDayIds = {};
    final Map<int, BaseLesson> movedToThisDate = {};

    for (var exception in _exceptions) {
      if (exception.scheduleId == null) continue;

      if (exception.status == 'declined') {
        cancelledIds.add(exception.scheduleId!);
      }

      if (exception.status == 'replaced') {
        WeeklyLesson? originalLesson = _weeklyLessons.firstWhere(
              (lesson) => lesson.id == exception.scheduleId,
          orElse: () => WeeklyLesson(
            id: -1,
            studentId: 0,
            dayOfWeek: 0,
            startTime: TimeOfDay(hour: 0, minute: 0),
            endTime: TimeOfDay(hour: 0, minute: 0),
          ),
        );

        if (originalLesson.id == -1) continue;

        if (exception.date != null &&
            exception.date!.year == date.year &&
            exception.date!.month == date.month &&
            exception.date!.day == date.day) {
          movedFromThisDayIds.add(exception.scheduleId!);
        }

        if (exception.newDate != null &&
            exception.newDate!.year == date.year &&
            exception.newDate!.month == date.month &&
            exception.newDate!.day == date.day &&
            exception.newStartTime != null &&
            exception.newEndTime != null) {
          movedToThisDate[exception.scheduleId!] = WeeklyLesson(
            id: originalLesson.id,
            studentId: originalLesson.studentId,
            dayOfWeek: exception.newDayOfWeek ?? dayOfWeek,
            startTime: exception.newStartTime!,
            endTime: exception.newEndTime!,
          );
        }
      }
    }

    // 2. Добавляем перенесенные занятия НА эту дату
    result.addAll(movedToThisDate.values);

    // 3. Добавляем обычные уроки для этого дня недели
    for (var lesson in _weeklyLessons) {
      if (lesson.dayOfWeek == dayOfWeek) {
        if (cancelledIds.contains(lesson.id)) continue;
        if (movedFromThisDayIds.contains(lesson.id)) continue;
        if (movedToThisDate.containsKey(lesson.id)) continue;

        result.add(lesson);
      }
    }

    // 4. Добавляем одиночные уроки на эту дату
    for (var singleLesson in _singleLessons) {
      if (singleLesson.date.year == date.year &&
          singleLesson.date.month == date.month &&
          singleLesson.date.day == date.day) {
        result.add(singleLesson);
      }
    }

    // Сортируем все уроки по времени начала
    result.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return result;
  }

  ScheduleException? _getExceptionForWeeklyLesson(WeeklyLesson lesson, DateTime date) {
    for (var exception in _exceptions) {
      if (exception.scheduleId == lesson.id) {
        if (exception.status == 'replaced' &&
            exception.newDate != null &&
            exception.newDate!.year == date.year &&
            exception.newDate!.month == date.month &&
            exception.newDate!.day == date.day &&
            exception.newStartTime != null &&
            exception.newStartTime!.hour == lesson.startTime.hour &&
            exception.newStartTime!.minute == lesson.startTime.minute) {
          return exception;
        }

        if (exception.status == 'declined') {
          return exception;
        }
      }
    }

    return null;
  }

  double _getTopPosition(TimeOfDay time) {
    const startHour = 11;
    final totalMinutes = time.hour * 60 + time.minute;
    final startMinutes = startHour * 60;
    final minutesFromStart = totalMinutes - startMinutes;
    return (minutesFromStart / 30) * 60;
  }

  double _getLessonHeight(BaseLesson lesson) {
    final startMinutes = lesson.startTime.hour * 60 + lesson.startTime.minute;
    final endMinutes = lesson.endTime.hour * 60 + lesson.endTime.minute;
    final durationMinutes = endMinutes - startMinutes;
    return (durationMinutes / 30) * 60;
  }

  List<List<BaseLesson>> _groupOverlappingLessons(List<BaseLesson> lessons) {
    if (lessons.isEmpty) return [];

    final sortedLessons = List<BaseLesson>.from(lessons);
    sortedLessons.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    List<List<BaseLesson>> groups = [];
    List<BaseLesson> currentGroup = [];

    for (int i = 0; i < sortedLessons.length; i++) {
      if (currentGroup.isEmpty) {
        currentGroup.add(sortedLessons[i]);
      } else {
        bool overlaps = currentGroup.any((lesson) =>
        sortedLessons[i].startMinutes < lesson.endMinutes &&
            sortedLessons[i].endMinutes > lesson.startMinutes);

        if (overlaps) {
          currentGroup.add(sortedLessons[i]);
        } else {
          groups.add(List<BaseLesson>.from(currentGroup));
          currentGroup = [sortedLessons[i]];
        }
      }
    }

    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return groups;
  }

  // Добавьте этот метод в класс _CalendarPageState (например, после _groupOverlappingLessons)
  void _navigateToEditStudent(int studentId, BuildContext context) {
    // Проверяем, есть ли ученик в карте
    if (_studentsMap.containsKey(studentId)) {
      final student = _studentsMap[studentId]!;

      // Показываем загрузку перед переходом
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Задержка для плавного перехода (опционально)
      Future.delayed(const Duration(milliseconds: 300), () {
        Navigator.pop(context); // Закрываем индикатор загрузки

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditStudentScreen(studentId: studentId),
            settings: RouteSettings(
              arguments: {
                'studentId': studentId,
                'studentName': student.name,
              },
            ),
          ),
        );
      });
    } else {
      // Если ученик не найден в кэше
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ученик с ID $studentId не найден'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildLessonWidget(BaseLesson lesson, int index, int totalInGroup, DateTime date) {
    final top = _getTopPosition(lesson.startTime);
    final height = _getLessonHeight(lesson);
    final bool isSingleLesson = lesson is SingleLesson;

    // Получаем информацию об ученике
    final student = _studentsMap[lesson.studentId];
    final studentName = student?.name ?? 'Ученик ${lesson.studentId}';
    final studentDescription = student?.description;
    final studentPrice = student?.price30Min ?? 0;

    // Рассчитываем стоимость занятия
    double lessonCost = 0;
    if (student != null) {
      lessonCost = student.calculateLessonCost(lesson.startTime, lesson.endTime);
    }

    ScheduleException? exception;
    if (lesson is WeeklyLesson) {
      exception = _getExceptionForWeeklyLesson(lesson, date);
    }

    double leftPercent = 0;
    double widthPercent = 1.0;

    if (totalInGroup > 1) {
      widthPercent = 1.0 / totalInGroup;
      leftPercent = index * widthPercent;
    }

    String statusText = '';
    if (exception != null) {
      if (exception.status == 'replaced') {
        statusText = 'Перенесено';
        if (exception.newDate != null && exception.newStartTime != null) {
          statusText += '\nна ${exception.newDate!.day}.${exception.newDate!.month} '
              '${exception.newStartTime!.hour}:${exception.newStartTime!.minute.toString().padLeft(2, '0')}';
        }
      } else if (exception.status == 'declined') {
        statusText = 'Отменено';
      }
    }

    // Определяем цвета
    Color lessonColor;
    Color borderColor;
    Color textColor;

    if (isSingleLesson) {
      // Для одиночных уроков - ЖЕЛТЫЙ
      lessonColor = Colors.yellow.withOpacity(0.2);
      borderColor = Colors.orange;
      textColor = Colors.orange[800]!;
    } else if (exception != null) {
      switch (exception.status) {
        case 'replaced':
          lessonColor = Colors.purple.withOpacity(0.2);
          borderColor = Colors.purple;
          textColor = Colors.purple;
          break;
        case 'declined':
          lessonColor = Colors.red.withOpacity(0.2);
          borderColor = Colors.red;
          textColor = Colors.red;
          break;
        default:
          lessonColor = Colors.pinkAccent.withOpacity(0.2);
          borderColor = Colors.pinkAccent;
          textColor = Colors.pinkAccent;
      }
    } else {
      lessonColor = Colors.pinkAccent.withOpacity(0.2);
      borderColor = Colors.pinkAccent;
      textColor = Colors.pinkAccent;
    }

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: height,
      child: Row(
        children: [
          Expanded(
            flex: (leftPercent * 100).round(),
            child: const SizedBox.shrink(),
          ),
          Expanded(
            flex: (widthPercent * 100).round(),
            child: GestureDetector(
              onTap: () {
                // Навигация на экран редактирования ученика
                _navigateToEditStudent(lesson.studentId, context);
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: lessonColor,
                    border: Border.all(
                      color: borderColor,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Имя ученика с иконкой перехода
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                studentName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 10,
                              color: textColor.withOpacity(0.7),
                            ),
                          ],
                        ),

                        // Описание ученика (если есть)
                        if (studentDescription != null && studentDescription.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              studentDescription,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                        // Стоимость занятия
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Стоимость:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  '${lessonCost.toStringAsFixed(2)} BYN',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Статус и тип занятия
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              if (isSingleLesson)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1), // ОРАНЖЕВЫЙ
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'разовое',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.orange[800]!, // ОРАНЖЕВЫЙ
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (exception != null && exception.status == 'replaced')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'перенесено',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.purple,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (exception != null && exception.status == 'declined')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'отменено',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Дополнительный текст статуса
                        if (statusText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 8,
                                color: textColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                        // Подсказка (только для десктопных устройств)
                        if (Theme.of(context).platform == TargetPlatform.windows ||
                            Theme.of(context).platform == TargetPlatform.linux ||
                            Theme.of(context).platform == TargetPlatform.macOS)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Нажмите для редактирования',
                              style: TextStyle(
                                fontSize: 7,
                                color: textColor.withOpacity(0.6),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: ((1 - leftPercent - widthPercent) * 100).round(),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('EEEE, d MMMM').format(_getDateFromIndex(_currentPageIndex)),
        ),
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
              selected: true,
              onTap: () => Navigator.pop(context),
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
                  MaterialPageRoute(builder: (context) => const AddStudentScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 56,
                  child: SingleChildScrollView(
                    controller: _timeScrollController,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: List.generate(23, (index) {
                        final hour = 11 + index ~/ 2;
                        final isFullHour = index % 2 == 0;
                        return SizedBox(
                          height: 60,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                horizontal: BorderSide(
                                  color: Colors.grey.shade300,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  isFullHour
                                      ? '${hour.toString().padLeft(2, '0')}:00'
                                      : '${hour.toString().padLeft(2, '0')}:30',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.pinkAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pageCount,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final date = _getDateFromIndex(index);
                      final lessonsForDate = _getLessonsForDate(date);
                      final lessonGroups = _groupOverlappingLessons(lessonsForDate);

                      return SingleChildScrollView(
                        controller: _contentScrollController,
                        child: SizedBox(
                          height: 60 * 23,
                          child: Stack(
                            children: [
                              Column(
                                children: List.generate(23, (index) {
                                  return Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade300,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              for (var group in lessonGroups)
                                for (int i = 0; i < group.length; i++)
                                  _buildLessonWidget(group[i], i, group.length, date),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}