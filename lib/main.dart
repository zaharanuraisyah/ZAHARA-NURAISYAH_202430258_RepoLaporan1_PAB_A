import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

// ============================================================
// 1. MODEL DATA
// ============================================================

class StudyTask {
  StudyTask({
    required this.id,
    required this.title,
    required this.subject,
    required this.date,
    required this.priority,
    required this.duration,
    this.notes = '',
    this.isCompleted = false,
  });

  final String id;
  String title;
  String subject;
  DateTime date;
  String priority;
  int duration;
  String notes;
  bool isCompleted;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'date': date.toIso8601String(),
      'priority': priority,
      'duration': duration,
      'notes': notes,
      'isCompleted': isCompleted,
    };
  }

  factory StudyTask.fromJson(Map<String, dynamic> json) {
    return StudyTask(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'Other',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ??
          DateTime.now(),
      priority: json['priority']?.toString() ?? 'Medium',
      duration: (json['duration'] as num?)?.toInt() ?? 30,
      notes: json['notes']?.toString() ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}

// ============================================================
// 2. APP THEME
// ============================================================

class PlannerColors {
  static const background = Color(0xFFFFF8FA);
  static const pink = Color(0xFFE8A0B5);
  static const darkPink = Color(0xFFC86F91);
  static const palePink = Color(0xFFFBE4EC);
  static const lavender = Color(0xFFEAE5FA);
  static const cream = Color(0xFFFFF0D9);
  static const mint = Color(0xFFE0F2E8);
  static const ink = Color(0xFF493740);
  static const muted = Color(0xFF98858F);
  static const border = Color(0xFFF0E4E9);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Little Study Space',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: PlannerColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: PlannerColors.pink,
          primary: PlannerColors.darkPink,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: PlannerColors.background,
          foregroundColor: PlannerColors.ink,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: PlannerColors.background,
          hintStyle: const TextStyle(
            color: PlannerColors.muted,
            fontSize: 13,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: PlannerColors.border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: PlannerColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: PlannerColors.pink,
              width: 1.5,
            ),
          ),
        ),
      ),
      home: const StudyPlannerPage(),
    );
  }
}

// ============================================================
// 3. MAIN PAGE
// ============================================================

class StudyPlannerPage extends StatefulWidget {
  const StudyPlannerPage({super.key});

  @override
  State<StudyPlannerPage> createState() => _StudyPlannerPageState();
}

class _StudyPlannerPageState extends State<StudyPlannerPage> {
  static const String _storageKey = 'my_little_study_space_tasks';

  final List<StudyTask> _tasks = [];

  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  bool _isLoading = true;
  bool _showCompleted = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Load tasks from local storage.
  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final loadedTasks = decoded
            .map(
              (item) => StudyTask.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();

        if (!mounted) return;

        setState(() {
          _tasks
            ..clear()
            ..addAll(loadedTasks);
        });
      }
    } catch (error) {
      debugPrint('Could not load tasks: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Save tasks to local storage.
  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _storageKey,
        jsonEncode(_tasks.map((task) => task.toJson()).toList()),
      );
    } catch (error) {
      debugPrint('Could not save tasks: $error');
    }
  }

List<StudyTask> get _visibleTasks {
  final result = _tasks.where((task) {
    final matchesSearch =
        task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        task.subject.toLowerCase().contains(_searchQuery.toLowerCase());

    final matchesFilter =
        _selectedFilter == 'All' || task.subject == _selectedFilter;

    final matchesStatus = _showCompleted || !task.isCompleted;

    return matchesSearch && matchesFilter && matchesStatus;
  }).toList();

  // Tugas yang belum selesai ditampilkan lebih dahulu.
  // Di dalam kelompoknya, tugas dengan prioritas tinggi berada di atas.
  result.sort((a, b) {
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }

    const priorityOrder = {
      'High': 0,
      'Medium': 1,
      'Low': 2,
    };

    final priorityComparison =
        (priorityOrder[a.priority] ?? 1)
            .compareTo(priorityOrder[b.priority] ?? 1);

    if (priorityComparison != 0) {
      return priorityComparison;
    }

    // Jika prioritas sama, deadline terdekat ditampilkan lebih dahulu.
    return a.date.compareTo(b.date);
  });

  return result;
}



  int get _completedCount =>
      _tasks.where((task) => task.isCompleted).length;

  int get _todayCount {
    return _tasks
        .where((task) => DateUtils.isSameDay(task.date, DateTime.now()))
        .length;
  }

  int get _todayCompletedCount {
    return _tasks
        .where(
          (task) =>
              DateUtils.isSameDay(task.date, DateTime.now()) &&
              task.isCompleted,
        )
        .length;
  }

  int get _totalMinutes {
    return _tasks
        .where((task) => task.isCompleted)
        .fold<int>(0, (total, task) => total + task.duration);
  }

  double get _progress {
    if (_tasks.isEmpty) return 0;
    return _completedCount / _tasks.length;
  }

  Future<void> _openTaskForm({StudyTask? task}) async {
    final result = await showDialog<StudyTask>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return TaskFormDialog(
          task: task,
          initialDate: _selectedDate,
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      final existingIndex =
          _tasks.indexWhere((item) => item.id == result.id);

      if (existingIndex == -1) {
        _tasks.add(result);
      } else {
        _tasks[existingIndex] = result;
      }

      _selectedDate = DateUtils.dateOnly(result.date);
    });

    await _saveTasks();
  }

  Future<void> _deleteTask(StudyTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Delete this task?'),
          content: const Text(
            'Your task will be removed from your study planner.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: PlannerColors.darkPink,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() => _tasks.removeWhere((item) => item.id == task.id));
    await _saveTasks();
  }

  Future<void> _toggleTask(StudyTask task) async {
    setState(() => task.isCompleted = !task.isCompleted);
    await _saveTasks();
  }

  Future<void> _clearTasks() async {
    if (_tasks.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Clear all tasks?'),
          content: const Text(
            'This will permanently remove all your saved tasks.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Clear all'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() => _tasks.clear());
    await _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        backgroundColor: PlannerColors.darkPink,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New task',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: PlannerColors.darkPink,
                ),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildWelcomeCard(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildStats(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildCalendar(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildTaskHeader(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildSearchAndFilter(),
                  ),
                  _buildTaskList(),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
      ),
    );
  }

  // ==========================================================
  // 4. HEADER
  // ==========================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: PlannerColors.palePink,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.local_florist_rounded,
              color: PlannerColors.darkPink,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Little Study Space',
                  style: TextStyle(
                    color: PlannerColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'your cozy little productivity corner',
                  style: TextStyle(
                    color: PlannerColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _showSettings,
            icon: const Icon(
              Icons.settings_outlined,
              color: PlannerColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 5. WELCOME CARD
  // ==========================================================

  Widget _buildWelcomeCard() {
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFF9DCE6),
              Color(0xFFFCEAF0),
              Color(0xFFFFF0E9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: 0,
              top: 0,
              child: Icon(
                Icons.auto_awesome,
                color: Color(0xFFD98AA5),
                size: 29,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(190),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_weekday(today.weekday)}  ·  ${today.day} ${_month(today.month)}',
                    style: const TextStyle(
                      color: PlannerColors.darkPink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                const Text(
                  'A little progress\nis still progress ♡',
                  style: TextStyle(
                    color: PlannerColors.ink,
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _todayCount == 0
                      ? 'Make today a little more meaningful.'
                      : 'You have $_todayCount task(s) planned for today.',
                  style: const TextStyle(
                    color: PlannerColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _todayCount == 0
                              ? 0
                              : _todayCompletedCount / _todayCount,
                          minHeight: 7,
                          backgroundColor: Colors.white,
                          valueColor: const AlwaysStoppedAnimation(
                            PlannerColors.darkPink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _todayCount == 0
                          ? '0%'
                          : '${((_todayCompletedCount / _todayCount) * 100).round()}%',
                      style: const TextStyle(
                        color: PlannerColors.darkPink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 6. SUMMARY CARDS
  // ==========================================================

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'Your little achievements',
            subtitle: 'Every small step counts',
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  icon: Icons.menu_book_rounded,
                  label: 'Tasks',
                  value: '${_tasks.length}',
                  caption: 'total plans',
                  color: PlannerColors.palePink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryCard(
                  icon: Icons.check_circle_rounded,
                  label: 'Completed',
                  value: '$_completedCount',
                  caption: 'tasks done',
                  color: PlannerColors.mint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryCard(
                  icon: Icons.favorite_rounded,
                  label: 'Study time',
                  value: '${(_totalMinutes / 60).toStringAsFixed(1)}h',
                  caption: 'time invested',
                  color: PlannerColors.lavender,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: PlannerColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: PlannerColors.cream,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.spa_rounded,
                    color: Color(0xFFBD8A46),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your overall progress',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: PlannerColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${(_progress * 100).round()}% of all tasks completed',
                        style: const TextStyle(
                          fontSize: 11,
                          color: PlannerColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 4,
                        backgroundColor: PlannerColors.palePink,
                        valueColor: const AlwaysStoppedAnimation(
                          PlannerColors.darkPink,
                        ),
                      ),
                      Text(
                        '${(_progress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
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
    );
  }

  // ==========================================================
  // 7. WEEKLY CALENDAR
  // ==========================================================

  Widget _buildCalendar() {
    final weekStart = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeading(
                  title: 'Study calendar',
                  subtitle: 'Choose your day',
                ),
              ),
              IconButton(
                tooltip: 'Previous week',
                onPressed: () {
                  setState(() {
                    _selectedDate =
                        _selectedDate.subtract(const Duration(days: 7));
                  });
                },
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Next week',
                onPressed: () {
                  setState(() {
                    _selectedDate =
                        _selectedDate.add(const Duration(days: 7));
                  });
                },
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(7, (index) {
              final date = weekStart.add(Duration(days: index));
              final selected = DateUtils.isSameDay(date, _selectedDate);
              final today = DateUtils.isSameDay(date, DateTime.now());

              final hasTasks = _tasks.any(
                (task) => DateUtils.isSameDay(task.date, date),
              );

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _selectedDate = DateUtils.dateOnly(date);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: selected
                            ? PlannerColors.darkPink
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? PlannerColors.darkPink
                              : PlannerColors.border,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: PlannerColors.pink.withAlpha(65),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            _weekdayShort(date.weekday),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white70
                                  : PlannerColors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? Colors.white
                                  : PlannerColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasTasks
                                  ? (selected
                                      ? Colors.white
                                      : PlannerColors.pink)
                                  : (today && !selected
                                      ? PlannerColors.darkPink
                                      : Colors.transparent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: PlannerColors.darkPink,
                          surface: Colors.white,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (!mounted || picked == null) return;

                setState(() {
                  _selectedDate = DateUtils.dateOnly(picked);
                });
              },
              icon: const Icon(Icons.calendar_month_rounded, size: 17),
              label: const Text('Open full calendar'),
              style: TextButton.styleFrom(
                foregroundColor: PlannerColors.darkPink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 8. TASK HEADER
  // ==========================================================


  // ==========================================================
  // 8. TASK SECTION HEADER
  // ==========================================================

  Widget _buildTaskHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: SectionHeading(
              title: 'My study tasks',
              subtitle: 'Little steps, big progress',
            ),
          ),
          Text(
            '${_tasks.length} tasks',
            style: const TextStyle(
              color: PlannerColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 9. SEARCH AND FILTER
  // ==========================================================

  Widget _buildSearchAndFilter() {
    const subjects = [
      'All',
      'Assignment',
      'Exam',
      'Project',
      'Reading',
      'Other',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      child: Column(
        children: [
          TextField(
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            decoration: const InputDecoration(
              hintText: 'Search your tasks...',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: PlannerColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subjects.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final subject = subjects[index];
                final selected = _selectedFilter == subject;

                return ChoiceChip(
                  label: Text(subject),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() => _selectedFilter = subject);
                  },
                  backgroundColor: Colors.white,
                  selectedColor: PlannerColors.palePink,
                  side: BorderSide(
                    color: selected
                        ? PlannerColors.pink
                        : PlannerColors.border,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: selected
                        ? PlannerColors.darkPink
                        : PlannerColors.muted,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 10. TASK LIST
  // ==========================================================

  Widget _buildTaskList() {
    final tasks = _visibleTasks;

    if (tasks.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: PlannerColors.border),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.spa_rounded,
                  size: 48,
                  color: PlannerColors.pink,
                ),
                const SizedBox(height: 14),
                const Text(
                  'A fresh page awaits ♡',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: PlannerColors.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _searchQuery.isNotEmpty || _selectedFilter != 'All'
                      ? 'No matching tasks. Try another search or filter.'
                      : 'No plans for ${_selectedDate.day} ${_month(_selectedDate.month)} yet.\nTap New task to start planning.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PlannerColors.muted,
                    height: 1.6,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = tasks[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ActivityCard(
                task: task,
                onToggle: () => _toggleTask(task),
                onEdit: () => _openTaskForm(task: task),
                onDelete: () => _deleteTask(task),
              ),
            );
          },
          childCount: tasks.length,
        ),
      ),
    );
  }

  // ==========================================================
  // 11. SETTINGS
  // ==========================================================

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Little space settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: PlannerColors.ink,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _showCompleted,
                  activeTrackColor: PlannerColors.pink,
                  title: const Text(
                    'Show completed tasks',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Display finished tasks in your list',
                    style: TextStyle(fontSize: 12),
                  ),
                  onChanged: (value) {
                    setState(() => _showCompleted = value);
                    Navigator.pop(sheetContext);
                  },
                ),
                const Divider(color: PlannerColors.border),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.delete_sweep_outlined,
                    color: PlannerColors.darkPink,
                  ),
                  title: const Text('Clear all tasks'),
                  subtitle: const Text(
                    'Remove every saved study plan',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _clearTasks();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// 12. CUSTOM WIDGET: SECTION HEADING
// ============================================================

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            color: PlannerColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: PlannerColors.muted,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 13. CUSTOM WIDGET: SUMMARY CARD
// ============================================================

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: PlannerColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: PlannerColors.darkPink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: PlannerColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: PlannerColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: PlannerColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 14. CUSTOM WIDGET: ACTIVITY CARD
// ============================================================

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final StudyTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color get _subjectColor {
    switch (task.subject) {
      case 'Assignment':
        return PlannerColors.palePink;
      case 'Exam':
        return PlannerColors.lavender;
      case 'Project':
        return PlannerColors.mint;
      case 'Reading':
        return PlannerColors.cream;
      default:
        return const Color(0xFFF0EDF0);
    }
  }

  Color get _priorityColor {
    switch (task.priority) {
      case 'High':
        return const Color(0xFFC85C75);
      case 'Medium':
        return const Color(0xFFC18B3C);
      default:
        return const Color(0xFF77A88A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: PlannerColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: task.isCompleted
                      ? PlannerColors.darkPink
                      : Colors.white,
                  border: Border.all(
                    color: task.isCompleted
                        ? PlannerColors.darkPink
                        : PlannerColors.pink,
                    width: 1.7,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 17,
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _smallTag(
                      task.subject,
                      _subjectColor,
                      PlannerColors.ink,
                    ),
                    _smallTag(
                      task.priority,
                      _priorityColor.withAlpha(25),
                      _priorityColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  task.title,
                  style: TextStyle(
                    color: task.isCompleted
                        ? PlannerColors.muted
                        : PlannerColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (task.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    task.notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PlannerColors.muted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 13,
                  runSpacing: 6,
                  children: [
                    _info(
                      Icons.calendar_today_rounded,
                      '${task.date.day} ${_month(task.date.month)}',
                    ),
                    _info(
                      Icons.schedule_rounded,
                      '${task.duration} min',
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Task options',
            icon: const Icon(
              Icons.more_horiz_rounded,
              color: PlannerColors.muted,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 9),
                    Text('Edit task'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18),
                    SizedBox(width: 9),
                    Text('Delete task'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallTag(String text, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: PlannerColors.muted,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: PlannerColors.muted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// 15. TASK FORM DIALOG
// ============================================================

class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({
    super.key,
    this.task,
    required this.initialDate,
  });

  final StudyTask? task;
  final DateTime initialDate;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  late String _subject;
  late String _priority;
  late int _duration;
  late DateTime _date;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _titleController = TextEditingController(
      text: task?.title ?? '',
    );

    _notesController = TextEditingController(
      text: task?.notes ?? '',
    );

    _subject = task?.subject ?? 'Assignment';
    _priority = task?.priority ?? 'Medium';
    _duration = task?.duration ?? 30;
    _date = DateUtils.dateOnly(task?.date ?? widget.initialDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: PlannerColors.darkPink,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || picked == null) return;

    setState(() => _date = DateUtils.dateOnly(picked));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.task;

    final task = StudyTask(
      id: existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      subject: _subject,
      date: _date,
      priority: _priority,
      duration: _duration,
      notes: _notesController.text.trim(),
      isCompleted: existing?.isCompleted ?? false,
    );

    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: PlannerColors.palePink,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.edit_calendar_rounded,
                        color: PlannerColors.darkPink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit your plan' : 'New study plan',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: PlannerColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Make a little plan for yourself ♡',
                            style: TextStyle(
                              color: PlannerColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 23),
                _fieldLabel('Task name *'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Finish Flutter assignment',
                    counterText: '',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a task name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 17),
                _fieldLabel('Category'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _subject,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Assignment',
                      child: Text('Assignment'),
                    ),
                    DropdownMenuItem(
                      value: 'Exam',
                      child: Text('Exam'),
                    ),
                    DropdownMenuItem(
                      value: 'Project',
                      child: Text('Project'),
                    ),
                    DropdownMenuItem(
                      value: 'Reading',
                      child: Text('Reading'),
                    ),
                    DropdownMenuItem(
                      value: 'Other',
                      child: Text('Other'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _subject = value);
                    }
                  },
                ),
                const SizedBox(height: 17),
                _fieldLabel('Priority'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'High',
                      child: Text('High priority'),
                    ),
                    DropdownMenuItem(
                      value: 'Medium',
                      child: Text('Medium priority'),
                    ),
                    DropdownMenuItem(
                      value: 'Low',
                      child: Text('Low priority'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _priority = value);
                    }
                  },
                ),
                const SizedBox(height: 17),
                _fieldLabel('Deadline'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _chooseDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: PlannerColors.background,
                      border: Border.all(
                        color: PlannerColors.border,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: PlannerColors.darkPink,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_date.day} ${_month(_date.month)} ${_date.year}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PlannerColors.ink,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: PlannerColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                _fieldLabel('Estimated study time'),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: _duration,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.schedule_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15 minutes')),
                    DropdownMenuItem(value: 30, child: Text('30 minutes')),
                    DropdownMenuItem(value: 45, child: Text('45 minutes')),
                    DropdownMenuItem(value: 60, child: Text('1 hour')),
                    DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                    DropdownMenuItem(value: 120, child: Text('2 hours')),
                    DropdownMenuItem(value: 180, child: Text('3 hours')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _duration = value);
                    }
                  },
                ),
                const SizedBox(height: 17),
                _fieldLabel('Notes (optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    hintText: 'Add a little reminder...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: Icon(
                      _isEditing
                          ? Icons.check_rounded
                          : Icons.favorite_rounded,
                    ),
                    label: Text(
                      _isEditing ? 'Save changes' : 'Create my plan',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: PlannerColors.darkPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                const Center(
                  child: Text(
                    'You are doing better than you think ♡',
                    style: TextStyle(
                      color: PlannerColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: PlannerColors.ink,
      ),
    );
  }
}

// ============================================================
// 16. DATE HELPERS
// ============================================================

String _weekday(int weekday) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  return names[weekday - 1];
}

String _weekdayShort(int weekday) {
  const names = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  return names[weekday - 1];
}

String _month(int month) {
  const names = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return names[month - 1];
}
