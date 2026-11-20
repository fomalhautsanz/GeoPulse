import 'package:flutter_test/flutter_test.dart';
import 'package:geopulse/models/device_status.dart';
import 'package:geopulse/services/alert_sound_service.dart';

import 'test_data.dart';

void main() {
  test('soil alert sounds only when the soil risk level increases', () {
    expect(
      AlertSoundService.riskIncreased(null, mockStatus(StatusLevel.critical)),
      isFalse,
    );
    expect(
      AlertSoundService.riskIncreased(
        mockStatus(StatusLevel.stable),
        mockStatus(StatusLevel.watch),
      ),
      isTrue,
    );
    expect(
      AlertSoundService.riskIncreased(
        mockStatus(StatusLevel.watch),
        mockStatus(StatusLevel.high),
      ),
      isTrue,
    );
    expect(
      AlertSoundService.riskIncreased(
        mockStatus(StatusLevel.high),
        mockStatus(StatusLevel.stable),
      ),
      isFalse,
    );
  });
}
