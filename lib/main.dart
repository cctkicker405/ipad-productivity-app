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
      title: 'MiniPad Productivity',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const ProductivityHome(),
    );
  }
}

class Project {
  Project({
    required this.name,
    this.icon = 'folder',
    this.color = 'purple',
  }) : id = const Uuid().v4();

  final String id;
  final String name;
  final String icon;
  final String color;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        name: json['name'] as String,
        icon: json['icon'] as String? ?? 'folder',
        color: json['color'] as String? ?? 'purple',
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
  }) : id = const Uuid().v4();

  final String id;
  final String title;
  final String notes;
  final String? projectId;
  final DateTime? dueDate;
  final String priority;
  final bool isDone;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'projectId': projectId,
        'dueDate': dueDate?.toIso8601String(),
        'priority': priority,
        'isDone': isDone,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        title: json['title'] as String,
        notes: json['notes'] as String? ?? '',
        projectId: json['projectId'] as String?,
        dueDate: json['dueDate'] == null
            ? null
            : DateTime.parse(json['dueDate'] as String),
        priority: json['priority'] as String? ?? 'medium',
        isDone: json['isDone'] as bool? ?? false,
      )..id = json['id'] as String;

  TaskItem copyWith({
    String? id,
    String? title,
    String? notes,
    String? projectId,
    DateTime? dueDate,
    String? priority,
    bool? isDone,
  }) {
    return TaskItem(
      title: title ?? this.title,
      notes: notes ?? this.notes,
      projectId: projectId ?? this.projectId,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isDone: isDone ?? this.isDone,
    );
  }

  TaskItem get withId => this; // placeholder to keep functional API simple
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
      )..id = json['id'] as String;

  NoteItem get withId => this; // placeholder to keep functional API simple
}

class AppStore extends ChangeNotifier {
  AppStore() {
    _load();
  }

  final List<Project> projects = [
    Project(name: 'Work', icon: 'work', color: 'purple'),
    Project(name: 'Personal', icon: 'person', color: 'green'),
    Project(name: 'Study', icon: 'school', color: 'blue'),
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
        title: 'Review weekly roadmap',
        notes: 'Finalize design handoff for sprint review.',
        projectId: projects.first.id,
        dueDate: DateTime.now().add(const Duration(days: 2)),
        priority: 'high',
      ),
      TaskItem(
        title: 'Plan personal errands',
        notes: 'Groceries and appointment calls.',
        projectId: projects[1].id,
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: 'medium',
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

  void addProject(String name) {
    if (name.trim().isEmpty) return;
    projects.add(Project(name: name.trim()));
    notifyListeners();
    _save();
  }

  void addTask(String title, {String notes = '', String? projectId, DateTime? dueDate, String priority = 'medium'}) {
    if (title.trim().isEmpty) return;
    tasks.add(TaskItem(
      title: title.trim(),
      notes: notes.trim(),
      projectId: projectId,
      dueDate: dueDate,
      priority: priority,
    ));
    notifyListeners();
    _save();
  }

  void toggleTask(TaskItem task) {
    final index = tasks.indexWhere((element) => element.id == task.id);
    if (index == -1) return;
    tasks[index] = TaskItem(
      title: task.title,
      notes: task.notes,
      projectId: task.projectId,
      dueDate: task.dueDate,
      priority: task.priority,
      isDone: !task.isDone,
    );
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
    notes.add(NoteItem(
      title: title.trim().isEmpty ? 'Untitled Note' : title.trim(),
      content: content.trim(),
      projectId: projectId,
    ));
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

  int get completedTasks => tasks.where((task) => task.isDone).length;
  int get openTasks => tasks.where((task) => !task.isDone).length;
  int get pendingNotes => notes.length;
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
      ProjectsScreen(store: _store),
      NotesScreen(store: _store),
    ];

    final isTablet = MediaQuery.of(context).size.width >= 700;

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
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: Text('Tasks')),
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
    final upcomingTasks = store.tasks.where((task) => !task.isDone && task.dueDate != null).toList()
      ..sort((a, b) => (a.dueDate ?? DateTime.now()).compareTo(b.dueDate ?? DateTime.now()));

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Good morning', style: TextStyle(fontSize: 20, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('Your focus dashboard', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  StatCard(title: 'Tasks', value: '${store.tasks.length}', color: Colors.blue),
                  StatCard(title: 'Done', value: '${store.completedTasks}', color: Colors.green),
                  StatCard(title: 'Open', value: '${store.openTasks}', color: Colors.orange),
                ],
              ),
              const SizedBox(height: 28),
              const Text('Today’s focus', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (store.tasks.where((task) => !task.isDone).isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text('No tasks pending. Great work!'),
                )
              else
                ...store.tasks.where((task) => !task.isDone).take(3).map((task) => TaskRow(task: task, store: store)),
              const SizedBox(height: 28),
              const Text('Upcoming', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (upcomingTasks.isEmpty)
                const Text('No upcoming items.')
              else
                ...upcomingTasks.take(3).map((task) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: priorityColor(task.priority), shape: BoxShape.circle)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(_formatDate(task.dueDate), style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text(store.projectName(task.projectId), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.color});

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: color)),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Task title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedProjectId.isEmpty ? null : _selectedProjectId,
                    hint: const Text('Project'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('General')),
                      ...widget.store.projects.map((project) => DropdownMenuItem(value: project.id, child: Text(project.name))),
                    ],
                    onChanged: (value) => setState(() => _selectedProjectId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _priority,
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                    ],
                    onChanged: (value) => setState(() => _priority = value ?? 'medium'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dueDate == null ? 'No due date' : _formatDate(_dueDate),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) setState(() => _dueDate = picked);
                        },
                        child: const Text('Pick date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
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
                      label: const Text('Add task'),
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
                    children: widget.store.tasks.map((task) => TaskRow(task: task, store: widget.store)).toList(),
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
                      decoration: const InputDecoration(labelText: 'New project'),
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
                  return ListView.builder(
                    itemCount: widget.store.projects.length,
                    itemBuilder: (context, index) {
                      final project = widget.store.projects[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: projectColor(project.color),
                          child: Icon(projectIcon(project.icon), color: Colors.white),
                        ),
                        title: Text(project.name),
                        subtitle: Text('${widget.store.tasks.where((task) => task.projectId == project.id).length} tasks'),
                      );
                    },
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Note title'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notes content'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedProjectId.isEmpty ? null : _selectedProjectId,
                    hint: const Text('Project'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('General')),
                      ...widget.store.projects.map((project) => DropdownMenuItem(value: project.id, child: Text(project.name))),
                    ],
                    onChanged: (value) => setState(() => _selectedProjectId = value ?? ''),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
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
                      label: const Text('Save note'),
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
                    children: widget.store.notes.map((note) => ListTile(
                          title: Text(note.title),
                          subtitle: Text(note.content.isEmpty ? 'No content' : note.content),
                          trailing: IconButton(
                            onPressed: () => widget.store.deleteNote(note),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                        )).toList(),
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

class TaskRow extends StatelessWidget {
  const TaskRow({super.key, required this.task, required this.store});

  final TaskItem task;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => store.toggleTask(task),
            icon: Icon(
              task.isDone ? Icons.check_box : Icons.check_box_outline_blank,
              color: task.isDone ? Colors.green : Colors.grey,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.notes.isNotEmpty)
                  Text(task.notes, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (task.dueDate != null)
                      Text(_formatDate(task.dueDate), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    if (task.dueDate != null) const SizedBox(width: 12),
                    Text(store.projectName(task.projectId), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: priorityColor(task.priority).withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              task.priority[0].toUpperCase() + task.priority.substring(1),
              style: TextStyle(color: priorityColor(task.priority), fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () => store.deleteTask(task),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
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
  final formatter = DateFormat('MMM d, yyyy');
  return formatter.format(date);
}

class DateFormat {
  const DateFormat(this.pattern);

  final String pattern;

  String format(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$month/$day/$year';
  }
}
