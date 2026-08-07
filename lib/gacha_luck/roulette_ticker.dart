import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════
/// ROULETTE TICKER - Efek suara & visual jarum
/// ═══════════════════════════════════════════════════════
/// Menghasilkan suara "tik" saat jarum melewati paku
/// dan memberi impuls getaran pada jarum
/// ═══════════════════════════════════════════════════════

class RouletteTicker {
  static final RouletteTicker _instance = RouletteTicker._internal();
  factory RouletteTicker() => _instance;

  RouletteTicker._internal();

  // Pemutar audio dengan sumber bunyi tick yang disiapkan
  AudioPlayer _player = AudioPlayer();

  /// Jumlah paku di sekitar roda — diisi dari screen pemakai
  /// (harus = jumlah sektor, karena 1 paku per garis batas)
  int pegCount = 40;

  /// Sudut antar paku dalam derajat
  double get pegAngle => 360 / pegCount;

  /// Posisi paku terakhir yang dilewati (untuk deteksi edge)
  int _lastPegIndex = -1;

  /// Stream controller untuk notify getaran jarum
  final _tickController = StreamController<double>.broadcast();
  Stream<double> get tickStream => _tickController.stream;

  /// Siapkan sumber bunyi tick (panggil sekali saat init)
  Future<void> loadAudio() async {
    try {
      // Bikin ulang player kalau pernah di-dispose (pengaman singleton)
      if (_player.state == PlayerState.disposed) {
        _player = AudioPlayer();
      }
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSource(AssetSource('sounds/tick.wav'));
    } catch (e) {
      debugPrint('RouletteTicker: Failed to init audio - $e');
    }
  }

  /// Play bunyi 'tik' — ulang dari awal tanpa melepas sumber,
  /// supaya bisa diputar beruntun dengan cepat & sinkron dgn hantaman
  void _playTick() {
    if (_player.state == PlayerState.disposed) return;
    // stop() melepas sumber; pakai seek(0)+resume agar tetap berbunyi
    _player.seek(Duration.zero);
    _player.resume();
  }

  /// Reset state saat spin baru dimulai
  void reset() {
    _lastPegIndex = -1;
  }

  /// Cek apakah ada paku yang dilewati berdasarkan sudut saat ini
  /// [currentAngle] dalam derajat, [angularVelocity] dalam derajat/detik
  void update(double currentAngle, double angularVelocity) {
    if (angularVelocity < 10) return; // Abaikan jika sangat lambat

    // Normalisasi sudut ke [0, 360)
    final normalizedAngle = ((currentAngle % 360) + 360) % 360;

    // Jarum statis di jam 12 (270°); hitung sambaran relatif ke posisi
    // jarum agar 'tik' & dorongan jarum terjadi pas paku menyentuh jarum.
    const needleAngle = 270.0;
    final passed = (((needleAngle - normalizedAngle) % 360) + 360) % 360;
    final currentPegIndex = (passed / pegAngle).floor() % pegCount;

    // Deteksi perubahan paku (edge detection)
    if (currentPegIndex != _lastPegIndex && _lastPegIndex >= 0) {
      // Trigger tick
      _tickController.add(angularVelocity / 100); // Normalize untuk visual
      _playTick();
    }

    _lastPegIndex = currentPegIndex;
  }

  void dispose() {
    _tickController.close();
    _player.dispose();
  }
}