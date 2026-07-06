import 'package:flutter/material.dart';
import '../database/database.dart';

class BahasaJepun extends StatelessWidget {
  const BahasaJepun({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Fitur asli untuk tabel hirakana
  String? selectedJenis;
  String? selectedKategori;
  bool isAcak = false;
  bool isSensorKarakterEnabled = false;
  bool isSensorRomajiEnabled = false;
  bool isMultiViewEnabled = false;
  int slideCount = 2;
  Map<String, List<String>> kategoriOptions = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchKategoriOptions();
  }

  void fetchKategoriOptions() async {
    final result = await DatabaseHelper().getKategoriOptions();
    setState(() {
      kategoriOptions = result;
      isLoading = false;
    });
  }

  void showCategoryDialog() {
    if (selectedJenis != null && selectedKategori == null) {
      selectedKategori = kategoriOptions[selectedJenis!]!.first;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Kategori'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedJenis != null)
                      ...kategoriOptions[selectedJenis!]!.map((kategori) {
                        return RadioListTile(
                          title: Text(kategori),
                          value: kategori,
                          groupValue: selectedKategori,
                          onChanged: (value) {
                            setStateDialog(() {
                              selectedKategori = value;
                            });
                          },
                        );
                      }),
                    SwitchListTile(
                      title: const Text("Acak Data"),
                      value: isAcak,
                      onChanged: (bool value) {
                        setStateDialog(() {
                          isAcak = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text("Sensor Karakter"),
                      value: isSensorKarakterEnabled,
                      onChanged: (bool value) {
                        setStateDialog(() {
                          isSensorKarakterEnabled = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text("Sensor Romaji"),
                      value: isSensorRomajiEnabled,
                      onChanged: (bool value) {
                        setStateDialog(() {
                          isSensorRomajiEnabled = value;
                        });
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: const Text("Multi View"),
                      value: isMultiViewEnabled,
                      onChanged: (bool value) {
                        setStateDialog(() {
                          isMultiViewEnabled = value;
                        });
                      },
                    ),
                    if (isMultiViewEnabled)
                      Column(
                        children: [
                          const Text("Jumlah Huruf per Halaman"),
                          Slider(
                            value: slideCount.toDouble(),
                            min: 2,
                            max: 5,
                            divisions: 3,
                            label: "$slideCount",
                            onChanged: (double value) {
                              setStateDialog(() {
                                slideCount = value.toInt();
                              });
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text("Proses"),
              onPressed: () {
                Navigator.pop(context);
                if (selectedJenis != null && selectedKategori != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultPage(
                        jenis: selectedJenis!,
                        kategori: selectedKategori!,
                        acak: isAcak,
                        sensorKarakter: isSensorKarakterEnabled,
                        sensorRomaji: isSensorRomajiEnabled,
                        multiView: isMultiViewEnabled,
                        slideCount: slideCount,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fitur asli untuk tabel hirakana
            DropdownButton<String>(
              hint: const Text("Pilih Jenis"),
              value: selectedJenis,
              items: kategoriOptions.keys.map((jenis) {
                return DropdownMenuItem<String>(
                  value: jenis,
                  child: Text(jenis),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedJenis = value;
                  selectedKategori = kategoriOptions[value!]!.first;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: selectedJenis != null ? showCategoryDialog : null,
              child: const Text("Proses"),
            ),
            const SizedBox(height: 20),
            // Tombol untuk fitur Advanced
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdvancedPage()),
                );
              },
              child: const Text("Advanced"),
            ),
          ],
        ),
      ),
    );
  }
}

/// ResultPage untuk tabel hirakana
class ResultPage extends StatefulWidget {
  final String jenis;
  final String kategori;
  final bool acak;
  final bool sensorKarakter;
  final bool sensorRomaji;
  final bool multiView;
  final int slideCount;
  const ResultPage({
    super.key,
    required this.jenis,
    required this.kategori,
    required this.acak,
    required this.sensorKarakter,
    required this.sensorRomaji,
    required this.multiView,
    required this.slideCount,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  List<Map<String, dynamic>> data = [];
  int currentIndex = 0;
  bool isKarakterHidden = true;
  bool isRomajiHidden = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  void fetchData() async {
    var result = await DatabaseHelper()
        .getData(widget.jenis, widget.kategori, widget.acak);
    setState(() {
      data = result;
    });
  }

  void nextCharacter() {
    int increment = widget.multiView ? widget.slideCount : 1;
    if (currentIndex + increment < data.length) {
      setState(() {
        currentIndex += increment;
        isKarakterHidden = true;
        isRomajiHidden = true;
      });
    }
  }

  void backCharacter() {
    int decrement = widget.multiView ? widget.slideCount : 1;
    if (currentIndex - decrement >= 0) {
      setState(() {
        currentIndex -= decrement;
        isKarakterHidden = true;
        isRomajiHidden = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentPage = widget.multiView
        ? (currentIndex ~/ widget.slideCount) + 1
        : currentIndex + 1;
    final totalPages = widget.multiView
        ? ((data.length + widget.slideCount - 1) ~/ widget.slideCount)
        : data.length;

    return Scaffold(
      appBar: AppBar(title: const Text("Hasil Hirakana")),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Jenis: ${widget.jenis.toUpperCase()}",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "Kategori: ${widget.kategori.toUpperCase()}",
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                "$currentPage/$totalPages",
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              widget.multiView
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.slideCount, (index) {
                          int dataIndex = currentIndex + index;
                          if (dataIndex >= data.length) return const SizedBox();
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Column(
                              children: [
                                GestureDetector(
                                  onTapDown: (_) =>
                                      setState(() => isKarakterHidden = false),
                                  onTapUp: (_) =>
                                      setState(() => isKarakterHidden = true),
                                  child: widget.sensorKarakter &&
                                          isKarakterHidden
                                      ? Container(
                                          width: widget.multiView ? 60 : 100,
                                          height: widget.multiView ? 60 : 100,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          data[dataIndex]['karakter'] ?? '-',
                                          style: TextStyle(
                                            fontFamily: 'NotoSansJP',
                                            fontSize:
                                                widget.multiView ? 60 : 100,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTapDown: (_) =>
                                      setState(() => isRomajiHidden = false),
                                  onTapUp: (_) =>
                                      setState(() => isRomajiHidden = true),
                                  child: widget.sensorRomaji && isRomajiHidden
                                      ? Container(
                                          width: 30,
                                          height: 30,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          data[dataIndex]['romaji'] ?? '-',
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    )
                  : Column(
                      children: [
                        GestureDetector(
                          onTapDown: (_) =>
                              setState(() => isKarakterHidden = false),
                          onTapUp: (_) =>
                              setState(() => isKarakterHidden = true),
                          child: widget.sensorKarakter && isKarakterHidden
                              ? Container(
                                  width: widget.multiView ? 60 : 100,
                                  height: widget.multiView ? 60 : 100,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  data[currentIndex]['karakter'] ?? '-',
                                  style: TextStyle(
                                    fontFamily: 'NotoSansJP',
                                    fontSize: widget.multiView ? 60 : 100,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTapDown: (_) =>
                              setState(() => isRomajiHidden = false),
                          onTapUp: (_) => setState(() => isRomajiHidden = true),
                          child: widget.sensorRomaji && isRomajiHidden
                              ? Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  data[currentIndex]['romaji'] ?? '-',
                                  style: const TextStyle(fontSize: 24),
                                ),
                        ),
                      ],
                    ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: currentIndex > 0 ? backCharacter : null,
                    child: const Text("Back"),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: currentIndex <
                            data.length -
                                (widget.multiView ? widget.slideCount : 1)
                        ? nextCharacter
                        : null,
                    child: const Text("Next"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Advanced Feature Widgets

class AdvancedPage extends StatefulWidget {
  const AdvancedPage({super.key});
  @override
  State<AdvancedPage> createState() => _AdvancedPageState();
}

class _AdvancedPageState extends State<AdvancedPage> {
  String? selectedType;
  bool isAcak = false;
  // Opsi tipe sesuai dengan nama tabel di database
  final List<String> advancedTypes = [
    "kanji",
    "vocal",
    "grammar",
    "kanji_freq_use",
    "jlpt_grammar_full"
  ];
  String selectedJLPT = "Semua"; // filter JLPT level
  final List<String> jlptOptions = ["Semua", "N1", "N2", "N3", "N4", "N5"];

  int selectedLimit = 10; // maksimal list view data
  final List<int> limitOptions = [10, 50, 100];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Advanced Feature")),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DropdownButton<String>(
                hint: const Text("Pilih Tipe"),
                value: selectedType,
                items: advancedTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Acak Data"),
                  Switch(
                    value: isAcak,
                    onChanged: (value) {
                      setState(() {
                        isAcak = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Dropdown filter JLPT level
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Filter JLPT Level: "),
                  DropdownButton<String>(
                    value: selectedJLPT,
                    items: jlptOptions.map((level) {
                      return DropdownMenuItem<String>(
                        value: level,
                        child: Text(level),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedJLPT = value!;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Dropdown untuk batas data (limit)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Max Data: "),
                  DropdownButton<int>(
                    value: selectedLimit,
                    items: limitOptions.map((limit) {
                      return DropdownMenuItem<int>(
                        value: limit,
                        child: Text(limit.toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedLimit = value!;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: selectedType != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdvancedResultPage(
                              type: selectedType!,
                              acak: isAcak,
                              jlptLevel: selectedJLPT,
                              limit: selectedLimit,
                            ),
                          ),
                        );
                      }
                    : null,
                child: const Text("Tampilkan Data"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdvancedResultPage extends StatefulWidget {
  final String type;
  final bool acak;
  final String jlptLevel;
  final int limit;
  const AdvancedResultPage({
    super.key,
    required this.type,
    required this.acak,
    required this.jlptLevel,
    required this.limit,
  });

  @override
  State<AdvancedResultPage> createState() => _AdvancedResultPageState();
}

class _AdvancedResultPageState extends State<AdvancedResultPage> {
  List<Map<String, dynamic>> data = [];
  bool isLoading = true;
  int currentPage = 1;
  int totalCount = 0;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  void fetchData() async {
    setState(() {
      isLoading = true;
    });
    try {
      // Ambil total count data terlebih dahulu
      int count = await DatabaseHelper().getCountByType(
        widget.type,
        jlptLevel: widget.jlptLevel,
      );
      setState(() {
        totalCount = count;
        totalPages =
            count == 0 ? 1 : ((count + widget.limit - 1) ~/ widget.limit);
      });

      int offset = (currentPage - 1) * widget.limit;
      var result = await DatabaseHelper().getDataByType(
        widget.type,
        widget.acak,
        jlptLevel: widget.jlptLevel,
        limit: widget.limit,
        offset: offset,
      );
      setState(() {
        data = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Tangani error sesuai kebutuhan
    }
  }

  void nextPage() {
    if (currentPage < totalPages) {
      setState(() {
        currentPage++;
        isLoading = true;
      });
      fetchData();
    }
  }

  void previousPage() {
    if (currentPage > 1) {
      setState(() {
        currentPage--;
        isLoading = true;
      });
      fetchData();
    }
  }

  void showDetailPopup(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(widget.type.toUpperCase()),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: buildDetailContent(widget.type, item),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
          ],
        );
      },
    );
  }

  List<Widget> buildDetailContent(String type, Map<String, dynamic> item) {
    List<Widget> content = [];
    if (type == "kanji" || type == "kanji_freq_use") {
      content.add(Text("Kanji: ${item['kanji'] ?? '-'}"));
      content.add(Text("Onyomi: ${item['onyomi'] ?? '-'}"));
      content.add(Text("Onchar: ${item['onchar'] ?? '-'}"));
      content.add(Text("Kunyomi: ${item['kunyomi'] ?? '-'}"));
      content.add(Text("Kunchar: ${item['kunchar'] ?? '-'}"));
      content.add(Text("Arti (EN): ${item['arti_en'] ?? '-'}"));
      content.add(Text("Arti (ID): ${item['arti_id'] ?? '-'}"));
      content.add(Text("JLPT Level: ${item['jlpt_level'] ?? '-'}"));
    } else if (type == "vocal") {
      content.add(Text("Kanji: ${item['kanji'] ?? '-'}"));
      content.add(Text("Verbal: ${item['verbal'] ?? '-'}"));
      content.add(Text("Verbal (JP): ${item['verbal_j'] ?? '-'}"));
      content.add(Text("Jenis Kata (EN): ${item['jenis_kata_en'] ?? '-'}"));
      content.add(Text("Jenis Kata (ID): ${item['jenis_kata_id'] ?? '-'}"));
      content.add(Text("Arti (EN): ${item['arti_en'] ?? '-'}"));
      content.add(Text("Arti (ID): ${item['arti_id'] ?? '-'}"));
      content.add(Text("JLPT Level: ${item['jlpt_level'] ?? '-'}"));
    } else if (type == "grammar") {
      content.add(Text("Tata Bahasa: ${item['tata_bahasa'] ?? '-'}"));
      content.add(Text("Tata Bahasa (JP): ${item['tata_bahasa_j'] ?? '-'}"));
      content.add(Text("Arti (EN): ${item['arti_en'] ?? '-'}"));
      content.add(Text("Arti (ID): ${item['arti_id'] ?? '-'}"));
      content.add(Text("JLPT Level: ${item['jlpt_level'] ?? '-'}"));
    } else if (type == "jlpt_grammar_full") {
      content.add(Text("Verbal: ${item['vechar'] ?? '-'}"));
      content.add(Text("Verbal (JP): ${item['javchar'] ?? '-'}"));
      content.add(Text("Arti (EN): ${item['arti_en'] ?? '-'}"));
      content.add(Text("Arti (ID): ${item['arti_id'] ?? '-'}"));
      content.add(Text("JLPT Level: ${item['jlpt_level'] ?? '-'}"));
    } else {
      content.add(const Text("Data tidak tersedia"));
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.type.toUpperCase()} - List"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : data.isEmpty
              ? const Center(child: Text("Tidak ada data"))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: data.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          var item = data[index];
                          String title = "";
                          if (widget.type == "kanji" ||
                              widget.type == "kanji_freq_use") {
                            title = item['kanji'] ?? '-';
                          } else if (widget.type == "vocal") {
                            title = item['verbal'] ?? '-';
                          } else if (widget.type == "grammar") {
                            title = item['tata_bahasa'] ?? '-';
                          } else if (widget.type == "jlpt_grammar_full") {
                            title = item['vechar'] ?? '-';
                          }
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(
                                title,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                  "JLPT Level: ${item['jlpt_level'] ?? '-'}"),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () => showDetailPopup(item),
                            ),
                          );
                        },
                      ),
                    ),
                    // Tampilan pagination
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: currentPage > 1 ? previousPage : null,
                            child: const Text("Back"),
                          ),
                          const SizedBox(width: 20),
                          Text("Page $currentPage of $totalPages"),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            onPressed:
                                currentPage < totalPages ? nextPage : null,
                            child: const Text("Next"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
