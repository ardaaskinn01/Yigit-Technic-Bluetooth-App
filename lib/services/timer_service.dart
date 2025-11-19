import 'dart:async';

class TimerService {
  // Timer'ları isimlerine göre saklayan harita
  final Map<String, Timer> _timers = {};

  /// Belirtilen isimde periyodik bir timer başlatır.
  /// Eğer aynı isimde bir timer varsa, önce eskisi iptal edilir.
  void startPeriodic(String name, Duration duration, void Function(Timer) callback) {
    cancel(name); // Çakışmayı önlemek için önce iptal et
    _timers[name] = Timer.periodic(duration, callback);
  }

  /// Belirtilen isimde tek seferlik (timeout) bir timer başlatır.
  void startTimeout(String name, Duration duration, void Function() callback) {
    cancel(name);
    _timers[name] = Timer(duration, () {
      callback();
      _timers.remove(name); // İş bitince listeden sil
    });
  }

  /// Belirli bir timer'ı iptal eder.
  void cancel(String name) {
    if (_timers.containsKey(name)) {
      _timers[name]?.cancel();
      _timers.remove(name);
    }
  }

  /// Belirli bir timer çalışıyor mu kontrol eder.
  bool isActive(String name) {
    return _timers.containsKey(name) && (_timers[name]?.isActive ?? false);
  }

  /// Tüm timer'ları iptal eder ve listeyi temizler.
  void cancelAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}