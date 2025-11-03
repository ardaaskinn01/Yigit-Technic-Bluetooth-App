import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  BluetoothConnection? _connection;
  final StreamController<String> _lineController = StreamController.broadcast();
  final StreamController<bool> _connectionController = StreamController.broadcast();
  final StreamController<String> _dataController = StreamController.broadcast();

  Timer? _heartbeatTimer;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  final int maxReconnectAttempts = 3;
  String? _currentAddress;

  // Yeni eklenen getter'lar
  bool get isConnected => _connection?.isConnected ?? false;
  Stream<bool> get onConnectionChanged => _connectionController.stream;
  Stream<String> get onDataReceived => _dataController.stream;
  Stream<String> get lines => _lineController.stream;

  // Yeni eklenen metodlar
  Future<void> initialize() async {
    // Bluetooth'u başlat - gerekli izinleri kontrol et
    try {
      bool? enabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (!enabled!) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }
      _lineController.add('[INFO] Bluetooth başlatıldı');
    } catch (e) {
      _lineController.add('[ERROR] Bluetooth başlatılamadı: $e');
      rethrow;
    }
  }

  Future<List<BluetoothDevice>> scanDevices() async {
    List<BluetoothDevice> devices = [];
    try {
      _lineController.add('[INFO] Cihazlar taranıyor...');

      List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      devices.addAll(bondedDevices);

      // Ayrıca discovery de yapabiliriz
      final subscription = FlutterBluetoothSerial.instance.startDiscovery().listen((device) {
        if (!devices.any((d) => d.address == device.device.address)) {
          devices.add(device.device);
        }
      });

      await Future.delayed(Duration(seconds: 5));
      await subscription.cancel();

      _lineController.add('[INFO] ${devices.length} cihaz bulundu');
    } catch (e) {
      _lineController.add('[ERROR] Tarama hatası: $e');
    }

    return devices;
  }

  Future<void> connect(BluetoothDevice device) async {
    await connectTo(device.address);
  }

  Future<void> connectTo(String address) async {
    await disconnect();

    try {
      _connection = await BluetoothConnection.toAddress(address);
      _currentAddress = address;
      _lineController.add('[INFO] $address adresine bağlanıldı');
      _connectionController.add(true);

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
              _dataController.add(line.trim());
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
    _connectionController.add(false);

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
      _connectionController.add(false);
      _lineController.add('[INFO] Bağlantı kesildi');
    }
  }

  void send(String data) {
    if (_connection?.isConnected ?? false) {
      try {
        _connection!.output.add(utf8.encode('$data\n'));
        _connection!.output.allSent;
        _lineController.add('[SENT] $data');
      } catch (e) {
        _lineController.add('[ERROR] Veri gönderilemedi: $e');
        _handleDisconnection();
      }
    } else {
      _lineController.add('[WARN] Komut gönderilemedi (bağlantı yok): $data');
    }
  }

  // Yeni eklenen metod - sendCommand için alias
  void sendCommand(String command) {
    send(command);
  }

  void dispose() {
    _stopHeartbeat();
    disconnect();
    _lineController.close();
    _connectionController.close();
    _dataController.close();
  }
}