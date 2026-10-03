import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const ProductivityApp());
}

class ProductivityApp extends StatelessWidget {
  const ProductivityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiniPad Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        fontFamily: 'Segoe UI',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Segoe UI',
      ),
      themeMode: ThemeMode.system,
      home: const ProductivityHome(),
    );
  }
}

enum TaskRecurrence { none, daily, weekly, monthly }

class DeviceSize {
  static bool isIPadMini(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return width < 768 && width > 500 && height < 1024;
  }

  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 600;

  static EdgeInsets getPadding(BuildContext context) {
    if (isIPadMini(context)) {
      return const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    }
    return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  }

  static double getCardHeight(BuildContext context) {
    return isIPadMini(context) ? 100 : 120;
  }

  static double getSpacing(BuildContext context) {
    return isIPadMini(context) ? 12 : 16;
  }
}

class Project {
  Project({
    required this.name,
    this.icon = 'folder',
    this.color = 'purple',
    this.description = '',
  }) : id = const Uuid().v4();

  final String id;
  final String name;
  final String icon;
  final String color;
  final String description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'description': description,
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        name: json['name'] as String,
        icon: json['icon'] as String? ?? 'folder',
        color: json['color'] as String? ?? 'purple',
        description: json['description'] as String? ?? '',
      );
}

class TaskItem {
  TaskItem({
    required this.title,
    this.notes = '',
    this.projectId,
    this.dueDate,
    this.priority = 'medium',
    this.isDone = false,
    this.recurrence = TaskRecurrence.none,
    this.tags = const [],
  }) : id = const Uuid().v4();

  final String id;
  final String title;
  final String notes;
  final String? projectId;
  final DateTime? dueDate;
  final String priority;
  bool isDone;
  final TaskRecurrence recurrence;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'projectId': projectId,
        'dueDate': dueDate?.toIso8601String(),
        'priority': priority,
        'isDone': isDone,
        'recurrence': recurrence.toString(),
        'tags': tags,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        title: json['title'] as String,
        notes: json['notes'] as String? ?? '',
        projectId: json['projectId'] as String?,
        dueDate: json['dueDate'] == null ? null : DateTime.parse(json['dueDate'] as String),
        priority: json['priority'] as String? ?? 'medium',
        isDone: json['isDone'] as bool? ?? false,
        recurrence: _parseRecurrence(json['recurrence'] as String?),
        tags: List<String>.from(json['tags'] as List? ?? []),
      );

  static TaskRecurrence _parseRecurrence(String? value) {
    if (value == null) return TaskRecurrence.none;
    return TaskRecurrence.values.firstWhere((e) => e.toString() == value, orElse: () => TaskRecurrence.none);
  }

  bool get isOverdue => !isDone && dueDate != null && dueDate!.isBefore(DateTime.now());
  bool get isDueToday => !isDone && dueDate != null && DateTime(dueDate!.year, dueDate!.month, dueDate!.day).compareTo(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) == 0;
}

class NoteItem {
  NoteItem({
    required this.title,
    this.content = '',
    this.projectId,
  }) : id = const Uuid().v4();

  final String id;
  final String title;
  final String content;
  final String? projectId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'projectId': projectId,
      };

  factory NoteItem.fromJson(Map<String, dynamic> json) => NoteItem(
        title: json['title'] as String,
        content: json['content'] as String? ?? '',
        projectId: json['projectId'] as String?,
      );
}

class AppStore extends ChangeNotifier {
  AppStore() {
    _load();
  }

  final List<Project> projects = [
    Project(name: 'Work', icon: 'work', color: 'purple', description: 'Professional projects'),
    Project(name: 'Personal', icon: 'person', color: 'green', description: 'Personal goals'),
    Project(name: 'Study', icon: 'school', color: 'blue', description: 'Learning & development'),
  ];

  final List<TaskItem> tasks = [];
  final List<NoteItem> notes = [];

  bool _isLoaded = false;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final savedProjects = prefs.getStringList('projects');
    if (savedProjects != null) {
      projects.clear();
      for (final item in savedProjects) {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        projects.add(Project.fromJson(decoded));
      }
    }

    final savedTasks = prefs.getStringList('tasks');
    if (savedTasks != null) {
      tasks.clear();
      for (final item in savedTasks) {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        tasks.add(TaskItem.fromJson(decoded));
      }
    }

    final savedNotes = prefs.getStringList('notes');
    if (savedNotes != null) {
      notes.clear();
      for (final item in savedNotes) {
        final decoded = jsonDecode(item) as Map<String, dynamic>;
        notes.add(NoteItem.fromJson(decoded));
      }
    }

    if (!_isLoaded) {
      _seedDefaults();
    }

    _isLoaded = true;
    notifyListeners();
  }

  void _seedDefaults() {
    if (tasks.isNotEmpty || notes.isNotEmpty) return;

    tasks.addAll([
      TaskItem(
        title: 'Review product roadmap',
        notes: 'Finalize design handoff for sprint review.',
        projectId: projects.first.id,
        dueDate: DateTime.now().add(const Duration(days: 2)),
        priority: 'high',
        tags: ['review', 'urgent'],
      ),
      TaskItem(
        title: 'Plan personal errands',
        notes: 'Groceries and appointment calls.',
        projectId: projects[1].id,
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: 'medium',
        tags: ['errands'],
      ),
      TaskItem(
        title: 'Weekly team standup',
        notes: 'Prepare update on progress.',
        projectId: projects.first.id,
        dueDate: DateTime.now(),
        priority: 'high',
        isDone: true,
        recurrence: TaskRecurrence.weekly,
      ),
    ]);

    notes.addAll([
      NoteItem(
        title: 'Daily focus',
        content: 'Prioritize one important task before responding to messages.',
      ),
      NoteItem(
        title: 'Ideas',
        content: 'Create a bite-sized check-in for team updates.',
        projectId: projects.first.id,
      ),
    ]);

    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'projects',
      projects.map((e) => jsonEncode(e.toJson())).toList(),
    );
    await prefs.setStringList(
      'tasks',
      tasks.map((e) => jsonEncode(e.toJson())).toList(),
    );
    await prefs.setStringList(
      'notes',
      notes.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  void addProject(String name, {String description = ''}) {
    if (name.trim().isEmpty) return;
    projects.add(Project(name: name.trim(), description: description.trim()));
    notifyListeners();
    _save();
  }

  void addTask(String title, {String notes = '', String? projectId, DateTime? dueDate, String priority = 'medium', List<String> tags = const []}) {
    if (title.trim().isEmpty) return;
    tasks.insert(
      0,
      TaskItem(
        title: title.trim(),
        notes: notes.trim(),
        projectId: projectId,
        dueDate: dueDate,
        priority: priority,
        tags: tags,
      ),
    );
    notifyListeners();
    _save();
  }

  void toggleTask(TaskItem task) {
    final index = tasks.indexWhere((element) => element.id == task.id);
    if (index == -1) return;
    tasks[index].isDone = !tasks[index].isDone;
    notifyListeners();
    _save();
  }

  void deleteTask(TaskItem task) {
    tasks.removeWhere((element) => element.id == task.id);
    notifyListeners();
    _save();
  }

  void addNote(String title, {String content = '', String? projectId}) {
    if (title.trim().isEmpty && content.trim().isEmpty) return;
    notes.insert(
      0,
      NoteItem(
        title: title.trim().isEmpty ? 'Untitled Note' : title.trim(),
        content: content.trim(),
        projectId: projectId,
      ),
    );
    notifyListeners();
    _save();
  }

  void deleteNote(NoteItem note) {
    notes.removeWhere((element) => element.id == note.id);
    notifyListeners();
    _save();
  }

  String projectName(String? projectId) {
    final project = projects.where((element) => element.id == projectId).firstOrNull;
    return project?.name ?? 'General';
  }

  List<TaskItem> tasksForProject(String? projectId) => tasks.where((task) => task.projectId == projectId).toList();

  List<TaskItem> todayTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return tasks.where((task) => !task.isDone && task.dueDate != null && DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day).compareTo(today) == 0).toList();
  }

  List<TaskItem> overdueTasks() => tasks.where((task) => task.isOverdue).toList()..sort((a, b) => (a.dueDate ?? DateTime.now()).compareTo(b.dueDate ?? DateTime.now()));

  List<TaskItem> upcomingTasks() => tasks.where((task) => !task.isDone && task.dueDate != null).toList()..sort((a, b) => (a.dueDate ?? DateTime.now()).compareTo(b.dueDate ?? DateTime.now()));

  int get completedTasks => tasks.where((task) => task.isDone).length;
  int get openTasks => tasks.where((task) => !task.isDone).length;
  double get completionRate => tasks.isEmpty ? 0 : (completedTasks / tasks.length) * 100;
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class ProductivityHome extends StatefulWidget {
  const ProductivityHome({super.key});

  @override
  State<ProductivityHome> createState() => _ProductivityHomeState();
}

class _ProductivityHomeState extends State<ProductivityHome> {
  int _selectedIndex = 0;
  late final AppStore _store;

  @override
  void initState() {
    super.initState();
    _store = AppStore();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(store: _store),
      TasksScreen(store: _store),
      CalendarScreen(store: _store),
      ProjectsScreen(store: _store),
      NotesScreen(store: _store),
    ];

    final isLargeTablet = MediaQuery.of(context).size.width >= 900;
    final isTablet = DeviceSize.isTablet(context);
    final isIPadMini = DeviceSize.isIPadMini(context);

    if (isLargeTablet) {
      return AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (value) => setState(() => _selectedIndex = value),
                  labelType: NavigationRailLabelType.all,
                  extended: true,
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: Text('Tasks')),
                    NavigationRailDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: Text('Calendar')),
                    NavigationRailDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: Text('Projects')),
                    NavigationRailDestination(icon: Icon(Icons.note_alt_outlined), selectedIcon: Icon(Icons.note_alt), label: Text('Notes')),
                  ],
                ),
                Expanded(child: screens[_selectedIndex]),
              ],
            ),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        return Scaffold(
          body: screens[_selectedIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (value) => setState(() => _selectedIndex = value),
            height: isIPadMini ? 65 : 80,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
              NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Tasks'),
              NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
              NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Projects'),
              NavigationDestination(icon: Icon(Icons.note_alt_outlined), selectedIcon: Icon(Icons.note_alt), label: 'Notes'),
            ],
          ),
        );
      },
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final isIPadMini = DeviceSize.isIPadMini(context);
    final spacing = DeviceSize.getSpacing(context);
    final padding = DeviceSize.getPadding(context);
    final upcomingTasks = store.upcomingTasks().take(5).toList();
    final overdueTasks = store.overdueTasks();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Good morning', style: TextStyle(fontSize: isIPadMini ? 14 : 16, color: Colors.grey)),
                      SizedBox(height: spacing / 2),
                      Text('Your focus dashboard', style: TextStyle(fontSize: isIPadMini ? 24 : 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.all(spacing),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('${store.completionRate.toStringAsFixed(1)}%', style: TextStyle(fontSize: isIPadMini ? 18 : 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                        Text('Complete', style: TextStyle(fontSize: isIPadMini ? 10 : 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing + 8),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: spacing - 4,
                mainAxisSpacing: spacing - 4,
                childAspectRatio: isIPadMini ? 1.8 : 1.6,
                children: [
                  StatCard(title: 'Tasks', value: '${store.tasks.length}', color: Colors.blue, icon: Icons.task_alt),
                  StatCard(title: 'Done', value: '${store.completedTasks}', color: Colors.green, icon: Icons.check_circle),
                  StatCard(title: 'Open', value: '${store.openTasks}', color: Colors.orange, icon: Icons.hourglass_empty),
                  StatCard(title: 'Projects', value: '${store.projects.length}', color: Colors.purple, icon: Icons.folder),
                ],
              ),
              SizedBox(height: spacing + 8),
              if (overdueTasks.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    SizedBox(width: spacing / 2),
                    const Text('Overdue Tasks', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    const Spacer(),
                    Text('${overdueTasks.length}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                SizedBox(height: spacing - 4),
                ...overdueTasks.take(2).map((task) => Padding(padding: EdgeInsets.only(bottom: spacing - 4), child: PremiumTaskCard(task: task, store: store))),
                SizedBox(height: spacing),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Today\u2019s focus', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${store.todayTasks().length} items', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              SizedBox(height: spacing - 4),
              if (store.todayTasks().isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(spacing + 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: const Center(
                    child: Text('No tasks today. Great work!', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ),
                )
              else
                ...store.todayTasks().map((task) => Padding(padding: EdgeInsets.only(bottom: spacing - 4), child: PremiumTaskCard(task: task, store: store))),
              SizedBox(height: spacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Upcoming', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${upcomingTasks.length} items', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              SizedBox(height: spacing - 4),
              if (upcomingTasks.isEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(spacing + 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: const Center(child: Text('No upcoming tasks', style: TextStyle(color: Colors.grey, fontSize: 14))),
                )
              else
                ...upcomingTasks.take(3).map((task) => Padding(padding: EdgeInsets.only(bottom: spacing - 4), child: UpcomingTaskCard(task: task, store: store))),
              SizedBox(height: spacing + 8),
            ],
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.color, required this.icon});

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isIPadMini = DeviceSize.isIPadMini(context);

    return Container(
      padding: EdgeInsets.all(isIPadMini ? 10 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(isIPadMini ? 5 : 6),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: isIPadMini ? 16 : 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey, fontSize: isIPadMini ? 10 : 11, fontWeight: FontWeight.w500)),
              SizedBox(height: isIPadMini ? 2 : 3),
              Text(value, style: TextStyle(fontSize: isIPadMini ? 20 : 24, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class PremiumTaskCard extends StatelessWidget {
  const PremiumTaskCard({super.key, required this.task, required this.store});

  final TaskItem task;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final isIPadMini = DeviceSize.isIPadMini(context);
    final spacing = DeviceSize.getSpacing(context);

    return Container(
      padding: EdgeInsets.all(isIPadMini ? 10 : 12),
      decoration: BoxDecoration(
        color: task.isOverdue ? Colors.red.withOpacity(0.05) : Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: task.isOverdue ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => store.toggleTask(task),
            child: Container(
              width: isIPadMini ? 28 : 32,
              height: isIPadMini ? 28 : 32,
              decoration: BoxDecoration(
                color: task.isDone ? priorityColor(task.priority) : Colors.transparent,
                border: Border.all(color: priorityColor(task.priority), width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: task.isDone ? Icon(Icons.check, color: Colors.white, size: isIPadMini ? 14 : 16) : null,
            ),
          ),
          SizedBox(width: spacing - 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isIPadMini ? 12 : 14,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                    color: task.isDone ? Colors.grey : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isIPadMini ? 2 : 3),
                Row(
                  children: [
                    if (task.dueDate != null) ...[
                      Icon(Icons.calendar_today, size: isIPadMini ? 10 : 11, color: task.isOverdue ? Colors.red : Colors.grey),
                      SizedBox(width: isIPadMini ? 2 : 3),
                      Text(_formatDate(task.dueDate), style: TextStyle(fontSize: isIPadMini ? 10 : 11, color: task.isOverdue ? Colors.red : Colors.grey)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: spacing - 6),
          Container(
            padding: EdgeInsets.symmetric(horizontal: isIPadMini ? 6 : 8, vertical: 2),
            decoration: BoxDecoration(
              color: priorityColor(task.priority).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              task.priority[0].toUpperCase(),
              style: TextStyle(color: priorityColor(task.priority), fontWeight: FontWeight.w600, fontSize: isIPadMini ? 9 : 10),
            ),
          ),
        ],
      ),
    );
  }
}

class UpcomingTaskCard extends StatelessWidget {
  const UpcomingTaskCard({super.key, required this.task, required this.store});

  final TaskItem task;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final isIPadMini = DeviceSize.isIPadMini(context);

    return Container(
      padding: EdgeInsets.all(isIPadMini ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: priorityColor(task.priority), shape: BoxShape.circle),
          ),
          SizedBox(width: isIPadMini ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: isIPadMini ? 12 : 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_formatDate(task.dueDate), style: TextStyle(color: Colors.grey, fontSize: isIPadMini ? 10 : 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _selectedProjectId = '';
  String _priority = 'medium';
  DateTime? _dueDate;

  @override
  Widget build(BuildContext context) {
    final isIPadMini = DeviceSize.isIPadMini(context);
    final spacing = DeviceSize.getSpacing(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              padding: DeviceSize.getPadding(context),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Task title',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isIPadMini ? 10 : 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.check_circle_outline),
                      isDense: isIPadMini,
                    ),
                  ),
                  SizedBox(height: spacing - 2),
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isIPadMini ? 10 : 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.note_outlined),
                      isDense: isIPadMini,
                    ),
                  ),
                  SizedBox(height: spacing - 2),
                  DropdownButtonFormField<String>(
                    value: _selectedProjectId.isEmpty ? null : _selectedProjectId,
                    hint: const Text('Project'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.folder_outlined),
                      isDense: isIPadMini,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isIPadMini ? 8 : 10),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('General')),
                      ...widget.store.projects.map((project) => DropdownMenuItem(value: project.id, child: Text(project.name))),
                    ],
                    onChanged: (value) => setState(() => _selectedProjectId = value ?? ''),
                  ),
                  SizedBox(height: spacing - 2),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.flag_outlined),
                      isDense: isIPadMini,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isIPadMini ? 8 : 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium Priority')),
                      DropdownMenuItem(value: 'high', child: Text('High Priority')),
                    ],
                    onChanged: (value) => setState(() => _priority = value ?? 'medium'),
                  ),
                  SizedBox(height: spacing - 2),
                  SizedBox(
                    width: double.infinity,
                    height: isIPadMini ? 40 : 48,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(_dueDate == null ? 'Set due date' : _formatDate(_dueDate)),
                    ),
                  ),
                  SizedBox(height: spacing + 2),
                  SizedBox(
                    width: double.infinity,
                    height: isIPadMini ? 42 : 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        widget.store.addTask(
                          _titleController.text,
                          notes: _notesController.text,
                          projectId: _selectedProjectId.isEmpty ? null : _selectedProjectId,
                          dueDate: _dueDate,
                          priority: _priority,
                        );
                        _titleController.clear();
                        _notesController.clear();
                        _selectedProjectId = '';
                        _priority = 'medium';
                        _dueDate = null;
                        setState(() {});
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Task'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) {
                  return ListView(
                    padding: EdgeInsets.symmetric(horizontal: spacing - 2, vertical: spacing - 4),
                    children: widget.store.tasks.map((task) => Padding(padding: EdgeInsets.only(bottom: spacing - 4), child: PremiumTaskCard(task: task, store: widget.store))).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final isIPadMini = DeviceSize.isIPadMini(context);
    final spacing = DeviceSize.getSpacing(context);
    final tasksForDate = widget.store.tasks
        .where((task) => task.dueDate != null && DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day).compareTo(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)) == 0)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: DeviceSize.getPadding(context),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1))),
                      Text('${_monthName(_selectedDate.month)} ${_selectedDate.year}', style: TextStyle(fontSize: isIPadMini ? 14 : 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1))),
                    ],
                  ),
                  SizedBox(height: spacing - 4),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 7,
                    childAspectRatio: 1.2,
                    children: _buildCalendarDays(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: EdgeInsets.all(spacing - 2),
                padding: EdgeInsets.all(spacing - 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_formatDate(_selectedDate)} (${tasksForDate.length} tasks)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isIPadMini ? 12 : 14)),
                    SizedBox(height: spacing - 4),
                    if (tasksForDate.isEmpty)
                      const Center(child: Text('No tasks scheduled', style: TextStyle(color: Colors.grey)))
                    else
                      Expanded(
                        child: ListView(children: tasksForDate.map((task) => Padding(padding: EdgeInsets.only(bottom: spacing - 4), child: PremiumTaskCard(task: task, store: widget.store))).toList()),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCalendarDays(BuildContext context) {
    final isIPadMini = DeviceSize.isIPadMini(context);
    final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1).weekday;
    final days = <Widget>[];

    for (var i = 0; i < 7; i++) {
      days.add(Center(child: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][i], style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: isIPadMini ? 10 : 12))));
    }

    for (var i = 1; i < firstDay; i++) {
      days.add(const SizedBox());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedDate.year, _selectedDate.month, day);
      final tasksCount = widget.store.tasks.where((task) => task.dueDate != null && DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day).compareTo(date) == 0).length;
      final isSelected = day == _selectedDate.day;

      days.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tasksCount > 0 ? Colors.blue : Colors.transparent, width: 0.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(day.toString(), style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87, fontSize: isIPadMini ? 11 : 12)),
                if (tasksCount > 0)
                  Container(width: 3, height: 3, margin: const EdgeInsets.only(top: 1), decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.blue, shape: BoxShape.circle)),
              ],
            ),
          ),
        ),
      );
    }

    return days;
  }

  String _monthName(int month) => ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
}

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isIPadMini = DeviceSize.isIPadMini(context);
    final spacing = DeviceSize.getSpacing(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: DeviceSize.getPadding(context),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'New project',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isIPadMini ? 8 : 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.add),
                        isDense: isIPadMini,
                      ),
                    ),
                  ),
                  SizedBox(width: spacing - 4),
                  SizedBox(
                    height: isIPadMini ? 40 : 48,
                    child: FilledButton(
                      onPressed: () {
                        widget.store.addProject(_controller.text);
                        _controller.clear();
                        setState(() {});
                      },
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) {
                  return GridView.count(
                    padding: EdgeInsets.all(spacing - 2),
                    crossAxisCount: 2,
                    mainAxisSpacing: spacing - 4,
                    crossAxisSpacing: spacing - 4,
                    childAspectRatio: isIPadMini ? 1.4 : 1.3,
                    children: widget.store.projects
                        .map((project) => Container(
                              padding: EdgeInsets.all(spacing - 2),
                              decoration: BoxDecoration(
                                color: projectColor(project.color).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: projectColor(project.color).withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: isIPadMini ? 36 : 40,
                                    height: isIPadMini ? 36 : 40,
                                    decoration: BoxDecoration(
                                      color: projectColor(project.color),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(projectIcon(project.icon), color: Colors.white, size: isIPadMini ? 18 : 20),
                                  ),
                                  SizedBox(height: spacing - 6),
                                  Text(project.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isIPadMini ? 13 : 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  if (project.description.isNotEmpty) ...[
                                    SizedBox(height: 2),
                                    Text(project.description, style: TextStyle(color: Colors.grey, fontSize: isIPadMini ? 9 : 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                  const Spacer(),
                                  Text('${widget.store.tasksForProject(project.id).length} tasks', style: TextStyle(color: Colors.grey, fontSize: isIPadMini ? 10 : 11, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _selectedProjectId = '';

  @override
  Widget build(BuildContext context) {
    final isIPadMini = DeviceSize.isIPadMini(context);
    final spacing = DeviceSize.getSpacing(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              padding: DeviceSize.getPadding(context),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Note title',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isIPadMini ? 8 : 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.title),
                      isDense: isIPadMini,
                    ),
                  ),
                  SizedBox(height: spacing - 2),
                  TextField(
                    controller: _contentController,
                    maxLines: isIPadMini ? 3 : 4,
                    decoration: InputDecoration(
                      labelText: 'Notes content',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isIPadMini ? 8 : 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.description_outlined),
                    ),
                  ),
                  SizedBox(height: spacing - 2),
                  DropdownButtonFormField<String>(
                    value: _selectedProjectId.isEmpty ? null : _selectedProjectId,
                    hint: const Text('Project'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.folder_outlined),
                      isDense: isIPadMini,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isIPadMini ? 8 : 10),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('General')),
                      ...widget.store.projects.map((project) => DropdownMenuItem(value: project.id, child: Text(project.name))),
                    ],
                    onChanged: (value) => setState(() => _selectedProjectId = value ?? ''),
                  ),
                  SizedBox(height: spacing),
                  SizedBox(
                    width: double.infinity,
                    height: isIPadMini ? 42 : 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        widget.store.addNote(
                          _titleController.text,
                          content: _contentController.text,
                          projectId: _selectedProjectId.isEmpty ? null : _selectedProjectId,
                        );
                        _titleController.clear();
                        _contentController.clear();
                        _selectedProjectId = '';
                        setState(() {});
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save Note'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) {
                  return ListView(
                    padding: EdgeInsets.symmetric(horizontal: spacing - 2),
                    children: widget.store.notes
                        .map((note) => Container(
                              margin: EdgeInsets.only(bottom: spacing - 4),
                              padding: EdgeInsets.all(spacing - 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(note.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isIPadMini ? 12 : 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        if (note.content.isNotEmpty) ...[
                                          SizedBox(height: 2),
                                          Text(note.content, style: TextStyle(color: Colors.grey, fontSize: isIPadMini ? 10 : 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                        if (note.projectId != null) ...[
                                          SizedBox(height: 3),
                                          Text(widget.store.projectName(note.projectId), style: TextStyle(color: Colors.blue, fontSize: isIPadMini ? 9 : 10)),
                                        ]
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => widget.store.deleteNote(note),
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                    iconSize: isIPadMini ? 18 : 20,
                                    padding: EdgeInsets.all(isIPadMini ? 4 : 6),
                                    constraints: BoxConstraints(minWidth: isIPadMini ? 28 : 32, minHeight: isIPadMini ? 28 : 32),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color priorityColor(String priority) {
  switch (priority.toLowerCase()) {
    case 'high':
      return Colors.red;
    case 'medium':
      return Colors.orange;
    default:
      return Colors.green;
  }
}

Color projectColor(String colorName) {
  switch (colorName) {
    case 'purple':
      return Colors.purple;
    case 'green':
      return Colors.green;
    case 'blue':
      return Colors.blue;
    case 'orange':
      return Colors.orange;
    case 'red':
      return Colors.red;
    default:
      return Colors.deepPurple;
  }
}

IconData projectIcon(String iconName) {
  switch (iconName) {
    case 'person':
      return Icons.person;
    case 'school':
      return Icons.school;
    case 'work':
      return Icons.work;
    default:
      return Icons.folder;
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'No due date';
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}';
}
