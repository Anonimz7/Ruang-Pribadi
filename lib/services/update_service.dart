import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_config.dart';
import '../config/app_version.dart';

class UpdateInfo {
  final bool updateAvailable;
  final String? versionName;
  final int? versionCode;
  final String? changelog;
  final double? fileSizeMb;
  final String? downloadUrl;

  UpdateInfo({
    required this.updateAvailable,
    this.versionName,
    this.versionCode,
    this.changelog,
    this.fileSizeMb,
    this.downloadUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      updateAvailable: json['update_available'] ?? false,
      versionName: json['version_name'],
      versionCode: json['version_code'],
      changelog: json['changelog'],
      fileSizeMb: (json['file_size_mb'] as num?)?.toDouble(),
      downloadUrl: json['download_url'],
    );
  }
}

class UpdateService {
  static final UpdateService _instance = UpdateService._();
  factory UpdateService() => _instance;
  UpdateService._();

  /// Check for update from server (public endpoint, no auth needed)
  Future<UpdateInfo?> checkUpdate() async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.prefix}/update/check?current_version_code=${AppVersion.code}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UpdateInfo.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return null;
  }

  /// Download APK to temp directory with progress callback
  Future<String> downloadApk(
    String downloadUrl, {
    Function(double progress)? onProgress,
  }) async {
    final fullUrl = '${ApiConfig.baseUrl}${ApiConfig.prefix}$downloadUrl';
    final uri = Uri.parse(fullUrl);

    final client = http.Client();
    final request = http.Request('GET', uri);
    final streamedResponse = await client.send(request);
    final contentLength = streamedResponse.contentLength ?? 0;

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/update.apk';
    final file = File(filePath);
    final sink = file.openWrite();

    int received = 0;
    await for (final chunk in streamedResponse.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (contentLength > 0 && onProgress != null) {
        onProgress(received / contentLength);
      }
    }
    await sink.close();
    client.close();

    return filePath;
  }

  /// Open APK file for installation
  Future<void> installApk(String apkPath) async {
    final file = File(apkPath);
    if (!await file.exists()) return;

    final uri = Uri.file(apkPath);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Get update info from login response (owner only)
  UpdateInfo? parseUpdateFromLogin(Map<String, dynamic> userData) {
    final updateData = userData['update'];
    if (updateData == null) return null;
    return UpdateInfo.fromJson(Map<String, dynamic>.from(updateData));
  }
}
