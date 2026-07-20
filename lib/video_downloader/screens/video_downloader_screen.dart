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

  // Collapsible group states
  bool _combinedExpanded = true;
  bool _videoOnlyExpanded = false;
  bool _audioExpanded = true;

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
      final vi =
          VideoInfo.fromJson((info['data'] ?? info) as Map<String, dynamic>);
      setState(() {
        _videoInfo = vi;
        _extracting = false;

        // Find best format: prefer 720p combined, then 720p video-only, then first combined
        final combined = vi.formats.where((f) => f.hasBothCodecs).toList();
        final videoOnly = vi.formats.where((f) => f.isVideoOnly).toList();
        VideoFormat? best;

        // Try to find 720p
        for (final f in combined) {
          if ((f.resolution ?? '').contains('720') ||
              (f.formatNote ?? '').contains('720')) {
            best = f;
            break;
          }
        }
        if (best == null) {
          for (final f in videoOnly) {
            if ((f.resolution ?? '').contains('720') ||
                (f.formatNote ?? '').contains('720')) {
              best = f;
              break;
            }
          }
        }
        // Fallback: first combined, then first video-only
        best ??= combined.isNotEmpty
            ? combined.first
            : (videoOnly.isNotEmpty ? videoOnly.first : null);

        _selectedFormat = best;

        // Auto-expand the group containing the selected format
        if (best != null) {
          if (best.hasBothCodecs) {
            _combinedExpanded = true;
            _videoOnlyExpanded = false;
          } else if (best.isVideoOnly) {
            _combinedExpanded = false;
            _videoOnlyExpanded = true;
          }
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
        _error =
            'Download gagal: ${e.toString().replaceAll('Exception: ', '')}';
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
          if (_videoInfo != null && !_extracting && !_downloading)
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
          // Thumbnail with duration badge
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
                    child:
                        const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
                ),
                if (info.duration != null)
                  Container(
                    margin: const EdgeInsets.all(8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDuration(info.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),

          // Video info
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (info.uploader != null) ...[
                      Icon(Icons.person_outline,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          info.uploader!,
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${info.formats.length} format',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
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
    final videoFormats = formats.where((f) => f.isVideoOnly).toList();
    final combinedFormats = formats.where((f) => f.hasBothCodecs).toList();
    final audioFormats = formats.where((f) => f.isAudioOnly).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Audio-only toggle
        SwitchListTile(
          title: const Text('🎵 Audio Saja'),
          subtitle: const Text('Download hanya audio'),
          value: _audioOnly,
          onChanged: (v) => setState(() {
            _audioOnly = v;
            _selectedFormat = null;
          }),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),

        // ── Audio-only formats ──
        if (_audioOnly && audioFormats.isNotEmpty)
          _buildCollapsibleGroup(
            title: 'Audio Formats',
            count: audioFormats.length,
            expanded: _audioExpanded,
            onToggle: () => setState(() => _audioExpanded = !_audioExpanded),
            children: audioFormats.map((f) => _buildFormatTile(f)).toList(),
          ),

        // ── Video formats ──
        if (!_audioOnly) ...[
          if (combinedFormats.isNotEmpty)
            _buildCollapsibleGroup(
              title: 'Video + Audio',
              count: combinedFormats.length,
              expanded: _combinedExpanded,
              onToggle: () =>
                  setState(() => _combinedExpanded = !_combinedExpanded),
              children:
                  combinedFormats.map((f) => _buildFormatTile(f)).toList(),
            ),
          if (videoFormats.isNotEmpty) ...[
            _buildCollapsibleGroup(
              title: 'Video Saja (tanpa audio)',
              count: videoFormats.length,
              expanded: _videoOnlyExpanded,
              onToggle: () =>
                  setState(() => _videoOnlyExpanded = !_videoOnlyExpanded),
              children: [
                // Info banner
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Video-only akan di-download lalu di-merge otomatis dengan audio terbaik',
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                ...videoFormats.map((f) => _buildFormatTile(f)),
              ],
            ),
          ],
          if (combinedFormats.isEmpty && videoFormats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Tidak ada format video tersedia',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildCollapsibleGroup({
    required String title,
    required int count,
    required bool expanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 22,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(children: children),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatTile(VideoFormat f) {
    final isSelected = _selectedFormat?.formatId == f.formatId;
    return RadioListTile<VideoFormat>(
      value: f,
      groupValue: _selectedFormat,
      onChanged: (v) => setState(() => _selectedFormat = v),
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Row(
        children: [
          // Resolution
          Text(
            f.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          // Codec badges
          if (f.vcodecLabel.isNotEmpty)
            _buildCodecBadge(f.vcodecLabel, Colors.blue.shade700),
          if (f.acodecLabel.isNotEmpty) ...[
            const SizedBox(width: 4),
            _buildCodecBadge(f.acodecLabel, Colors.teal.shade700),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          Text(
            f.fileSizeKb,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          if (f.formatNote != null && f.formatNote!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              f.formatNote!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
          if (f.abr != null && f.abr! > 0) ...[
            const SizedBox(width: 8),
            Text(
              '${f.abr!.toStringAsFixed(0)} kbps',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCodecBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
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
    final isVideoOnly = _selectedFormat?.isVideoOnly ?? false;
    final label = _audioOnly
        ? 'Download Audio'
        : isVideoOnly
            ? 'Download Video + Audio (Merge)'
            : 'Download Video';
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _startDownload,
        icon: const Icon(Icons.download),
        label: Text(label),
      ),
    );
  }
}
