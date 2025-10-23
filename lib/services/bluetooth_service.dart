import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Bluetooth üzerinden veri gönderme ve alma işlevlerini yöneten servis.
/// AppState bu sınıfı kullanarak tüm bağlantı kontrolünü yapar.
class BluetoothService {
  BluetoothConnection? _connection;
  final StreamController<String> _lineController = StreamController.broadcast();

  bool get isConnected => _connection?.isConnected ?? false;

  /// Dışa açık satır bazlı veri akışı (AppState bu Stream'i dinler)
  Stream<String> get lines => _lineController.stream;

  /// Belirtilen adrese bağlanır.
  Future<void> connectTo(String address) async {
    await disconnect();

    try {
      _connection = await BluetoothConnection.toAddress(address);
      _lineController.add('[INFO] $address adresine bağlanıldı');

      // Gelen veriyi dinle
      _connection!.input!.transform(
        StreamTransformer<Uint8List, String>.fromHandlers(
          handleData: (Uint8List data, EventSink<String> sink) {
            // Uint8List'i List<int> olarak UTF-8 decoder'a gönder
            sink.add(utf8.decode(data));
          },
        ),
      ).listen((data) {
        for (var line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            _lineController.add(line.trim());
          }
        }
      }, onDone: () {
        _lineController.add('[INFO] Bağlantı sonlandırıldı');
        disconnect();
      }, onError: (error) {
        _lineController.add('[ERROR] Veri akışı hatası: $error');
      });
    } catch (e) {
      _lineController.add('[ERROR] Bağlantı kurulamadı: $e');
      rethrow;
    }
  }

  /// Bluetooth bağlantısını sonlandırır.
  Future<void> disconnect() async {
    if (_connection != null) {
      try {
        await _connection!.finish();
      } catch (_) {}
      _connection = null;
      _lineController.add('[INFO] Bağlantı kesildi');
    }
  }

  /// Bluetooth üzerinden komut gönderir.
  void send(String data) {
    if (_connection?.isConnected ?? false) {
      _connection!.output.add(utf8.encode('$data\n'));
      _connection!.output.allSent;
    } else {
      _lineController.add('[WARN] Komut gönderilemedi (bağlantı yok): $data');
    }
  }

  /// Servisi temizle (uygulama kapanırken çağrılır)
  void dispose() {
    disconnect();
    _lineController.close();
  }
}
