import 'dart:js_interop';

import 'package:web/web.dart' as web;

const bool isSupported = true;

web.HTMLAudioElement? _audio;

Future<void> playSound() async {
  final audio = _audio ??= (web.HTMLAudioElement()
    ..src = Uri.base.resolve('assets/assets/sounds/soil_alert.wav').toString()
    ..preload = 'auto'
    ..volume = 0.7);
  audio.pause();
  audio.currentTime = 0;
  await audio.play().toDart;
}
