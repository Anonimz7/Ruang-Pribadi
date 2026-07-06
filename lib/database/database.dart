import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class DatabaseHelper {
  static Database? _database;

  /// =========================== INISIALISASI ===========================
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, "data.db");

      if (!await File(path).exists()) {
        try {
          await Directory(dirname(path)).create(recursive: true);
        } catch (e) {
          throw Exception("Gagal membuat direktori: ${e.toString()}");
        }
        ByteData data = await rootBundle.load("assets/database/data.db");
        List<int> bytes = data.buffer.asUint8List();
        await File(path).writeAsBytes(bytes, flush: true);
      }
      return await openDatabase(path);
    } catch (e) {
      throw Exception("Gagal menginisialisasi database: ${e.toString()}");
    }
  }

  /// ====================== FUNGSI PENGAMBILAN DATA ======================
  /// Method untuk mengambil data dari tabel hirakana berdasarkan jenis dan kategori.
  Future<List<Map<String, dynamic>>> getData(
      String jenis, String kategori, bool acak) async {
    final db = await database;
    try {
      String query = "SELECT * FROM hirakana WHERE jenis = ? AND kategori = ?";
      List<dynamic> args = [jenis, kategori];
      if (acak) {
        query += " ORDER BY RANDOM()";
      }
      return await db.rawQuery(query, args);
    } catch (e) {
      throw Exception("Gagal mengambil data: ${e.toString()}");
    }
  }

  /// Method untuk mengambil data dari tabel advanced (kanji, vocal, grammar, dll.)
  /// Parameter:
  /// - [type]: nama tabel
  /// - [acak]: apakah hasil diacak
  /// - [jlptLevel]: filter berdasarkan JLPT level (misalnya "N1", "N2", dst, atau "Semua" untuk tidak memfilter)
  /// - [limit]: batas maksimum data yang diambil
// Perubahan pada method getDataByType: tambahkan parameter offset
  Future<List<Map<String, dynamic>>> getDataByType(
    String type,
    bool acak, {
    String? jlptLevel,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    try {
      String query = "SELECT * FROM $type";
      List<dynamic> args = [];

      if (jlptLevel != null && jlptLevel != "Semua") {
        query += " WHERE jlpt_level = ?";
        args.add(jlptLevel);
      }

      if (acak) {
        query += " ORDER BY RANDOM()";
      }

      if (limit != null) {
        query += " LIMIT $limit";
      }
      if (offset != null) {
        query += " OFFSET $offset";
      }
      return await db.rawQuery(query, args);
    } catch (e) {
      throw Exception("Gagal mengambil data: ${e.toString()}");
    }
  }

  /// Mengambil jumlah data dari tabel advanced berdasarkan filter JLPT level.
  Future<int> getCountByType(String type, {String? jlptLevel}) async {
    final db = await database;
    try {
      String query = "SELECT COUNT(*) as count FROM $type";
      List<dynamic> args = [];
      if (jlptLevel != null && jlptLevel != "Semua") {
        query += " WHERE jlpt_level = ?";
        args.add(jlptLevel);
      }
      var result = await db.rawQuery(query, args);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw Exception("Gagal mengambil count data: ${e.toString()}");
    }
  }

  /// Mengambil daftar kategori unik berdasarkan jenis dari tabel hirakana
  Future<Map<String, List<String>>> getKategoriOptions() async {
    final db = await database;
    try {
      final result = await db.rawQuery("""
        SELECT DISTINCT jenis, kategori 
        FROM hirakana
      """);
      Map<String, List<String>> kategoriMap = {};
      for (var row in result) {
        final jenis = row['jenis'] as String;
        final kategori = row['kategori'] as String;
        if (kategoriMap.containsKey(jenis)) {
          if (!kategoriMap[jenis]!.contains(kategori)) {
            kategoriMap[jenis]!.add(kategori);
          }
        } else {
          kategoriMap[jenis] = [kategori];
        }
      }
      return kategoriMap;
    } catch (e) {
      throw Exception("Gagal mengambil kategori: ${e.toString()}");
    }
  }

  /// Menutup database (opsional)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
