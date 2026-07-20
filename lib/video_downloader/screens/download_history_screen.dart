import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/download_model.dart';
import '../../services/apis.dart';
import '../../services/api_config.dart';
import '../../services/api_client.dart';

class DownloadHistoryScreen extends StatefulWidget {
  const DownloadHistoryScreen({super.key});

  @override
  State<DownloadHistoryScreen> createState() => _DownloadHistoryScreenState();
}

class _DownloadHistoryScreenState extends State<DownloadHistoryScreen> {
  final _videoApi = VideoApi();
  List<DownloadRecord> _records = [];
  bool _loading = true;
  WebSocketChannel? _wsChannel;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final data = await _videoApi.history();
      setState(() {
        _records = data.map((e) => DownloadRecord.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _connectWebSocket() {
    try {
      final baseUrl = ApiConfig.baseUrl.replaceFirst('http', 'ws');
      final userId = ApiClient().username;
      final wsUrl = '$baseUrl/ws/video-progress/$userId';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _wsChannel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data);
            final id = msg['id'];
            final status = msg['status'];
            final progress = (msg['progress'] ?? 0).toDouble();
            setState(() {
              for (var i = 0; i < _records.length; i++) {
                if (_records[i].id == id) {
                  _records[i] = DownloadRecord(
                    id: _records[i].id,
                    url: _records[i].url,
                    title: _records[i].title,
                    thumbnail: _records[i].thumbnail,
                    duration: _records[i].duration,
                    ext: _records[i].ext,
                    fileSize: _records[i].fileSize,
                    status: status ?? _records[i].status,
                    progress: progress,
                    createdAt: _records[i].createdAt,
                  );
                  break;
                }
              }
            });
            if (status == 'completed') _loadHistory();
          } catch (_) {}
        },
        onDone: () {},
        onError: (_) {},
      );
    } catch (_) {}
  }

  Future<void> _playVideo(DownloadRecord record) async {
    final url = _videoApi.streamUrl(record.id);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _deleteRecord(DownloadRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Download?'),
        content: Text('Hapus "${record.title ?? 'video ini'}" dari riwayat?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _videoApi.delete(record.id);
        _loadHistory();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus: $e')),
          );
        }
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Download'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_done, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Belum ada download',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];
          return _buildRecordCard(record);
        },
      ),
    );
  }

  Widget _buildRecordCard(DownloadRecord record) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: InkWell(
        onTap: record.isCompleted ? () => _playVideo(record) : null,
        child: Row(
          children: [
            // Thumbnail
            if (record.thumbnail != null)
              Image.network(
                record.thumbnail!,
                width: 120,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image),
                ),
              )
            else
              Container(
                width: 120,
                height: 80,
                color: Colors.grey.shade200,
                child: const Icon(Icons.video_library, size: 32),
              ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title ?? 'Video',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Status badge
                        _buildStatusBadge(record),
                        const SizedBox(width: 8),
                        if (record.fileSizeText != '—')
                          Text(
                            record.fileSizeText,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        if (record.ext != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            record.ext!.toUpperCase(),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                    // Progress bar for active downloads
                    if (record.isDownloading) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: record.progress / 100,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            if (record.isCompleted)
              IconButton(
                icon: const Icon(Icons.play_circle_fill, color: Colors.green),
                onPressed: () => _playVideo(record),
              ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
              onPressed: () => _deleteRecord(record),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(DownloadRecord record) {
    Color bgColor;
    Color textColor;
    IconData icon;

    if (record.isCompleted) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      icon = Icons.check_circle;
    } else if (record.isFailed) {
      bgColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      icon = Icons.error;
    } else {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      icon = Icons.hourglass_top;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 3),
          Text(
            record.statusText,
            style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
