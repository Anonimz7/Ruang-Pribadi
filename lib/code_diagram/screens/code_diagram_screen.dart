import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:puml_canvas/puml_canvas.dart';

/// ═══════════════════════════════════════════════════════
/// CODE DIAGRAM — Tulis kode PlantUML → render → simpan PNG
/// ═══════════════════════════════════════════════════════
/// Editor monospace multi-line di atas, tombol Render di tengah,
/// preview diagram via `PumlView` (puml_canvas, render native canvas).
/// Simpan PNG lewat `saveFile` dialog (FilePicker).
/// ═══════════════════════════════════════════════════════
class CodeDiagramScreen extends StatefulWidget {
  const CodeDiagramScreen({super.key});

  @override
  State<CodeDiagramScreen> createState() => _CodeDiagramScreenState();
}

class _CodeDiagramScreenState extends State<CodeDiagramScreen> {
  static const _initialSource = '''
@startuml
class Product {
  +name: string
  +price: int
}
class Order {
  -items: List<Product>
}
Order "1" --> "*" Product
@enduml
''';

  late final TextEditingController _controller =
      TextEditingController(text: _initialSource);
  final _boundaryKey = GlobalKey();
  String _source = _initialSource;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Simpan preview (RepaintBoundary) sebagai file PNG via save dialog.
  Future<void> _savePng() async {
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _showSnack('Belum ada render yang bisa disimpan.');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        _showSnack('Gagal mengenkode gambar.');
        return;
      }

      final path = await FilePicker.saveFile(
        dialogTitle: 'Simpan Diagram PNG',
        fileName: 'diagram.png',
        type: FileType.image,
        allowedExtensions: ['png'],
      );
      if (path == null) return; // dibatalkan user

      final file = File(path);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      _showSnack('Tersimpan: $path');
    } catch (e) {
      _showSnack('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    final boardColor =
        Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFFFFFFFF);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ─── Editor kode ─────────────────────
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
                  onPressed: () =>
                      setState(() => _source = _controller.text),
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
            'Preview di-render native (puml_canvas) — latar putih agar PNG rapi.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          // ─── Preview (zoom/geser, binder putih agar PNG rapi) ──
          // RepaintBoundary di DALAM InteractiveViewer: PNG selalu skala dasar,
          // tidak ikut transform zoom/geser.
          InteractiveViewer(
            minScale: 0.2,
            maxScale: 4,
            child: RepaintBoundary(
              key: _boundaryKey,
              child: Container(
                color: boardColor,
                padding: const EdgeInsets.all(12),
                alignment: Alignment.topLeft,
                child: PumlView(source: _source),
              ),
            ),
          ),
        ],
      ),
    );
  }
}