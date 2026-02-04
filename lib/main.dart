import 'package:flutter/material.dart';
import 'package:for_repets/all_student.dart';
import 'package:for_repets/statistics_page.dart';
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
      price30Min: (json['price_30_min'] as num?)?.toDouble() ?? 0.0,
    );
  }


}

class BaseLesson {
  final int id;
  final int studentId;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  final bool isReplacedFromCompleted;

  BaseLesson({
    required this.id,
    required this.studentId,
    required this.startTime,
    required this.endTime,
    this.isReplacedFromCompleted = false,
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
    bool isReplacedFromCompleted = false,
  }) : super(
    id: id,
    studentId: studentId,
    startTime: startTime,
    endTime: endTime,
    isReplacedFromCompleted: isReplacedFromCompleted,
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

class CompletedLesson {
  final int id;
  final int studentId;
  final int? scheduleId;
  final DateTime lessonDate;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String type; // 'single', 'weekly', 'replaced', 'declined'

  CompletedLesson({
    required this.id,
    required this.studentId,
    this.scheduleId,
    required this.lessonDate,
    required this.startTime,
    required this.endTime,
    required this.type,
  });

  factory CompletedLesson.fromJson(Map<String, dynamic> json) {
    final startParts = (json['start_time'] as String).split(':');
    final endParts = (json['end_time'] as String).split(':');

    return CompletedLesson(
      id: json['id'] as int,
      studentId: json['student_id'] as int,
      scheduleId: json['schedule_id'] as int?,
      lessonDate: DateTime.parse(json['lesson_date'] as String),
      startTime: TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      ),
      type: json['type'] as String,
    );
  }
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
  List<CompletedLesson> _completedLessons = [];
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
      _fetchCompletedLessons(),
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

  Future<void> _fetchCompletedLessons() async {
    try {
      final response = await Supabase.instance.client
          .from('completed_lessons')
          .select();

      if (response is List) {
        setState(() {
          _completedLessons = response.map((json) => CompletedLesson.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print('Error fetching completed lessons: $e');
    }
  }

  Future<void> _refreshAllData() async {
    setState(() => _isLoading = true);

    try {
      await _loadEssentialData();
    } catch (e) {
      print('Ошибка при обновлении: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось обновить данные: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final result = <BaseLesson>[];
    final now = DateTime.now();
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

    // 1. Исключения (отмены и переносы) — применяем всегда
    final cancelledOnThisDate = <int>{};
    final movedFromThisDay = <int>{};
    final movedToThisDate = <int, BaseLesson>{};

    for (var exception in _exceptions) {
      if (exception.scheduleId == null) continue;

      final isThisDateAffected = exception.date != null &&
          exception.date!.year == date.year &&
          exception.date!.month == date.month &&
          exception.date!.day == date.day;

      final isDeclinedOnThisDate = exception.status == 'declined' &&
          exception.newDate != null &&
          exception.newDate!.year == date.year &&
          exception.newDate!.month == date.month &&
          exception.newDate!.day == date.day;

      if (isDeclinedOnThisDate) {
        cancelledOnThisDate.add(exception.scheduleId!);
      }

      if (exception.status == 'replaced') {
        final original = _weeklyLessons.firstWhere(
              (l) => l.id == exception.scheduleId,
          orElse: () => WeeklyLesson(
            id: -1,
            studentId: 0,
            dayOfWeek: 0,
            startTime: TimeOfDay(hour: 0, minute: 0),
            endTime: TimeOfDay(hour: 0, minute: 0),
          ),
        );

        if (original.id == -1) continue;

        if (isThisDateAffected) movedFromThisDay.add(exception.scheduleId!);

        if (exception.newDate != null &&
            exception.newDate!.year == date.year &&
            exception.newDate!.month == date.month &&
            exception.newDate!.day == date.day &&
            exception.newStartTime != null &&
            exception.newEndTime != null) {
          movedToThisDate[exception.scheduleId!] = WeeklyLesson(
            id: original.id,
            studentId: original.studentId,
            dayOfWeek: exception.newDayOfWeek ?? dayOfWeek,
            startTime: exception.newStartTime!,
            endTime: exception.newEndTime!,
          );
        }
      }
    }

    result.addAll(movedToThisDate.values);

    // 2. Регулярные занятия
    for (var lesson in _weeklyLessons) {
      if (lesson.dayOfWeek != dayOfWeek) continue;

      CompletedLesson? completed;
      try {
        completed = _completedLessons.firstWhere(
              (c) =>
          c.scheduleId == lesson.id &&
              c.lessonDate.year == date.year &&
              c.lessonDate.month == date.month &&
              c.lessonDate.day == date.day,
        );
      } catch (_) {
        completed = null;
      }

      if (completed != null) {
        if (completed.type == 'declined') {
          cancelledOnThisDate.add(lesson.id);
        } else if (completed.type == 'replaced') {
          movedFromThisDay.add(lesson.id);
        }
      }

      if (cancelledOnThisDate.contains(lesson.id)) continue;
      if (movedFromThisDay.contains(lesson.id)) continue;
      if (movedToThisDate.containsKey(lesson.id)) continue;

      result.add(lesson);
    }

    // 3. Одиночные занятия — РАЗДЕЛЯЕМ по isPast
    if (isPast) {
      // Прошлое: берём из completed_lessons (single + replaced)
      for (var cl in _completedLessons) {
        if (cl.lessonDate.year == date.year &&
            cl.lessonDate.month == date.month &&
            cl.lessonDate.day == date.day) {
          if (cl.type == 'single') {
            result.add(SingleLesson(
              id: cl.id,
              studentId: cl.studentId,
              startTime: cl.startTime,
              endTime: cl.endTime,
              date: cl.lessonDate,
            ));
          } else if (cl.type == 'replaced') {
            WeeklyLesson? originalWeekly;
            if (cl.scheduleId != null) {
              try {
                originalWeekly = _weeklyLessons.firstWhere(
                      (l) => l.id == cl.scheduleId,
                );
              } catch (_) {}
            }

            if (originalWeekly != null) {
              result.add(WeeklyLesson(
                id: originalWeekly.id,
                studentId: cl.studentId,
                dayOfWeek: originalWeekly.dayOfWeek,
                startTime: cl.startTime,
                endTime: cl.endTime,
                isReplacedFromCompleted: true,
              ));
            } else {
              result.add(BaseLesson(
                id: cl.id,
                studentId: cl.studentId,
                startTime: cl.startTime,
                endTime: cl.endTime,
                isReplacedFromCompleted: true,
              ));
            }
          }
        }
      }
    } else {
      // Будущее (включая сегодня): берём из single_lessons
      for (var single in _singleLessons) {
        if (single.date.year == date.year &&
            single.date.month == date.month &&
            single.date.day == date.day) {
          result.add(single);
        }
      }
    }

    // 4. Удаляем дубликаты (по студенту + времени)
    final uniqueResult = <BaseLesson>[];
    final seen = <String>{};

    for (var lesson in result) {
      final key = '${lesson.studentId}_${lesson.startMinutes}_${lesson.endMinutes}';
      if (seen.add(key)) {
        uniqueResult.add(lesson);
      }
    }

    uniqueResult.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return uniqueResult;
  }

  ScheduleException? _getExceptionForWeeklyLesson(WeeklyLesson lesson, DateTime date) {
    for (var exception in _exceptions) {
      if (exception.scheduleId != lesson.id) continue;

      final bool isThisDateAffected =
          exception.date != null &&
              exception.date!.isAtSameMomentAs(date);

      final bool isDeclinedOnThisDate =
          exception.status == 'declined' &&
              exception.newDate != null &&
              exception.newDate!.isAtSameMomentAs(date);

      final bool isReplacedOnThisDate =
          exception.status == 'replaced' &&
              exception.newDate != null &&
              exception.newDate!.isAtSameMomentAs(date) &&
              exception.newStartTime != null &&
              exception.newStartTime!.hour == lesson.startTime.hour &&
              exception.newStartTime!.minute == lesson.startTime.minute;

      if (isDeclinedOnThisDate || isReplacedOnThisDate || isThisDateAffected) {
        return exception;
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
    final double price30Min = student?.price30Min ?? 0.0;
    int maxDescLines = 0;

    double lessonCost = 0.0;
    if (student != null && price30Min > 0) {
      final startMinutes = lesson.startTime.hour * 60 + lesson.startTime.minute;
      final endMinutes   = lesson.endTime.hour   * 60 + lesson.endTime.minute;
      final durationMinutes = endMinutes - startMinutes;
      maxDescLines = (durationMinutes <= 30) ? 1 : 2;

      if (durationMinutes > 0) {
        lessonCost = (durationMinutes / 30) * price30Min;
      }
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

    // Определяем цвета
    Color lessonColor;
    Color borderColor;
    Color textColor;


    if (isSingleLesson) {
      lessonColor = Colors.yellow.withOpacity(0.2);
      borderColor = Colors.orange;
      textColor = Colors.orange[800]!;
    }
    else if (lesson.isReplacedFromCompleted || (lesson is WeeklyLesson && _getExceptionForWeeklyLesson(lesson, date)?.status == 'replaced')) {
      lessonColor = Colors.purple.withOpacity(0.2);
      borderColor = Colors.purple;
      textColor = Colors.purple;
    }
    else if (exception != null) {
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
    }
    else {
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  studentName,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  softWrap: true,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${lessonCost.toStringAsFixed(2)} BYN',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                      maxLines: 1,
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 20,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ],
                                ),
                              ],
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
                              maxLines: maxDescLines,
                              overflow: TextOverflow.ellipsis,
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
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Статистика'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StatisticsPage()),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshAllData,
        tooltip: 'Обновить',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}