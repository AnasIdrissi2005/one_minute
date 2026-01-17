import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:one_minute/domain.dart';
import 'package:one_minute/storage.dart';
import 'package:one_minute/lock_task.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OneMinuteApp());
}

class OneMinuteApp extends StatelessWidget {
  const OneMinuteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "One Minute",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0B0D),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF121217),
          primary: Color(0xFFE6E6E6),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(color: Color(0xFFBDBDBD)),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

enum SessionState { idle, running, completed, failed, lockedToday }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _store = LocalStore();

  SessionState _state = SessionState.idle;
  MinuteMode _mode = MinuteMode.silence;

  Timer? _timer;
  int _remaining = 60;
  int _durationSeconds = 60;

  String _today = "";
  String? _lastCompletedDay;
  int _completedCount = 0;

  bool _sessionFinalized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    _today = todayKey(DateTime.now());
    _durationSeconds = await _store.getDurationSeconds();
    _lastCompletedDay = await _store.getLastCompletedDay();
    _completedCount = await _store.getCompletedCount();

    if (!mounted) return;
    setState(() {
      _state = (_lastCompletedDay == _today)
          ? SessionState.lockedToday
          : SessionState.idle;
      if (_state == SessionState.idle) _sessionFinalized = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_state == SessionState.running &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.detached)) {
      _failSession();
    }
  }

  // ===================== DURATION PICKER =====================

  Future<void> _pickDuration() async {
    if (_state != SessionState.idle) return;

    int h = _durationSeconds ~/ 3600;
    int m = (_durationSeconds % 3600) ~/ 60;
    int s = _durationSeconds % 60;

    final res = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: const Color(0xFF121217),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Duration",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _numPicker("h", h, 0, 12, (v) => h = v)),
                const SizedBox(width: 8),
                Expanded(child: _numPicker("m", m, 0, 59, (v) => m = v)),
                const SizedBox(width: 8),
                Expanded(child: _numPicker("s", s, 0, 59, (v) => s = v)),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, [h, m, s]),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6E6E6),
                  foregroundColor: const Color(0xFF0B0B0D),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("Set"),
              ),
            ),
          ],
        ),
      ),
    );

    if (res == null) return;

    final total = res[0] * 3600 + res[1] * 60 + res[2];
    if (total < 10) return;

    if (!mounted) return;
    setState(() => _durationSeconds = total);
    await _store.setDurationSeconds(total);
  }

  Widget _numPicker(
    String label,
    int initialValue,
    int min,
    int max,
    void Function(int) onChanged,
  ) {
    int v = initialValue;

    return StatefulBuilder(
      builder: (_, setLocal) {
        void dec() {
          if (v <= min) return;
          setLocal(() => v--);
          onChanged(v);
        }

        void inc() {
          if (v >= max) return;
          setLocal(() => v++);
          onChanged(v);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFFBDBDBD))),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 34, height: 34),
                  onPressed: v > min ? dec : null,
                  icon: const Icon(Icons.remove, size: 18),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    v.toString().padLeft(2, '0'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 34, height: 34),
                  onPressed: v < max ? inc : null,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ===================== SESSION =====================

  Future<void> _startSession() async {
    if (_state != SessionState.idle || _sessionFinalized) return;

    setState(() {
      _state = SessionState.running;
      _remaining = _durationSeconds;
    });

    await LockTask.start();
    HapticFeedback.selectionClick();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;

      setState(() => _remaining--);

      if (_remaining <= 0) {
        _timer?.cancel();
        await _completeSession();
      }
    });
  }

  Future<void> _completeSession() async {
    if (_sessionFinalized) return;
    _sessionFinalized = true;

    await _store.saveCompletedDay(dayKey: _today, modeIndex: _mode.index);
    _completedCount = await _store.getCompletedCount();
    await LockTask.stop();

    if (!mounted) return;
    setState(() => _state = SessionState.completed);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _state = SessionState.lockedToday);
    });
  }

  Future<void> _failSession() async {
    if (_sessionFinalized) return;
    _sessionFinalized = true;

    _timer?.cancel();
    await LockTask.stop();

    if (!mounted) return;
    setState(() => _state = SessionState.failed);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _state = SessionState.lockedToday);
    });
  }

  // ===================== UI =====================

  Widget _durationTile() {
    String fmt(int s) => s >= 3600
        ? "${s ~/ 3600}h ${(s % 3600) ~/ 60}m"
        : s >= 60
            ? "${s ~/ 60}m ${s % 60}s"
            : "${s}s";

    return InkWell(
      onTap: _state == SessionState.idle ? _pickDuration : null,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF121217),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 18),
            const SizedBox(width: 10),
            const Text("Duration"),
            const Spacer(),
            Text(
              fmt(_durationSeconds),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _state != SessionState.running,
      child: Scaffold(
        body: AbsorbPointer(
          absorbing: _state == SessionState.running,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    "One Minute",
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 22),
                  _durationTile(),
                  const SizedBox(height: 14),
                  _timerView(),
                  const SizedBox(height: 14),
                  _primaryButton(),
                  const Spacer(),
                  Opacity(
                    opacity: 0.5,
                    child: Text(
                      "Completed days: $_completedCount",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timerView() => _state != SessionState.running
      ? const SizedBox(height: 56)
      : Center(
          child: Text(
            "$_remaining s",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        );

  Widget _primaryButton() => SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: _state == SessionState.idle ? _startSession : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE6E6E6),
            foregroundColor: const Color(0xFF0B0B0D),
            disabledBackgroundColor: const Color(0xFF2A2A30),
            disabledForegroundColor: const Color(0xFF8A8A8A),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            _state == SessionState.idle
                ? "Start"
                : _state == SessionState.running
                    ? "Locked"
                    : "Closed",
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
}
