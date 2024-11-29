import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: UserScreen(),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, age INTEGER, email TEXT UNIQUE)');
        await db.execute(
            'CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER, title TEXT, completed INTEGER, FOREIGN KEY(userId) REFERENCES users(id))');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE users ADD COLUMN email TEXT UNIQUE');
          await db.execute(
              'CREATE TABLE tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, userId INTEGER, title TEXT, completed INTEGER, FOREIGN KEY(userId) REFERENCES users(id))');
        }
      },
    );
  }

  Future<void> insertUser(String name, int age, String email) async {
    final db = await database;
    await db.insert(
      'users',
      {'name': name, 'age': age, 'email': email},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    final db = await database;
    return db.query('users');
  }

  Future<List<Map<String, dynamic>>> searchUsersByName(String name) async {
    final db = await database;
    return db.query(
      'users',
      where: 'name LIKE ?',
      whereArgs: ['%$name%'],
    );
  }

  Future<List<Map<String, dynamic>>> filterUsersByAgeRange(
      int minAge, int maxAge) async {
    final db = await database;
    return db.query(
      'users',
      where: 'age BETWEEN ? AND ?',
      whereArgs: [minAge, maxAge],
    );
  }

  Future<void> updateUser(int id, String name, int age, String email) async {
    final db = await database;
    await db.update(
      'users',
      {'name': name, 'age': age, 'email': email},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteUser(int id) async {
    final db = await database;
    await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertTask(int userId, String title, bool completed) async {
    final db = await database;
    await db.insert(
      'tasks',
      {'userId': userId, 'title': title, 'completed': completed ? 1 : 0},
    );
  }

  Future<List<Map<String, dynamic>>> fetchTasksForUser(int userId) async {
    final db = await database;
    return db.query(
      'tasks',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updateTask(int id, String title, bool completed) async {
    final db = await database;
    await db.update(
      'tasks',
      {'title': title, 'completed': completed ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class UserScreen extends StatefulWidget {
  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _tasks = [];
  int? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() async {
    final users = await dbHelper.fetchUsers();
    setState(() {
      _users = users;
    });
  }

  void _loadTasksForUser(int userId) async {
    final tasks = await dbHelper.fetchTasksForUser(userId);
    setState(() {
      _tasks = tasks;
      _selectedUserId = userId;
    });
  }

  void _addUser() async {
    final name = _nameController.text;
    final age = int.tryParse(_ageController.text) ?? 0;
    final email = _emailController.text;

    if (name.isNotEmpty && age > 0 && email.isNotEmpty) {
      await dbHelper.insertUser(name, age, email);
      _nameController.clear();
      _ageController.clear();
      _emailController.clear();
      _loadUsers();
    }
  }

  void _addTask() async {
    final userId = _selectedUserId;
    final title = _nameController.text;

    if (userId != null && title.isNotEmpty) {
      await dbHelper.insertTask(userId, title, false);
      _nameController.clear();
      _loadTasksForUser(userId);
    }
  }

  void _updateUser(int id) async {
    final name = _nameController.text;
    final age = int.tryParse(_ageController.text) ?? 0;
    final email = _emailController.text;

    if (name.isNotEmpty && age > 0 && email.isNotEmpty) {
      await dbHelper.updateUser(id, name, age, email);
      _nameController.clear();
      _ageController.clear();
      _emailController.clear();
      _loadUsers();
    }
  }

  void _updateTask(int id) async {
    final title = _nameController.text;

    if (title.isNotEmpty) {
      await dbHelper.updateTask(id, title, true);
      _nameController.clear();
      if (_selectedUserId != null) _loadTasksForUser(_selectedUserId!);
    }
  }

  void _deleteUser(int id) async {
    await dbHelper.deleteUser(id);
    _loadUsers();
    if (_selectedUserId == id) {
      setState(() {
        _tasks.clear();
        _selectedUserId = null;
      });
    }
  }

  void _deleteTask(int id) async {
    await dbHelper.deleteTask(id);
    if (_selectedUserId != null) _loadTasksForUser(_selectedUserId!);
  }

  void _searchUsers() async {
    final searchText = _searchController.text;
    final users = await dbHelper.searchUsersByName(searchText);
    setState(() {
      _users = users;
    });
  }

  void _filterUsersByAge() async {
    final users = await dbHelper.filterUsersByAgeRange(20, 30);
    setState(() {
      _users = users;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Aplicacion Completa con Dart y Flutter Juan Jose Aldana Rodriguez'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _ageController,
                    decoration: const InputDecoration(labelText: 'Edad'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration:
                        const InputDecoration(labelText: 'Correo Electrónico'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addUser,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(labelText: 'Buscar usuario'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  title: Text(user['name']),
                  subtitle: Text('Edad: ${user['age']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _nameController.text = user['name'];
                          _ageController.text = user['age'].toString();
                          _emailController.text = user['email'];
                          _updateUser(user['id']);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _deleteUser(user['id']);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.task),
                        onPressed: () {
                          _loadTasksForUser(user['id']);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_selectedUserId != null) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nueva tarea'),
              ),
            ),
            ElevatedButton(
              onPressed: _addTask,
              child: const Text('Agregar tarea'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return ListTile(
                    title: Text(task['title']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _deleteTask(task['id']);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _filterUsersByAge,
        child: const Icon(Icons.filter_list),
        tooltip: 'Filtrar usuarios por edad',
      ),
    );
  }
}
