import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  BluetoothConnection? _connection;
  final StreamController<String> _lineController = StreamController.broadcast();
  Timer? _heartbeatTimer;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  final int maxReconnectAttempts = 3;
  String? _currentAddress;

  bool get isConnected => _connection?.isConnected ?? false;

  Future<void> connectTo(String address) async {
    await disconnect();

    try {
      _connection = await BluetoothConnection.toAddress(address);
      _currentAddress = address; // Adresi kaydet
      _lineController.add('[INFO] $address adresine bağlanıldı');

      // Bağlantı başarılı, reconnect counter'ı sıfırla
      _reconnectAttempts = 0;
      _isReconnecting = false;

      // Heartbeat başlat
      _startHeartbeat();

      // Gelen veriyi dinle
      _connection!.input!.listen(
            (Uint8List data) {
          String decoded = utf8.decode(data);
          for (var line in decoded.split('\n')) {
            if (line.trim().isNotEmpty) {
              _lineController.add(line.trim());
            }
          }
        },
        onDone: () {
          _lineController.add('[INFO] Bağlantı sonlandırıldı');
          _handleDisconnection();
        },
        onError: (error) {
          _lineController.add('[ERROR] Veri akışı hatası: $error');
          _handleDisconnection();
        },
      );
    } catch (e) {
      _lineController.add('[ERROR] Bağlantı kurulamadı: $e');
      _handleDisconnection();
      rethrow;
    }
  }

  void _handleDisconnection() {
    _stopHeartbeat();

    if (!_isReconnecting && _reconnectAttempts < maxReconnectAttempts && _currentAddress != null) {
      _reconnectAttempts++;
      _isReconnecting = true;

      _lineController.add('[INFO] Yeniden bağlanılıyor... (Deneme $_reconnectAttempts/$maxReconnectAttempts)');

      Future.delayed(Duration(seconds: 2 * _reconnectAttempts), () {
        if (!isConnected && _currentAddress != null) {
          connectTo(_currentAddress!).catchError((e) {
            _lineController.add('[ERROR] Yeniden bağlanma başarısız: $e');
            _isReconnecting = false;
          });
        }
      });
    } else {
      _lineController.add('[ERROR] Maksimum yeniden bağlanma denemesi aşıldı');
      _isReconnecting = false;
      _currentAddress = null;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (isConnected) {
        try {
          send('PING'); // Cihaza ping gönder
        } catch (e) {
          _lineController.add('[WARN] Heartbeat gönderilemedi: $e');
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> disconnect() async {
    _stopHeartbeat();
    _isReconnecting = false;
    _currentAddress = null;

    if (_connection != null) {
      try {
        await _connection!.finish();
      } catch (e) {
        _lineController.add('[WARN] Bağlantı kapatılırken hata: $e');
      }
      _connection = null;
      _lineController.add('[INFO] Bağlantı kesildi');
    }
  }

  void send(String data) {
    if (_connection?.isConnected ?? false) {
      try {
        _connection!.output.add(utf8.encode('$data\n'));
        _connection!.output.allSent;
      } catch (e) {
        _lineController.add('[ERROR] Veri gönderilemedi: $e');
        _handleDisconnection();
      }
    } else {
      _lineController.add('[WARN] Komut gönderilemedi (bağlantı yok): $data');
    }
  }

  Stream<String> get lines => _lineController.stream;

  void dispose() {
    _stopHeartbeat();
    disconnect();
    _lineController.close();
  }
}