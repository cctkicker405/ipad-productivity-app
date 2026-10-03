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

    final isTablet = MediaQuery.of(context).size.width >= 800;

    if (isTablet) {
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
                  extended: MediaQuery.of(context).size.width > 900,
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
    final isTablet = MediaQuery.of(context).size.width >= 800;
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
          padding: EdgeInsets.all(isTablet ? 28 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Good morning', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 6),
                      const Text('Your focus dashboard', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (isTablet)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text('${store.completionRate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                          const Text('Complete', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: isTablet ? 4 : 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isTablet ? 1.3 : 1.5,
                children: [
                  StatCard(title: 'Tasks', value: '${store.tasks.length}', color: Colors.blue, icon: Icons.task_alt),
                  StatCard(title: 'Done', value: '${store.completedTasks}', color: Colors.green, icon: Icons.check_circle),
                  StatCard(title: 'Open', value: '${store.openTasks}', color: Colors.orange, icon: Icons.hourglass_empty),
                  if (isTablet) StatCard(title: 'Projects', value: '${store.projects.length}', color: Colors.purple, icon: Icons.folder),
                ],
              ),
              const SizedBox(height: 32),
              if (overdueTasks.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('Overdue Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                    const Spacer(),
                    Text('${overdueTasks.length} items', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                ...overdueTasks.take(3).map((task) => PremiumTaskCard(task: task, store: store)),
                const SizedBox(height: 24),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Today\u2019s focus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('${store.todayTasks().length} items', style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),
              if (store.todayTasks().isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: const Center(
                    child: Text('No tasks today. Great work!', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ),
                )
              else
                ...store.todayTasks().map((task) => PremiumTaskCard(task: task, store: store)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Upcoming', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('${upcomingTasks.length} items', style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 12),
              if (upcomingTasks.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: const Center(child: Text('No upcoming tasks', style: TextStyle(color: Colors.grey))),
                )
              else
                ...upcomingTasks.map((task) => UpcomingTaskCard(task: task, store: store)),
              const SizedBox(height: 28),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: task.isOverdue ? Colors.red.withOpacity(0.05) : Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.isOverdue ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => store.toggleTask(task),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: task.isDone ? priorityColor(task.priority) : Colors.transparent,
                border: Border.all(color: priorityColor(task.priority), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: task.isDone ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                    color: task.isDone ? Colors.grey : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (task.dueDate != null) ...[
                      Icon(Icons.calendar_today, size: 12, color: task.isOverdue ? Colors.red : Colors.grey),
                      const SizedBox(width: 4),
                      Text(_formatDate(task.dueDate), style: TextStyle(fontSize: 12, color: task.isOverdue ? Colors.red : Colors.grey)),
                      const SizedBox(width: 12),
                    ],
                    Text(store.projectName(task.projectId), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                if (task.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: task.tags
                        .take(2)
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(tag, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                            ))
                        .toList(),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: priorityColor(task.priority).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              task.priority[0].toUpperCase() + task.priority.substring(1),
              style: TextStyle(color: priorityColor(task.priority), fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => store.deleteTask(task),
                child: const Row(
                  children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete')],
                ),
              ),
            ],
            child: const Icon(Icons.more_vert, size: 20),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: priorityColor(task.priority), shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(_formatDate(task.dueDate), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(store.projectName(task.projectId), style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
    final isTablet = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Task title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.check_circle_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.note_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedProjectId.isEmpty ? null : _selectedProjectId,
                    hint: const Text('Project'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.folder_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('General')),
                      ...widget.store.projects.map((project) => DropdownMenuItem(value: project.id, child: Text(project.name))),
                    ],
                    onChanged: (value) => setState(() => _selectedProjectId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.flag_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium Priority')),
                      DropdownMenuItem(value: 'high', child: Text('High Priority')),
                    ],
                    onChanged: (value) => setState(() => _priority = value ?? 'medium'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: _dueDate == null ? 'No due date' : _formatDate(_dueDate),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) setState(() => _dueDate = picked);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: widget.store.tasks.map((task) => PremiumTaskCard(task: task, store: widget.store)).toList(),
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
    final tasksForDate = widget.store.tasks
        .where((task) => task.dueDate != null && DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day).compareTo(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)) == 0)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1))),
                      Text('${_monthName(_selectedDate.month)} ${_selectedDate.year}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 7,
                    children: _buildCalendarDays(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_formatDate(_selectedDate)} (${tasksForDate.length} tasks)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    if (tasksForDate.isEmpty)
                      const Center(child: Text('No tasks scheduled', style: TextStyle(color: Colors.grey)))
                    else
                      Expanded(
                        child: ListView(children: tasksForDate.map((task) => PremiumTaskCard(task: task, store: widget.store)).toList()),
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

  List<Widget> _buildCalendarDays() {
    final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1).weekday;
    final days = <Widget>[];

    for (var i = 0; i < 7; i++) {
      days.add(Center(child: Text(['M', 'T', 'W', 'T', 'F', 'S', 'S'][i], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))));
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
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tasksCount > 0 ? Colors.blue : Colors.transparent),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(day.toString(), style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87)),
                if (tasksCount > 0)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.blue, shape: BoxShape.circle),
                  ),
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
    final isTablet = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'New project',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.add),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      widget.store.addProject(_controller.text);
                      _controller.clear();
                      setState(() {});
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.store,
                builder: (context, _) {
                  return GridView.count(
                    padding: const EdgeInsets.all(16),
                    crossAxisCount: isTablet ? 3 : 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: widget.store.projects
                        .map((project) => Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: projectColor(project.color).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: projectColor(project.color).withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: projectColor(project.color),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(projectIcon(project.icon), color: Colors.white),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  if (project.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(project.description, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                  const Spacer(),
                                  Text('${widget.store.tasksForProject(project.id).length} tasks', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Note title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.title),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contentController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Notes content',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedProjectId.isEmpty ? null : _selectedProjectId,
                    hint: const Text('Project'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.folder_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('General')),
                      ...widget.store.projects.map((project) => DropdownMenuItem(value: project.id, child: Text(project.name))),
                    ],
                    onChanged: (value) => setState(() => _selectedProjectId = value ?? ''),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: widget.store.notes
                        .map((note) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        if (note.content.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(note.content, style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        ],
                                        if (note.projectId != null) ...[
                                          const SizedBox(height: 6),
                                          Text(widget.store.projectName(note.projectId), style: const TextStyle(color: Colors.blue, fontSize: 11)),
                                        ]
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => widget.store.deleteNote(note),
                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
