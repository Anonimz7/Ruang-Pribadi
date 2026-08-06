import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════
/// ROULETTE TICKER - Efek suara & visual jarum
/// ═══════════════════════════════════════════════════════
/// Menghasilkan suara "tik" saat jarum melewati paku
/// dan memberikan offset getaran pada jarum
/// ═══════════════════════════════════════════════════════

class RouletteTicker {
  static final RouletteTicker _instance = RouletteTicker._internal();
  factory RouletteTicker() => _instance;
  RouletteTicker._internal();

  // Cache audio
  ByteData? _audioData;
  
  /// Jumlah paku di sekitar roda (harus sama dengan jumlah sektor × multiplier)
  int pegCount = 40;
  
  /// Sudut antar paku dalam derajat
  double get pegAngle => 360 / pegCount;
  
  /// Posisi paku terakhir yang dilewati (untuk deteksi edge)
  int _lastPegIndex = -1;
  
  /// Stream controller untuk notify getaran jarum
  final _tickController = StreamController<double>.broadcast();
  Stream<double> get tickStream => _tickController.stream;
  
  /// Load audio tick.wav
  Future<void> loadAudio() async {
    if (_audioData != null) return;
    try {
      _audioData = await rootBundle.load('assets/sounds/tick.wav');
      debugPrint('RouletteTicker: Audio loaded successfully');
    } catch (e) {
      debugPrint('RouletteTicker: Failed to load audio - $e');
    }
  }
  
  /// Play sound tick
  void _playTick() {
    if (_audioData == null) return;
    // Catatan: Flutter tidak punya built-in audio player sederhana
    // Untuk production, gunakan package seperti 'audioplayers' atau 'just_audio'
    // Di sini kita hanya trigger stream untuk visual feedback
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
    
    // Hitung indeks paku saat ini
    final currentPegIndex = (normalizedAngle / pegAngle).floor() % pegCount;
    
    // Deteksi perubahan paku (edge detection)
    if (currentPegIndex != _lastPegIndex && _lastPegIndex >= 0) {
      // Trigger tick
      _tickController.add(angularVelocity / 100); // Normalize untuk visual
      _playTick();
    }
    
    _lastPegIndex = currentPegIndex;
  }
  
  /// Dapatkan offset getaran untuk jarum berdasarkan proximity ke paku
  /// Returns rotation offset in degrees (-2 to +2 max)
  double getNeedleVibration(double currentAngle, double angularVelocity) {
    if (angularVelocity < 5) return 0;
    
    final normalizedAngle = ((currentAngle % 360) + 360) % 360;
    final angleWithinPeg = normalizedAngle % pegAngle;
    final centerOfPeg = pegAngle / 2;
    final distanceFromCenter = (angleWithinPeg - centerOfPeg).abs();
    
    // Getaran maksimal saat tepat di paku, minimal di antara paku
    final vibrationStrength = (1 - distanceFromCenter / centerOfPeg);
    final maxVibration = 2.0 * (angularVelocity / 200).clamp(0, 1);
    
    return (angleWithinPeg < centerOfPeg ? 1 : -1) * 
           vibrationStrength * maxVibration;
  }
  
  void dispose() {
    _tickController.close();
  }
}
