import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/core/network/api_client.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();
  io.Socket? _socket;
  bool _connected = false;

  final ValueNotifier<Map<String,dynamic>?> requestUpdate = ValueNotifier(null);
  final ValueNotifier<Map<String,dynamic>?> newNotification = ValueNotifier(null);

  Future<void> connect() async {
    if (_connected) return;
    final token = await ApiClient.instance.getToken();
    if (token == null) return;

    _socket = io.io(AppConstants.socketUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .enableAutoConnect()
      .enableReconnection()
      .setReconnectionAttempts(10)
      .setReconnectionDelay(2000)
      .build());

    _socket!.onConnect((_) {
      _connected = true;
      debugPrint('[SOCKET] Connected');
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      debugPrint('[SOCKET] Disconnected');
    });

    // Listen for request status updates
    _socket!.on('request_completed', (data) {
      requestUpdate.value = {'status': 'COMPLETED', ...Map<String,dynamic>.from(data as Map)};
    });

    _socket!.on('request_failed', (data) {
      requestUpdate.value = {'status': 'FAILED', ...Map<String,dynamic>.from(data as Map)};
    });

    _socket!.on('new_notification', (data) {
      newNotification.value = Map<String,dynamic>.from(data as Map);
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _connected = false;
  }

  bool get isConnected => _connected;
}
