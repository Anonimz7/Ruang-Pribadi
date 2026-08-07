import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/plantuml_client.dart';

/// ═══════════════════════════════════════════════════════
/// CODE DIAGRAM — Tulis kode PlantUML → render (server) → simpan PNG
/// ═══════════════════════════════════════════════════════
/// Editor monospace multi-line di atas, tombol Render di tengah.
/// Render via PlantUML server asli (graphviz) → hasil rapi,
/// warna per-stereotype & note didukung penuh.
/// Simpan PNG: byte dari server langsung ditulis lewat save dialog.
/// ═══════════════════════════════════════════════════════
class CodeDiagramScreen extends StatefulWidget {
  const CodeDiagramScreen({super.key});

  @override
  State<CodeDiagramScreen> createState() => _CodeDiagramScreenState();
}

class _CodeDiagramScreenState extends State<CodeDiagramScreen> {
  static const _initialSource = '''
@startuml
Alice -> Bob: Hello
Bob --> Alice: Hi!
@enduml
''';

  late final TextEditingController _controller =
      TextEditingController(text: _initialSource);
  final _client = PlantumlClient();

  Uint8List? _png;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _render() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _png = null;
    });
    try {
      final png = await _client.fetchPng(_controller.text);
      if (!mounted) return;
      setState(() => _png = png);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Simpan byte PNG (hasil server) via save dialog.
  Future<void> _savePng() async {
    final png = _png;
    if (png == null) {
      _showSnack('Belum ada hasil render.');
      return;
    }
    setState(() => _saving = true);
    try {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Diagram PNG',
        fileName: 'diagram.png',
        type: FileType.image,
        allowedExtensions: ['png'],
        bytes: png,
      );
      if (path == null) return; // dibatalkan user
      _showSnack('Tersimpan: $path');
    } catch (e) {
      _showSnack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  Widget _buildPreview() {
    if (_loading) {
      return const CircularProgressIndicator();
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        ),
      );
    }
    if (_png != null) {
      return InteractiveViewer(
        minScale: 0.2,
        maxScale: 4,
        child: Center(
          child: Image.memory(
            _png!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      );
    }
    return const Text(
      'Tekan Render untuk melihat hasil',
      style: TextStyle(color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Render Diagram'),
      ),
      body: Column(
        children: [
          // ─── Editor + tombol aksi (scroll sendiri) ──
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              children: [
                TextField(
                  controller: _controller,
                  minLines: 8,
                  maxLines: 14,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    labelText: 'Kode PlantUML',
                    hintText: '@startuml\n...\n@enduml',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                // ─── Tombol aksi ─────────────────────
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _render,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Render'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : _savePng,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_alt),
                        label: const Text('Simpan PNG'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Render via PlantUML server (butuh internet).',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          // ─── Preview: Expanded → sisa tinggi layar ──
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.white,
              alignment: Alignment.center,
              child: _buildPreview(),
            ),
          ),
        ],
      ),
    );
  }
}