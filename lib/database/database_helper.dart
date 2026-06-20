import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/level_model.dart';

/// O'yinning butun offline ma'lumotlar bazasini boshqaruvchi singleton klass.
///
/// Birinchi marta ishga tushganda assets/data/words_*.json fayllaridan
/// darajalarni o'qib, SQLite jadvaliga "seed" qiladi. Keyingi safar
/// ilova ochilganda esa to'g'ridan-to'g'ri bazadan o'qiydi - internet kerak emas.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'soz_topish.db';
  static const int _dbVersion = 1;

  static const String tableLevels = 'levels';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableLevels (
        id INTEGER PRIMARY KEY,
        level_number INTEGER NOT NULL,
        alphabet TEXT NOT NULL,
        circle_letters TEXT NOT NULL,
        valid_words TEXT NOT NULL,
        main_word TEXT NOT NULL,
        star_threshold INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Birinchi o'rnatishda JSON assetlardan darajalarni yuklab, bazaga yozamiz.
    await _seedFromAssets(db);
  }

  Future<void> _seedFromAssets(Database db) async {
    await _seedAlphabet(db, 'assets/data/words_lotin.json', 'lotin');
    await _seedAlphabet(db, 'assets/data/words_kiril.json', 'kiril');
  }

  Future<void> _seedAlphabet(
    Database db,
    String assetPath,
    String alphabetKey,
  ) async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;

      final batch = db.batch();
      for (final item in jsonList) {
        final level = LevelModel.fromJson(
          item as Map<String, dynamic>,
          alphabetKey,
        );
        batch.insert(
          tableLevels,
          level.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      // Agar asset topilmasa, ilova qulamasligi uchun jim o'tamiz.
      // Productionda bu yerga logging qo'shing.
    }
  }

  /// Berilgan alifbo bo'yicha barcha darajalarni level_number tartibida qaytaradi.
  Future<List<LevelModel>> getLevelsByAlphabet(String alphabetKey) async {
    final db = await database;
    final rows = await db.query(
      tableLevels,
      where: 'alphabet = ?',
      whereArgs: [alphabetKey],
      orderBy: 'level_number ASC',
    );
    return rows.map((r) => LevelModel.fromMap(r)).toList();
  }

  Future<LevelModel?> getLevelById(int id) async {
    final db = await database;
    final rows = await db.query(
      tableLevels,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LevelModel.fromMap(rows.first);
  }

  Future<int> countLevels(String alphabetKey) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableLevels WHERE alphabet = ?',
      [alphabetKey],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
