import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

var path = null;

class Basedatohelper {
  Future<Database> _openDataBase() async {
    final databasepath = await getDatabasesPath();
    final path = join(databasepath, 'mydatabase.db');
    return openDatabase(path, onCreate: (db, version) async {
      await db.execute(
          'CREATE TABLE mytabla (id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT)');
    }, version: 1);
  }

  Future<void> addData() async {
    final database = await _openDataBase();
    await database.insert(
      'mitabla',
      {'name': 'juan'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('agregado');
    await database.close();
  }

  Future<void> mostrar() async {
    final database = await _openDataBase();
    final data = await database.query('mytabla');
    print(data);
    await database.close();
  }
}
