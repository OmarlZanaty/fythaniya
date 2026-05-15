import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fythaniya/core/network/api_client.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  try { await Firebase.initializeApp(); } catch (_) {}
  debugPrint('[FCM-BG] ${message.notification?.title}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _firebaseReady = false;

  static const _channelId = 'fythaniya_high';
  static const _channelName = 'تنبيهات فى ثانية';
  static const _channelDesc = 'إشعارات الطلبات والمعاملات';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    } catch (e) {
      debugPrint('[NOTIF] Firebase init failed (no google-services.json?): $e');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        debugPrint('[NOTIF] tapped: ${resp.payload}');
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId, _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _requestPermissions();

    if (_firebaseReady) {
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
      await _registerFcmToken();
      FirebaseMessaging.instance.onTokenRefresh.listen((t) => _sendTokenToBackend(t));
    }
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    if (_firebaseReady) {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendTokenToBackend(token);
    } catch (e) { debugPrint('[NOTIF] getToken failed: $e'); }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiClient.instance.put('/auth/device-token', body: {'deviceToken': token});
      debugPrint('[NOTIF] FCM token registered');
    } catch (e) { debugPrint('[NOTIF] device-token register failed: $e'); }
  }

  void _onForegroundMessage(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    show(title: n.title ?? 'إشعار', body: n.body ?? '', payload: m.data['requestId']?.toString());
  }

  void _onMessageOpenedApp(RemoteMessage m) {
    debugPrint('[NOTIF] opened from FCM: ${m.data}');
  }

  Future<void> show({required String title, required String body, String? payload, int? id}) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      _channelId, _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'فى ثانية',
    );
    const iosDetails = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title, body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}
