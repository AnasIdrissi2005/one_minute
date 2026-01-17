String todayKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return "$y-$m-$day";
}

enum MinuteMode {
  thinking,
  breathing,
  reading,
  writing,
  silence,
  phoneFree,
}

extension MinuteModeLabel on MinuteMode {
  String get label {
    switch (this) {
      case MinuteMode.thinking:
        return "Thinking";
      case MinuteMode.breathing:
        return "Breathing";
      case MinuteMode.reading:
        return "Reading";
      case MinuteMode.writing:
        return "Writing";
      case MinuteMode.silence:
        return "Silence";
      case MinuteMode.phoneFree:
        return "Phone-free minute";
    }
  }
}
