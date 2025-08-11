import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/person.dart';

class DatabaseHelper {
  static Database? _db;

  static Future<Database> initDB() async {
    sqfliteFfiInit();
    var factory = databaseFactoryFfi;
    Directory dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/attendance.db';

    return _db ??= await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          // First time DB creation
          await _createTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Handle migrations between versions
          if (oldVersion < 2) {
            await _migrateToV2(db);
          }
        },
        onOpen: (db) async {
          // Ensure tables exist for old DBs
          await _createTables(db);
          // Also ensure columns exist if DB was created by an older app version
          await _migrateToV2(db);
        },
      ),
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS persons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        empCode INTEGER,
        role TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS holidays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER,
        month INTEGER,
        day INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS leaves (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        personId INTEGER,
        year INTEGER,
        month INTEGER,
        day INTEGER,
        type TEXT
      )
    ''');
  }

  // Migration helpers
  static Future<void> _migrateToV2(Database db) async {
    // Ensure persons table has empCode and role columns
    final res = await db.rawQuery("PRAGMA table_info(persons)");
    final columnNames = res.map((row) => (row['name'] as Object?).toString()).toSet();
    if (!columnNames.contains('empCode')) {
      await db.execute('ALTER TABLE persons ADD COLUMN empCode INTEGER');
    }
    if (!columnNames.contains('role')) {
      await db.execute('ALTER TABLE persons ADD COLUMN role TEXT');
    }
  }

  // Insert person with numeric empCode auto-generation per role
  static Future<int> insertPerson(Person p) async {
    final db = await initDB();
    if (p.empCode == 0) {
      final res = await db.rawQuery(
        'SELECT MAX(empCode) as maxc FROM persons WHERE role = ?',
        [p.role],
      );
      final maxc = res.first['maxc'] as int? ?? 0;
      p.empCode = maxc + 1;
    }
    final id = await db.insert('persons', p.toMap());
    print("✅ Saved ${p.role}: ${p.name} (Code: ${p.empCode})");
    return id;
  }

  static Future<List<Person>> getAllPersons() async {
    final db = await initDB();
    final res = await db.query('persons', orderBy: 'role DESC, empCode ASC');
    return res.map((e) => Person.fromMap(e)).toList();
  }

  static Future<int> deletePerson(int id) async {
    final db = await initDB();
    return db.delete('persons', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> updatePerson(Person p) async {
    final db = await initDB();
    if (p.id == null) {
      throw ArgumentError('Person.id is required for update');
    }
    return db.update('persons', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  // Holidays CRUD
  static Future<void> addHoliday(int year, int month, int day) async {
    final db = await initDB();
    await db.insert('holidays', {
      'year': year,
      'month': month,
      'day': day,
    });
  }

  static Future<void> removeHoliday(int year, int month, int day) async {
    final db = await initDB();
    await db.delete(
      'holidays',
      where: 'year=? AND month=? AND day=?',
      whereArgs: [year, month, day],
    );
  }

  static Future<List<DateTime>> getHolidaysForMonth(
      int year, int month) async {
    final db = await initDB();
    final res = await db.query(
      'holidays',
      where: 'year=? AND month=?',
      whereArgs: [year, month],
    );
    return res
        .map((r) => DateTime(
              r['year'] as int,
              r['month'] as int,
              r['day'] as int,
            ))
        .toList();
  }

  // Leaves CRUD
  static Future<void> addLeave(
      int personId, int year, int month, int day, String type) async {
    final db = await initDB();
    await db.insert('leaves', {
      'personId': personId,
      'year': year,
      'month': month,
      'day': day,
      'type': type,
    });
  }

  static Future<void> removeLeave(
      int personId, int year, int month, int day) async {
    final db = await initDB();
    await db.delete(
      'leaves',
      where: 'personId=? AND year=? AND month=? AND day=?',
      whereArgs: [personId, year, month, day],
    );
  }

  static Future<Map<int, Map<int, String>>> getLeavesForMonth(
      int year, int month) async {
    final db = await initDB();
    final res = await db.query(
      'leaves',
      where: 'year=? AND month=?',
      whereArgs: [year, month],
    );
    final map = <int, Map<int, String>>{};
    for (var r in res) {
      final pid = r['personId'] as int;
      final day = r['day'] as int;
      final type = r['type'] as String;
      map.putIfAbsent(pid, () => {})[day] = type;
    }
    return map;
  }
}
