import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'driver_service.dart';

/// Handles pushes that arrive while the app is in the background or closed.
/// Top-level by requirement, and runs in its own isolate.
@pragma('vm:entry-point')
Future<void> driverBackgroundHandler(RemoteMessage message) async {
  try {
    // Android reads google-services.json at build time (via the
    // com.google.gms.google-services Gradle plugin), so no options are needed
    // here. If you later add iOS, run `flutterfire configure` and pass
    // DefaultFirebaseOptions.currentPlatform instead.
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[Push] background init failed: $e');
  }
}

/// Firebase setup and token registration for the driver app.
/// Messages the office sends to bus staff land here.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _channelId = 'staff_messages';
  final _local = FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _attached = false;
  StreamSubscription<RemoteMessage>? _msgSub;
  StreamSubscription<String>? _tokenSub;

  /// Called once at startup.
  Future<void> init() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(driverBackgroundHandler);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _local.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      final android = _local.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        'Messages from the school',
        description: 'Notices sent to drivers and conductors.',
        importance: Importance.high,
      ));
      await android?.requestNotificationsPermission();

      _ready = true;
      debugPrint('[Push] Firebase ready.');
    } catch (e) {
      debugPrint('[Push] Firebase init FAILED — messages will not be pushed: $e');
    }
  }

  /// Called once the driver is signed in and we know their drivers row id.
  Future<void> attach(DriverService service, String driverId) async {
    if (_attached || !_ready) return;
    _attached = true;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      debugPrint('[Push] permission: ${settings.authorizationStatus}');

      final platform = Platform.isIOS ? 'ios' : 'android';
      if (Platform.isIOS) await messaging.getAPNSToken();

      final token = await messaging.getToken();
      if (token != null) {
        await service.registerDeviceToken(token, platform, driverId);
        debugPrint('[Push] token saved (${token.substring(0, 12)}…)');
      }

      // Tokens rotate on reinstall or data clear.
      _tokenSub = messaging.onTokenRefresh.listen(
        (t) => service.registerDeviceToken(t, platform, driverId),
      );

      // Android hides FCM's own notification while the app is open.
      _msgSub = FirebaseMessaging.onMessage.listen((m) {
        final title = m.notification?.title ?? m.data['title'] ?? 'Evide School Bus';
        final body = m.notification?.body ?? m.data['body'] ?? '';
        _local.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Messages from the school',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      });
    } catch (e) {
      debugPrint('[Push] wiring failed: $e');
    }
  }

  /// Stops this phone receiving messages meant for the signed-out driver.
  Future<void> detach(DriverService service) async {
    await _msgSub?.cancel();
    await _tokenSub?.cancel();
    _msgSub = null;
    _tokenSub = null;
    _attached = false;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await service.removeDeviceToken(token);
    } catch (_) {}
  }
}
