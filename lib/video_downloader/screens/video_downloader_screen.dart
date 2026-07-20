import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/download_model.dart';
import '../../services/apis.dart';
import '../../services/api_config.dart';
import '../../services/api_client.dart';
import 'download_history_screen.dart';
import '../../settings/admin_cookies_screen.dart';

class VideoDownloaderScreen extends StatefulWidget {
  const VideoDownloaderScreen({super.key});

  @override
  State<VideoDownloaderScreen> createState() => _VideoDownloaderScreenState();
}

class _VideoDownloaderScreenState extends State<VideoDownloaderScreen> {
  final _urlCtrl = TextEditingController();
  final _videoApi = VideoApi();
  final _focusNode = FocusNode();

  VideoInfo? _videoInfo;
  bool _extracting = false;
  bool _downloading = false;
  int? _downloadId;
  double _progress = 0;
  String _downloadStatus = '';
  String? _error;

  WebSocketChannel? _wsChannel;
  VideoFormat? _selectedFormat;
  bool _audioOnly = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _focusNode.dispose();
    _wsChannel?.sink.close();
    super.dispose();
  }

  // ── Extract ─────────────────────────────────────────────
  Future<void> _extract() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Masukkan URL video');
      return;
    }

    setState(() {
      _extracting = true;
      _error = null;
      _videoInfo = null;
      _selectedFormat = null;
    });

    try {
      final info = await _videoApi.extract(url);
      final vi = VideoInfo.fromJson(info);
      setState(() {
        _videoInfo = vi;
        _extracting = false;
        // Auto-select best format
        if (vi.formats.isNotEmpty) {
          _selectedFormat = vi.formats.first;
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal: ${e.toString().replaceAll('Exception: ', '')}';
        _extracting = false;
      });
    }
  }

  // ── Download ────────────────────────────────────────────
  Future<void> _startDownload() async {
    if (_selectedFormat == null && !_audioOnly) return;
    final url = _urlCtrl.text.trim();

    setState(() {
      _downloading = true;
      _progress = 0;
      _downloadStatus = 'Memulai...';
      _error = null;
    });

    try {
      final result = await _videoApi.download(
        url,
        _audioOnly ? 'bestaudio' : (_selectedFormat?.formatId ?? 'best'),
        audioOnly: _audioOnly,
      );
      final recordId = result['id'] as int;
      setState(() {
        _downloadId = recordId;
        _downloadStatus = 'Mengunduh...';
      });
      _connectWebSocket(recordId);
    } catch (e) {
      setState(() {
        _downloading = false;
        _error = 'Download gagal: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  // ── WebSocket Progress ──────────────────────────────────
  void _connectWebSocket(int recordId) {
    try {
      final baseUrl = ApiConfig.baseUrl.replaceFirst('http', 'ws');
      final userId = ApiClient().username; // use as channel key
      final wsUrl = '$baseUrl/ws/video-progress/$userId';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _wsChannel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data);
            if (msg['id'] == recordId) {
              final pct = (msg['progress'] ?? 0).toDouble();
              final status = msg['status'] as String?;
              setState(() {
                _progress = pct;
                _downloadStatus = status ?? 'Mengunduh...';
                if (status == 'completed') {
                  _downloading = false;
                } else if (status == 'failed') {
                  _downloading = false;
                  _error = msg['error'] ?? 'Download gagal';
                }
              });
            }
          } catch (_) {}
        },
        onDone: () {},
        onError: (_) {},
      );
    } catch (_) {}
  }

  // ── Helpers ─────────────────────────────────────────────
  String _formatDuration(int? seconds) {
    if (seconds == null) return '';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      _urlCtrl.text = data!.text!;
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Downloader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cookie),
            tooltip: 'Kelola Cookies',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminCookiesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Riwayat Download',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DownloadHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── URL Input ──
          _buildUrlInput(),
          const SizedBox(height: 16),

          // ── Error ──
          if (_error != null) _buildError(),
          if (_error != null) const SizedBox(height: 12),

          // ── Extracting ──
          if (_extracting) _buildExtracting(),

          // ── Video Info ──
          if (_videoInfo != null && !_extracting) ...[
            _buildVideoCard(),
            const SizedBox(height: 16),
            _buildFormatSelector(),
            const SizedBox(height: 16),
          ],

          // ── Download Progress ──
          if (_downloading) ...[
            _buildProgressSection(),
            const SizedBox(height: 16),
          ],

          // ── Download Button ──
          if (_videoInfo != null &&
              !_extracting &&
              !_downloading)
            _buildDownloadButton(),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _urlCtrl,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Paste URL video di sini...',
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _extract(),
          ),
        ),
        const SizedBox(width: 8),
        // Paste button
        IconButton.filled(
          onPressed: _pasteFromClipboard,
          icon: const Icon(Icons.paste, size: 20),
          tooltip: 'Paste dari clipboard',
        ),
        const SizedBox(width: 8),
        // Extract button
        FilledButton(
          onPressed: _extracting ? null : _extract,
          child: _extracting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Extract'),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtracting() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Menganalisis video...', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard() {
    final info = _videoInfo!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          if (info.thumbnail != null)
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Image.network(
                  info.thumbnail!,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
                if (info.duration != null)
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(info.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (info.uploader != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    info.uploader!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${info.formats.length} format tersedia',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector() {
    final formats = _videoInfo!.formats;
    // Separate video and audio formats
    final videoFormats = formats
        .where((f) => f.isVideoOnly || (f.vcodec != null && f.vcodec != 'none'))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📹 Pilih Format:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),

        // Audio-only toggle
        SwitchListTile(
          title: const Text('🎵 Audio Only (MP3)'),
          subtitle: const Text('Download hanya audio dalam format MP3'),
          value: _audioOnly,
          onChanged: (v) => setState(() => _audioOnly = v),
          contentPadding: EdgeInsets.zero,
        ),

        if (!_audioOnly && videoFormats.isNotEmpty) ...[
          // Format list
          ...videoFormats.map((f) {
            final isSelected = _selectedFormat?.formatId == f.formatId;
            return RadioListTile<VideoFormat>(
              title: Text(f.label, style: const TextStyle(fontSize: 14)),
              subtitle: Text(f.fileSizeKb, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              value: f,
              groupValue: _selectedFormat,
              onChanged: (v) => setState(() => _selectedFormat = v),
              contentPadding: EdgeInsets.zero,
              dense: true,
            );
          }),
        ],
      ],
    );
  }

  Widget _buildProgressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _progress >= 100 ? Icons.check_circle : Icons.downloading,
                  color: _progress >= 100 ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _progress >= 100 ? 'Selesai!' : 'Mengunduh...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${_progress.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Text(
              _downloadStatus,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _startDownload,
        icon: const Icon(Icons.download),
        label: Text(
          _audioOnly ? '⬇ Download Audio (MP3)' : '⬇ Download Video',
        ),
      ),
    );
  }
}
