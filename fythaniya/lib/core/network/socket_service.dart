import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/core/network/api_client.dart';
import 'package:fythaniya/core/notifications/notification_service.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();
  io.Socket? _socket;
  bool _connected = false;

  final ValueNotifier<Map<String,dynamic>?> requestUpdate = ValueNotifier(null);
  final ValueNotifier<Map<String,dynamic>?> newNotification = ValueNotifier(null);

  static const _statusLabels = {
    'ASSIGNED':    ('👤 تم استلام طلبك', 'تم تعيين موظف لمعالجة طلبك'),
    'IN_PROGRESS': ('⏳ جارٍ التنفيذ',     'بدأ معالج المعاملات بتنفيذ طلبك'),
    'COMPLETED':   ('✅ تم تنفيذ الطلب',  'تم إتمام طلبك بنجاح'),
    'FAILED':      ('❌ فشل الطلب',       'لم يتم تنفيذ الطلب'),
    'REFUNDED':    ('💰 تم الاسترداد',    'تم استرداد المبلغ إلى محفظتك'),
  };

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

    void notifyForStatus(String status, Map<String,dynamic> data) {
      final lbl = _statusLabels[status];
      if (lbl == null) return;
      NotificationService.instance.show(
        title: lbl.$1,
        body: lbl.$2,
        payload: data['requestId']?.toString(),
      );
    }

    _socket!.on('request_completed', (data) {
      final m = Map<String,dynamic>.from(data as Map);
      requestUpdate.value = {'status': 'COMPLETED', ...m};
      notifyForStatus('COMPLETED', m);
    });

    _socket!.on('request_failed', (data) {
      final m = Map<String,dynamic>.from(data as Map);
      requestUpdate.value = {'status': 'FAILED', ...m};
      notifyForStatus('FAILED', m);
    });

    _socket!.on('request_updated', (data) {
      final m = Map<String,dynamic>.from(data as Map);
      requestUpdate.value = m;
      notifyForStatus(m['status']?.toString() ?? '', m);
    });

    _socket!.on('new_notification', (data) {
      final m = Map<String,dynamic>.from(data as Map);
      newNotification.value = m;
      NotificationService.instance.show(
        title: m['title']?.toString() ?? 'إشعار',
        body: m['body']?.toString() ?? '',
        payload: m['requestId']?.toString(),
      );
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _connected = false;
  }

  bool get isConnected => _connected;
}
