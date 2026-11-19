import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Flutter runs this before every test file. It loads the real Roboto so
/// tests lay text out like the app does (tests otherwise use a blocky
/// placeholder font).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final roboto = FontLoader('Roboto');
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    final bytes = File('assets/fonts/Roboto-$weight.ttf').readAsBytesSync();
    roboto.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await roboto.load();
  await testMain();
}
