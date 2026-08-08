import 'package:flutter/material.dart';
import '../../services/apis.dart';

/// Halaman fokus: tampilkan semua pasangan a⟷b dari satu dokumen.
class BahasaDetailScreen extends StatefulWidget {
  final int id;

  const BahasaDetailScreen({super.key, required this.id});

  @override
  State<BahasaDetailScreen> createState() => _BahasaDetailScreenState();
}

class _BahasaDetailScreenState extends State<BahasaDetailScreen> {
  final _api = BahasaApi();

  Map<String, dynamic>? _doc;
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doc = await _api.get(widget.id);
      setState(() => _doc = doc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> get _entries {
    final all = ((_doc?['entries']) as List?) ?? [];
    if (_q.trim().isEmpty) return all;
    final q = _q.trim().toLowerCase();
    return all.where((e) {
      final a = (e['a'] ?? '').toString().toLowerCase();
      final b = (e['b'] ?? '').toString().toLowerCase();
      return a.contains(q) || b.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      appBar: AppBar(
        title: Text(doc?['judul'] ?? 'Detail'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : doc == null
              ? const Center(child: Text('Dokumen tidak ditemukan'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${doc['string_lang']} • ${doc['jumlah_entri']} entri',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                    ),
                    // ── Pencarian ──
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari kata...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _q = v),
                      ),
                    ),
                    // ── Daftar entri a⟷b ──
                    Expanded(
                      child: _entries.isEmpty
                          ? const Center(
                              child: Text('Tidak ada hasil',
                                  style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: _entries.length,
                              itemBuilder: (_, i) {
                                final e = _entries[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '${e['a']}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8),
                                          child: Icon(Icons.arrow_forward,
                                              size: 16, color: Colors.grey),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            '${e['b']}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF00C87A)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}