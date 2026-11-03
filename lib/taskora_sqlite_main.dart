
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  tz.initializeTimeZones();
tz.setLocalLocation(tz.getLocation('Asia/Karachi'));

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: settings,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}
Future<void> showTestNotification() async {
  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'taskora_channel',
    'Taskora Notifications',
    channelDescription: 'Reminders for your tasks',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

await flutterLocalNotificationsPlugin.show(
  id: 0,
  title: 'Taskora Reminder',
  body: 'Your task reminder is working!',
  notificationDetails: notificationDetails,
);
}
Future<void> scheduleTaskReminder(Task task) async {
  if (task.dueDate == 'No date') return;

  final parts = task.dueDate.split('-');

  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);

  final scheduledDate = tz.TZDateTime(
    tz.local,
    year,
    month,
    day,
    9,
    0,
  );

  if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
    return;
  }

  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    'taskora_channel',
    'Taskora Notifications',
    channelDescription: 'Reminders for your tasks',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id: task.id ?? 0,
    title: 'Taskora Reminder',
    body: 'You have a task due: ${task.title}',
    scheduledDate: scheduledDate,
    notificationDetails: notificationDetails,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeNotifications();

  runApp(const TaskoraApp());
}

const purple = Color(0xFF7566D9);
const backgroundColor = Color(0xFFF7F6FC);

const categories = [
  'University',
  'Assignment',
  'Study',
  'Personal',
  'Project',
];

class Task {
  int? id;
  String title;
  String category;
  String dueDate;
  String description;
  bool isCompleted;

  Task({
    this.id,
    required this.title,
    required this.category,
    required this.dueDate,
    this.description = '',
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'category': category,
    'dueDate': dueDate,
    'description': description,
    'isCompleted': isCompleted ? 1 : 0,
  };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'] as int?,
    title: map['title'] as String,
    category: map['category'] as String,
    dueDate: map['dueDate'] as String,
    description: (map['description'] as String?) ?? '',
    isCompleted: (map['isCompleted'] as int) == 1,
  );
}

class TaskDatabase {
  TaskDatabase._();
  static final TaskDatabase instance = TaskDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = path.join(await getDatabasesPath(), 'taskora.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            dueDate TEXT NOT NULL,
            description TEXT NOT NULL,
            isCompleted INTEGER NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<List<Task>> getTasks() async {
    final db = await database;
    final rows = await db.query('tasks', orderBy: 'id DESC');
    return rows.map((row) => Task.fromMap(row)).toList();
  }

  Future<int> insertTask(Task task) async {
    final db = await database;
    final values = task.toMap()..remove('id');
    return db.insert('tasks', values);
  }

  Future<void> updateTask(Task task) async {
    if (task.id == null) return;
    final db = await database;
    await db.update('tasks', task.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [task.id]);
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }
}

class TaskoraApp extends StatelessWidget {
  const TaskoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taskora',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: purple),
        scaffoldBackgroundColor: backgroundColor,
        fontFamily: 'Roboto',
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;
  List<Task> tasks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      var savedTasks = await TaskDatabase.instance.getTasks();
      if (savedTasks.isEmpty) {
        final examples = [
          Task(title: 'Complete MAD Assignment', category: 'University',
            dueDate: 'Today',
            description: 'Finish the mobile application assignment.'),
          Task(title: 'Prepare Flutter presentation', category: 'Project',
            dueDate: 'Tomorrow',
            description: 'Prepare slides for the presentation.'),
          Task(title: 'Study Database Systems', category: 'Study',
            dueDate: 'Friday', description: 'Revise database concepts.',
            isCompleted: true),
        ];
        for (final task in examples) {
          task.id = await TaskDatabase.instance.insertTask(task);
        }
        savedTasks = await TaskDatabase.instance.getTasks();
      }
      if (!mounted) return;
      setState(() {
        tasks = savedTasks;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load tasks: $error')),
      );
    }
  }

  Future<void> toggleTask(Task task) async {
    task.isCompleted = !task.isCompleted;
    await TaskDatabase.instance.updateTask(task);
    if (mounted) setState(() {});
  }

  Future<void> deleteTask(Task task) async {
    if (task.id != null) await TaskDatabase.instance.deleteTask(task.id!);
    if (!mounted) return;
    setState(() => tasks.removeWhere((item) => item.id == task.id));
  }

  Future<void> openTaskForm({Task? task}) async {
    final result = await Navigator.push<Task>(
      context,
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
    );
    if (!mounted || result == null) return;

    if (task == null) {
  result.id = await TaskDatabase.instance.insertTask(result);

  await scheduleTaskReminder(result);

  if (!mounted) return;
  setState(() => tasks.insert(0, result));
} else {
  result.id = task.id;

  await flutterLocalNotificationsPlugin.cancel(
    id: task.id!,
  );

  await TaskDatabase.instance.updateTask(result);

  await scheduleTaskReminder(result);

  if (!mounted) return;

  setState(() {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index != -1) tasks[index] = result;
  });
}
  }

  Future<void> openTaskDetails(Task task) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailsScreen(task: task)),
    );
    if (!mounted || result == null) return;
    if (result == 'delete') {
      await deleteTask(task);
    } else if (result == 'edit') {
      await openTaskForm(task: task);
    } else if (result == 'toggle') {
      await toggleTask(task);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taskora', style: TextStyle(
          fontSize: 25, fontWeight: FontWeight.bold, color: purple)),
        actions: [
          IconButton(
  onPressed: () async {
    await showTestNotification();
  },
            icon: const Icon(Icons.notifications_outlined)),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: purple))
          : IndexedStack(
              index: selectedIndex,
              children: [
                HomePage(tasks: tasks, onToggle: toggleTask,
                  onDelete: deleteTask,
                  onEdit: (task) => openTaskForm(task: task),
                  onDetails: openTaskDetails),
                AllTasksPage(tasks: tasks, onToggle: toggleTask,
                  onDelete: deleteTask,
                  onEdit: (task) => openTaskForm(task: task),
                  onDetails: openTaskDetails),
                SearchPage(tasks: tasks, onToggle: toggleTask,
                  onDelete: deleteTask,
                  onEdit: (task) => openTaskForm(task: task),
                  onDetails: openTaskDetails),
                const ProfilePage(),
              ],
            ),
      floatingActionButton: selectedIndex != 3
          ? FloatingActionButton(
              onPressed: () => openTaskForm(),
              backgroundColor: purple,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist), label: 'All Tasks'),
          NavigationDestination(icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// HOME PAGE

class HomePage extends StatelessWidget {
  final List<Task> tasks;
  final Function(Task) onToggle;
  final Function(Task) onDelete;
  final Function(Task) onEdit;
  final Function(Task) onDetails;

  const HomePage({
    super.key,
    required this.tasks,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.isCompleted).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hello, Student! 👋',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Let’s make today productive.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 25),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: purple,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Progress',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Text(
                  '$completed / ${tasks.length} Tasks Completed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                LinearProgressIndicator(
                  value: tasks.isEmpty ? 0 : completed / tasks.length,
                  backgroundColor: Colors.white30,
                  color: Colors.white,
                  minHeight: 9,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Tasks',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '${tasks.length} Total',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (tasks.isEmpty)
            const Text('No tasks yet. Add your first task!'),
          ...tasks.map(
            (task) => TaskCard(
              task: task,
              onToggle: () => onToggle(task),
              onDelete: () => onDelete(task),
              onEdit: () => onEdit(task),
              onTap: () => onDetails(task),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ALL TASKS PAGE

class AllTasksPage extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task) onToggle;
  final Function(Task) onDelete;
  final Function(Task) onEdit;
  final Function(Task) onDetails;

  const AllTasksPage({
    super.key,
    required this.tasks,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onDetails,
  });

  @override
  State<AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<AllTasksPage> {
  String selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final filteredTasks = widget.tasks.where((task) {
      if (selectedFilter == 'Pending') return !task.isCompleted;
      if (selectedFilter == 'Completed') return task.isCompleted;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 5),
          child: Text(
            'All Tasks',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Manage all your university tasks.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['All', 'Pending', 'Completed'].map((filter) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Center(child: Text(filter)),
                    selected: selectedFilter == filter,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() {
                        selectedFilter = filter;
                      });
                    },
                    selectedColor: const Color(0xFFDCD6FA),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filteredTasks.isEmpty
              ? Center(child: Text('No $selectedFilter tasks found.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 5, 16, 85),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];

                    return TaskCard(
                      task: task,
                      onToggle: () => widget.onToggle(task),
                      onDelete: () => widget.onDelete(task),
                      onEdit: () => widget.onEdit(task),
                      onTap: () => widget.onDetails(task),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// SEARCH AND FILTER PAGE

class SearchPage extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task) onToggle;
  final Function(Task) onDelete;
  final Function(Task) onEdit;
  final Function(Task) onDetails;

  const SearchPage({
    super.key,
    required this.tasks,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onDetails,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController searchController = TextEditingController();

  String selectedCategory = 'All';
  String selectedStatus = 'All';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void clearFilters() {
    setState(() {
      searchController.clear();
      selectedCategory = 'All';
      selectedStatus = 'All';
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchText = searchController.text.toLowerCase().trim();

    final filteredTasks = widget.tasks.where((task) {
      final matchesTitle = task.title.toLowerCase().contains(searchText);

      final matchesCategory =
          selectedCategory == 'All' || task.category == selectedCategory;

      final matchesStatus = selectedStatus == 'All' ||
          (selectedStatus == 'Pending' && !task.isCompleted) ||
          (selectedStatus == 'Completed' && task.isCompleted);

      return matchesTitle && matchesCategory && matchesStatus;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 15),
          child: Text(
            'Search Tasks',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by task title...',
              prefixIcon: const Icon(Icons.search, color: purple),
              suffixIcon: IconButton(
                onPressed: () {
                  searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Filter by Category',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: ['All', ...categories].map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedCategory = value;
                });
              }
            },
          ),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Filter by Status',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: ['All', 'Pending', 'Completed'].map((status) {
              return ChoiceChip(
                label: Text(status),
                selected: selectedStatus == status,
                showCheckmark: false,
                selectedColor: const Color(0xFFDCD6FA),
                onSelected: (_) {
                  setState(() {
                    selectedStatus = status;
                  });
                },
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredTasks.length} matching tasks',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: clearFilters,
                child: const Text(
                  'Clear filters',
                  style: TextStyle(color: purple),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredTasks.isEmpty
              ? const Center(
                  child: Text(
                    'No matching tasks found.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 85),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];

                    return TaskCard(
                      task: task,
                      onToggle: () => widget.onToggle(task),
                      onDelete: () => widget.onDelete(task),
                      onEdit: () => widget.onEdit(task),
                      onTap: () => widget.onDetails(task),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// REUSABLE TASK CARD

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onTap;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        leading: Checkbox(
          value: task.isCompleted,
          activeColor: purple,
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: task.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            color: task.isCompleted ? Colors.grey : Colors.black87,
          ),
        ),
        subtitle: Text('${task.category} • ${task.dueDate}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TASK DETAILS SCREEN

class TaskDetailsScreen extends StatelessWidget {
  final Task task;

  const TaskDetailsScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        backgroundColor: backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: purple,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.assignment_outlined,
                    color: Colors.white,
                    size: 38,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    task.isCompleted ? 'Completed' : 'Pending',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Task Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _detailRow(Icons.category_outlined, 'Category', task.category),
            _detailRow(Icons.calendar_month_outlined, 'Due Date', task.dueDate),
            _detailRow(
              Icons.flag_outlined,
              'Status',
              task.isCompleted ? 'Completed' : 'Pending',
            ),
            const SizedBox(height: 25),
            const Text(
              'Description',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                task.description.isEmpty
                    ? 'No description added.'
                    : task.description,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, 'toggle');
                },
                icon: Icon(
                  task.isCompleted
                      ? Icons.refresh
                      : Icons.check_circle_outline,
                ),
                label: Text(
                  task.isCompleted
                      ? 'Mark as Pending'
                      : 'Mark as Completed',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context, 'edit');
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Task'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context, 'delete');
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text(
                  'Delete Task',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: purple, size: 23),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ADD / EDIT TASK SCREEN

class TaskFormScreen extends StatefulWidget {
  final Task? task;

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController titleController;
  late TextEditingController descriptionController;

  late String selectedCategory;
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.task?.title ?? '',
    );

    descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );

    selectedCategory = categories.contains(widget.task?.category)
        ? widget.task!.category
        : 'University';

    if (widget.task != null) {
      selectedDate = DateTime.tryParse(widget.task!.dueDate);
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
      });
    }
  }

  void saveTask() {
    if (!_formKey.currentState!.validate()) return;

    final result = Task(
      id: widget.task?.id,
      title: titleController.text.trim(),
      category: selectedCategory,
      dueDate: selectedDate == null
          ? 'No date'
          : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
      description: descriptionController.text.trim(),
      isCompleted: widget.task?.isCompleted ?? false,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'Add New Task'),
        backgroundColor: backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing
                    ? 'Update your task details.'
                    : 'Create a task and stay organized.',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 25),
              const Text(
                'Task Title',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: 'Enter task title',
                  prefixIcon: const Icon(Icons.edit_note),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.category_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedCategory = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Due Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: chooseDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: purple),
                      const SizedBox(width: 12),
                      Text(
                        selectedDate == null
                            ? 'Choose a due date'
                            : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                      ),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add task details...',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: saveTask,
                  icon: Icon(isEditing ? Icons.save_outlined : Icons.add),
                  label: Text(isEditing ? 'Update Task' : 'Save Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// PROFILE PAGE

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: Color(0xFFE7E3FA),
            child: Icon(Icons.person, size: 50, color: purple),
          ),
          SizedBox(height: 15),
          Text(
            'Student Profile',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Welcome to Taskora!',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
