import 'dart:async';
import 'package:flutter/material.dart';
import '../services/update_service.dart';

/// Shows an update notification dialog if a newer version is available.
/// Returns true if user triggered download.
Future<bool> showUpdateDialogIfNeeded(BuildContext context, UpdateInfo info) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _UpdateDialog(info: info),
  );
  return result ?? false;
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _apkPath;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final updateService = UpdateService();
      _apkPath = await updateService.downloadApk(
        widget.info.downloadUrl!,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      // Show install dialog
      if (mounted) {
        Navigator.pop(context); // close download dialog
        await _showInstallDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Download gagal: $e')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _showInstallDialog() async {
    if (_apkPath == null) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📥 Download Selesai'),
        content: const Text('APK berhasil diunduh. Buka file untuk install?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nanti'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await UpdateService().installApk(_apkPath!);
            },
            child: const Text('Install Sekarang'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_downloading) {
      return _DownloadProgress(progress: _progress, info: widget.info);
    }
    return AlertDialog(
      title: const Row(
        children: [
          Text('🔄 ', style: TextStyle(fontSize: 24)),
          Text('Update Tersedia!'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versi baru: ${widget.info.versionName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Ukuran: ${widget.info.fileSizeMb} MB',
                style: const TextStyle(color: Colors.grey)),
            if (widget.info.changelog != null &&
                widget.info.changelog!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Perubahan:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.info.changelog!,
                    style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Nanti'),
        ),
        ElevatedButton(
          onPressed: () => setState(() => _downloading = true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C87A),
          ),
          child: const Text('Download & Install',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  final double progress;
  final UpdateInfo info;
  const _DownloadProgress({required this.progress, required this.info});

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).toStringAsFixed(0);
    final sizeMb = info.fileSizeMb ?? 0;
    final downloaded = (sizeMb * progress).toStringAsFixed(1);
    return AlertDialog(
      title: const Text('📥 Mengunduh Update...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress > 0 ? progress : null,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF00C87A)),
          ),
          const SizedBox(height: 12),
          Text('$percent%  ($downloaded / $sizeMb MB)',
              style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
