// Inisialisasi pengambilan library
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum untuk jenis operasi matematika.
enum ArithmeticOperation { addition, subtraction, multiplication, division }

/// Model soal.
class Question {
  final String questionText;
  final num correctAnswer;
  num? userAnswer;
  bool isCorrect;
  double timeTaken;
  bool timedOut; // Menandai kehabisan waktu

  Question({
    required this.questionText,
    required this.correctAnswer,
    this.userAnswer,
    this.isCorrect = false,
    this.timeTaken = 0,
    this.timedOut = false,
  });
}

/// Provider untuk pengaturan aplikasi.
class SettingsProvider extends ChangeNotifier {
  ArithmeticOperation selectedOperation = ArithmeticOperation.addition;
  int questionsPerSession = 10; // 10 atau 20 soal per sesi
  int questionTime = 5; // default: 5 detik
  String keyboardSize = "medium"; // opsi: small, medium, large

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    questionsPerSession = prefs.getInt('questionsPerSession') ?? 10;
    questionTime = prefs.getInt('questionTime') ?? 5;
    keyboardSize = prefs.getString('keyboardSize') ?? "medium";
    int opIndex = prefs.getInt('selectedOperation') ?? 0;
    selectedOperation = ArithmeticOperation.values[opIndex];
    notifyListeners();
  }

  Future<void> saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('questionsPerSession', questionsPerSession);
    await prefs.setInt('questionTime', questionTime);
    await prefs.setString('keyboardSize', keyboardSize);
    await prefs.setInt('selectedOperation', selectedOperation.index);
  }

  void updateQuestionsPerSession(int value) {
    questionsPerSession = value;
    saveSettings();
    notifyListeners();
  }

  void updateQuestionTime(int value) {
    questionTime = value;
    saveSettings();
    notifyListeners();
  }

  void updateKeyboardSize(String size) {
    keyboardSize = size;
    saveSettings();
    notifyListeners();
  }

  void updateSelectedOperation(ArithmeticOperation op) {
    selectedOperation = op;
    saveSettings();
    notifyListeners();
  }
}

/// Provider untuk logika kuis.
class QuizProvider extends ChangeNotifier {
  List<List<Question>> sessions = [];
  int currentSessionIndex = 0;
  int currentQuestionIndex = 0;
  int totalScore = 0;
  late DateTime questionStartTime;
  Timer? timer;
  int remainingTime = 0;
  String currentAnswer = "";
  int totalSessions = 0;

  // Properti untuk menyimpan operasi quiz yang sedang berjalan.
  late ArithmeticOperation currentOperation;

  /// Set global untuk menyimpan soal yang sudah digunakan (unik di seluruh kuis).
  Set<String> globalGeneratedQuestions = {};

  /// Jika kuis belum selesai, maka sesi masih pending.
  bool get hasPendingSession => sessions.isNotEmpty && !isQuizFinished;

  void startNewQuiz(SettingsProvider settings) {
    sessions = [];
    currentSessionIndex = 0;
    currentQuestionIndex = 0;
    totalScore = 0;
    globalGeneratedQuestions = {};
    // Simpan operasi yang digunakan untuk quiz ini.
    currentOperation = settings.selectedOperation;
    totalSessions = (100 / settings.questionsPerSession).ceil();
    for (int i = 0; i < totalSessions; i++) {
      sessions.add(_generateSession(settings));
    }
    notifyListeners();
  }

  List<Question> _generateSession(SettingsProvider settings) {
    List<Question> questions = [];
    Random rnd = Random();
    while (questions.length < settings.questionsPerSession) {
      Question q = _generateQuestion(settings.selectedOperation, rnd);
      if (!globalGeneratedQuestions.contains(q.questionText)) {
        globalGeneratedQuestions.add(q.questionText);
        questions.add(q);
      }
    }
    return questions;
  }

  Question _generateQuestion(ArithmeticOperation op, Random rnd) {
    int a = rnd.nextInt(10) + 1;
    int b = rnd.nextInt(10) + 1;
    String text = "";
    num answer = 0;
    switch (op) {
      case ArithmeticOperation.addition:
        text = "$a + $b";
        answer = a + b;
        break;
      case ArithmeticOperation.subtraction:
        int r = rnd.nextInt(10);
        int s = rnd.nextInt(10) + 1;
        int a = r + s;
        text = "$a - $s";
        answer = r;
        break;
      case ArithmeticOperation.multiplication:
        text = "$a × $b";
        answer = a * b;
        break;
      case ArithmeticOperation.division:
        text = "${a * b} ÷ $b";
        answer = a;
        break;
    }
    return Question(questionText: text, correctAnswer: answer);
  }

  Question get currentQuestion =>
      sessions[currentSessionIndex][currentQuestionIndex];

  void startQuestion(SettingsProvider settings) {
    currentAnswer = "";
    remainingTime = settings.questionTime;
    questionStartTime = DateTime.now();
    timer?.cancel();
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      remainingTime--;
      if (remainingTime <= 0) {
        submitAnswer(timeout: true, settings: settings);
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void addDigit(String digit) {
    currentAnswer += digit;
    notifyListeners();
  }

  void deleteDigit() {
    if (currentAnswer.isNotEmpty) {
      currentAnswer = currentAnswer.substring(0, currentAnswer.length - 1);
      notifyListeners();
    }
  }

  void submitAnswer(
      {bool timeout = false, required SettingsProvider settings}) {
    timer?.cancel();
    double timeTaken = settings.questionTime - remainingTime.toDouble();
    Question q = currentQuestion;
    q.timeTaken = timeTaken;
    if (!timeout && currentAnswer.isNotEmpty) {
      q.userAnswer = num.tryParse(currentAnswer) ?? 0;
      q.isCorrect = (q.userAnswer == q.correctAnswer);
      if (q.isCorrect) totalScore++;
    } else {
      q.userAnswer = num.tryParse(currentAnswer) ?? 0;
      q.isCorrect = false;
      if (timeout) q.timedOut = true;
    }
    if (currentQuestionIndex < sessions[currentSessionIndex].length - 1) {
      currentQuestionIndex++;
      startQuestion(settings);
    } else {
      timer?.cancel();
      remainingTime = 0;
      notifyListeners();
    }
  }

  double get currentSessionAverageTime {
    List<Question> qs = sessions[currentSessionIndex];
    if (qs.isEmpty) return 0;
    double total = qs.fold(0, (prev, q) => prev + q.timeTaken);
    return total / qs.length;
  }

  double get overallAverageTime {
    List<Question> all = sessions.expand((s) => s).toList();
    if (all.isEmpty) return 0;
    double total = all.fold(0, (prev, q) => prev + q.timeTaken);
    return total / all.length;
  }

  void nextSession(SettingsProvider settings) {
    if (currentSessionIndex < sessions.length - 1) {
      currentSessionIndex++;
      currentQuestionIndex = 0;
      startQuestion(settings);
    }
    notifyListeners();
  }

  void restartSession(SettingsProvider settings) {
    for (var q in sessions[currentSessionIndex]) {
      globalGeneratedQuestions.remove(q.questionText);
    }
    sessions[currentSessionIndex] = _generateSession(settings);
    currentQuestionIndex = 0;
    startQuestion(settings);
    notifyListeners();
  }

  void resetQuiz() {
    sessions = [];
    currentSessionIndex = 0;
    currentQuestionIndex = 0;
    totalScore = 0;
    globalGeneratedQuestions = {};
    timer?.cancel();
    notifyListeners();
  }

  bool get isQuizFinished {
    return sessions.isNotEmpty &&
        (currentSessionIndex == sessions.length - 1) &&
        (currentQuestionIndex == sessions[currentSessionIndex].length - 1) &&
        (remainingTime == 0);
  }
}

/// Model rekor.
class Record {
  final int topScore;
  final double bestAverageTime;
  Record({required this.topScore, required this.bestAverageTime});
}

/// Provider untuk menyimpan dan memperbarui rekor.
class RecordProvider extends ChangeNotifier {
  Map<ArithmeticOperation, Record> records = {};

  RecordProvider() {
    loadRecords();
  }

  Future<void> loadRecords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    for (var op in ArithmeticOperation.values) {
      String opKey = _opToKey(op);
      int score = prefs.getInt('record_${opKey}_score') ?? 0;
      double time = prefs.getDouble('record_${opKey}_time') ?? double.infinity;
      records[op] = Record(topScore: score, bestAverageTime: time);
    }
    notifyListeners();
  }

  Future<bool> updateRecord(
      ArithmeticOperation op, int newScore, double newAvgTime) async {
    Record? current = records[op];
    bool isUpdated = false;
    if (current == null ||
        newScore > current.topScore ||
        (newScore == current.topScore &&
            newAvgTime < current.bestAverageTime)) {
      records[op] = Record(topScore: newScore, bestAverageTime: newAvgTime);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String opKey = _opToKey(op);
      await prefs.setInt('record_${opKey}_score', newScore);
      await prefs.setDouble('record_${opKey}_time', newAvgTime);
      isUpdated = true;
      notifyListeners();
    }
    return isUpdated;
  }

  String _opToKey(ArithmeticOperation op) {
    switch (op) {
      case ArithmeticOperation.addition:
        return "addition";
      case ArithmeticOperation.subtraction:
        return "subtraction";
      case ArithmeticOperation.multiplication:
        return "multiplication";
      case ArithmeticOperation.division:
        return "division";
    }
  }
}

/// Widget MainPage dengan Bottom Navigation untuk Beranda dan Rekor.
class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    RecordScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Beranda"),
          BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events), label: "Rekor"),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

/// Halaman Utama (Home Screen)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Awalnya controller di-set dengan nilai default (5 detik)
    // karena loadSettings() berjalan secara asinkron.
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    timeController.text = settings.questionTime.toString();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Perbaikan bug: Sinkronkan nilai TextEditingController dengan nilai yang terbaru dari SettingsProvider.
    final settings = Provider.of<SettingsProvider>(context);
    if (timeController.text != settings.questionTime.toString()) {
      timeController.text = settings.questionTime.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final quiz = Provider.of<QuizProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Math Speed Up"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pilih Operasi Matematika:",
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            DropdownButton<ArithmeticOperation>(
              value: settings.selectedOperation,
              items: ArithmeticOperation.values.map((op) {
                String text = "";
                switch (op) {
                  case ArithmeticOperation.addition:
                    text = "Penjumlahan";
                    break;
                  case ArithmeticOperation.subtraction:
                    text = "Pengurangan";
                    break;
                  case ArithmeticOperation.multiplication:
                    text = "Perkalian";
                    break;
                  case ArithmeticOperation.division:
                    text = "Pembagian";
                    break;
                }
                return DropdownMenuItem(
                  value: op,
                  child: Text(text),
                );
              }).toList(),
              onChanged: (newOp) {
                if (newOp != null) {
                  QuizProvider quiz =
                      Provider.of<QuizProvider>(context, listen: false);
                  if (quiz.hasPendingSession &&
                      quiz.currentOperation != newOp) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Lanjutkan Quiz?"),
                        content: Text(
                          "Anda telah memulai quiz dengan operasi ${_opToString(quiz.currentOperation)}. "
                          "Apakah Anda ingin melanjutkan quiz tersebut atau memulai ulang dengan operasi baru?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Provider.of<SettingsProvider>(context,
                                      listen: false)
                                  .updateSelectedOperation(
                                      quiz.currentOperation);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const QuizScreen()),
                              );
                            },
                            child: const Text("Lanjutkan"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Provider.of<SettingsProvider>(context,
                                      listen: false)
                                  .updateSelectedOperation(newOp);
                              quiz.resetQuiz();
                              quiz.startNewQuiz(Provider.of<SettingsProvider>(
                                  context,
                                  listen: false));
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const QuizScreen()),
                              );
                            },
                            child: const Text("Ulang dari awal"),
                          ),
                        ],
                      ),
                    );
                  } else {
                    Provider.of<SettingsProvider>(context, listen: false)
                        .updateSelectedOperation(newOp);
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            const Text("Jumlah Soal per Sesi:", style: TextStyle(fontSize: 18)),
            Row(
              children: [
                Radio<int>(
                  value: 10,
                  groupValue: settings.questionsPerSession,
                  onChanged: (val) {
                    if (val != null) settings.updateQuestionsPerSession(val);
                  },
                ),
                const Text("10 Soal"),
                Radio<int>(
                  value: 20,
                  groupValue: settings.questionsPerSession,
                  onChanged: (val) {
                    if (val != null) settings.updateQuestionsPerSession(val);
                  },
                ),
                const Text("20 Soal"),
              ],
            ),
            const SizedBox(height: 16),
            const Text("Waktu per Soal (detik):",
                style: TextStyle(fontSize: 18)),
            TextField(
              controller: timeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Masukkan waktu (detik)",
              ),
              onChanged: (value) {
                int? time = int.tryParse(value);
                if (time != null && time > 0) settings.updateQuestionTime(time);
              },
            ),
            const SizedBox(height: 16),
            const Text("Ukuran Keyboard PIN:", style: TextStyle(fontSize: 18)),
            DropdownButton<String>(
              value: settings.keyboardSize,
              items: ["small", "medium", "large"].map((size) {
                return DropdownMenuItem(
                  value: size,
                  child: Text(size.toUpperCase()),
                );
              }).toList(),
              onChanged: (size) {
                if (size != null) settings.updateKeyboardSize(size);
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (quiz.hasPendingSession) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Lanjutkan Quiz?"),
                        content: Text(
                            "Anda sudah menyelesaikan ${quiz.currentSessionIndex} sesi dan sedang mengerjakan sesi ${quiz.currentSessionIndex + 1} dari ${quiz.sessions.length}."),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const QuizScreen()),
                              );
                            },
                            child: const Text("Lanjutkan"),
                          ),
                          TextButton(
                            onPressed: () {
                              quiz.resetQuiz();
                              quiz.startNewQuiz(settings);
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const QuizScreen()),
                              );
                            },
                            child: const Text("Ulang dari awal"),
                          ),
                        ],
                      ),
                    );
                  } else {
                    quiz.resetQuiz();
                    quiz.startNewQuiz(settings);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizScreen()),
                    );
                  }
                },
                child: const Text("Mulai Quiz"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _opToString(ArithmeticOperation op) {
  switch (op) {
    case ArithmeticOperation.addition:
      return "Penjumlahan";
    case ArithmeticOperation.subtraction:
      return "Pengurangan";
    case ArithmeticOperation.multiplication:
      return "Perkalian";
    case ArithmeticOperation.division:
      return "Pembagian";
    default:
      return "";
  }
}

/// Halaman Quiz (Question Screen)
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool navigated = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    Future.microtask(() {
      Provider.of<QuizProvider>(context, listen: false).startQuestion(settings);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Consumer<QuizProvider>(
      builder: (context, quiz, child) {
        if (quiz.currentQuestionIndex ==
                quiz.sessions[quiz.currentSessionIndex].length - 1 &&
            quiz.remainingTime == 0 &&
            !navigated) {
          navigated = true;
          Future.microtask(() {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SessionResultScreen()),
            );
          });
        }
        if (quiz.isQuizFinished && !navigated) {
          navigated = true;
          Future.microtask(() {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const FinalResultScreen()),
            );
          });
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(
                "Sesi ${quiz.currentSessionIndex + 1} dari ${quiz.sessions.length} - Soal ${quiz.currentQuestionIndex + 1} dari ${quiz.sessions[quiz.currentSessionIndex].length}"),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  "Waktu tersisa: ${quiz.remainingTime} detik",
                  style: TextStyle(
                    fontSize: 20,
                    color: quiz.remainingTime <= 3
                        ? Colors.red
                        : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: Text(
                      quiz.currentQuestion.questionText,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Text(
                  quiz.currentAnswer,
                  style: const TextStyle(fontSize: 32, color: Colors.blue),
                ),
                const SizedBox(height: 16),
                Keypad(keyboardSize: settings.keyboardSize),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Widget Keyboard PIN dengan tata letak yang disempurnakan.
class Keypad extends StatelessWidget {
  final String keyboardSize;
  const Keypad({super.key, required this.keyboardSize});

  double _getButtonSize() {
    switch (keyboardSize) {
      case "small":
        return 50;
      case "large":
        return 70;
      case "medium":
      default:
        return 60;
    }
  }

  @override
  Widget build(BuildContext context) {
    double buttonSize = _getButtonSize();
    double spacing = 8;

    Widget buildButton(String text, {VoidCallback? onPressed, IconData? icon}) {
      return SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            alignment: Alignment.center,
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          child: icon != null
              ? Icon(icon, size: buttonSize / 2)
              : Text(text, style: TextStyle(fontSize: buttonSize / 2.5)),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildButton("1", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("1");
            }),
            buildButton("2", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("2");
            }),
            buildButton("3", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("3");
            }),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildButton("4", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("4");
            }),
            buildButton("5", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("5");
            }),
            buildButton("6", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("6");
            }),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildButton("7", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("7");
            }),
            buildButton("8", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("8");
            }),
            buildButton("9", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("9");
            }),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            buildButton("", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).deleteDigit();
            }, icon: Icons.backspace),
            buildButton("0", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).addDigit("0");
            }),
            buildButton("", onPressed: () {
              Provider.of<QuizProvider>(context, listen: false).submitAnswer(
                settings: Provider.of<SettingsProvider>(context, listen: false),
              );
            }, icon: Icons.check),
          ],
        ),
      ],
    );
  }
}

/// Halaman Hasil Sesi.
class SessionResultScreen extends StatelessWidget {
  const SessionResultScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final quiz = Provider.of<QuizProvider>(context);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    List<Question> currentSession = quiz.sessions[quiz.currentSessionIndex];
    int correctCount = currentSession.where((q) => q.isCorrect).length;
    int sessionScore = ((correctCount * 100) / currentSession.length).round();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hasil Sesi"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Skor Sesi: $sessionScore",
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              "Rata-rata Waktu: ${quiz.currentSessionAverageTime.toStringAsFixed(2)} detik per soal",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            const Text("Riwayat Soal:", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: currentSession.length,
                itemBuilder: (context, index) {
                  Question q = currentSession[index];
                  return ListTile(
                    title: Text(q.questionText),
                    subtitle: Text(
                        "Jawaban Anda: ${q.timedOut ? 'Kehabisan waktu' : q.userAnswer.toString()} | Jawaban Benar: ${q.correctAnswer}"),
                    trailing: Icon(
                      q.isCorrect ? Icons.check_circle : Icons.cancel,
                      color: q.isCorrect ? Colors.green : Colors.red,
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    quiz.restartSession(settings);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizScreen()),
                    );
                  },
                  child: const Text("Ulang"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (quiz.currentSessionIndex < quiz.sessions.length - 1) {
                      quiz.nextSession(settings);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const QuizScreen()),
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FinalResultScreen()),
                      );
                    }
                  },
                  child: const Text("Lanjut"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Halaman Hasil Akhir dengan pengecekan rekor.
class FinalResultScreen extends StatefulWidget {
  const FinalResultScreen({super.key});
  @override
  State<FinalResultScreen> createState() => _FinalResultScreenState();
}

class _FinalResultScreenState extends State<FinalResultScreen> {
  bool newRecordAchieved = false;
  bool recordChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final quiz = Provider.of<QuizProvider>(context, listen: false);
      final recordProvider =
          Provider.of<RecordProvider>(context, listen: false);
      bool updated = await recordProvider.updateRecord(
          quiz.currentOperation, quiz.totalScore, quiz.overallAverageTime);
      setState(() {
        newRecordAchieved = updated;
        recordChecked = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final quiz = Provider.of<QuizProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hasil Akhir"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (recordChecked && newRecordAchieved)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  "Selamat, anda melampaui rekor sebelumnya!",
                  style: TextStyle(fontSize: 20, color: Colors.green),
                ),
              ),
            Text(
              "Nilai Akhir: ${quiz.totalScore}",
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 16),
            Text(
              "Rata-rata Waktu Keseluruhan: ${quiz.overallAverageTime.toStringAsFixed(2)} detik",
              style: const TextStyle(fontSize: 20),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                quiz.resetQuiz();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainPage()),
                  (route) => false,
                );
              },
              child: const Text("Main Lagi"),
            ),
          ],
        ),
      ),
    );
  }
}

/// Halaman Rekor yang menampilkan rekor untuk tiap operasi.
class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final recordProvider = Provider.of<RecordProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Rekor")),
      body: ListView(
        children: ArithmeticOperation.values.map((op) {
          String opName;
          switch (op) {
            case ArithmeticOperation.addition:
              opName = "Penjumlahan";
              break;
            case ArithmeticOperation.subtraction:
              opName = "Pengurangan";
              break;
            case ArithmeticOperation.multiplication:
              opName = "Perkalian";
              break;
            case ArithmeticOperation.division:
              opName = "Pembagian";
              break;
          }
          Record? rec = recordProvider.records[op];
          String scoreText = rec != null ? rec.topScore.toString() : "0";
          String timeText =
              rec != null && rec.bestAverageTime != double.infinity
                  ? rec.bestAverageTime.toStringAsFixed(2)
                  : "-";
          return ListTile(
            title: Text(opName),
            subtitle: Text(
                "Top Nilai: $scoreText, Waktu Rata-rata Terbaik: $timeText detik"),
          );
        }).toList(),
      ),
    );
  }
}

class MathApp extends StatelessWidget {
  const MathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body:
          MainPage(), // Ganti MainPage() dengan HomePage() jika memang ini yang diinginkan
    );
  }
}
