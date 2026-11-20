import 'package:flutter/foundation.dart';

import '../models/device_status.dart';
import 'alert_sound_platform_stub.dart'
    if (dart.library.html) 'alert_sound_platform_web.dart'
    as platform;

class AlertSoundService {
  AlertSoundService._();

  static bool get isSupported => platform.isSupported;

  static bool riskIncreased(DeviceStatus? before, DeviceStatus after) =>
      before != null && before.soilLevel.index < after.soilLevel.index;

  static Future<void> playAlert() async {
    if (!isSupported) return;
    try {
      await platform.playSound();
    } catch (e, stackTrace) {
      debugPrint('Automatic soil alert sound failed: $e\n$stackTrace');
    }
  }

  static Future<void> playTestSound() => platform.playSound();
}
