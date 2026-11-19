import 'package:flutter/material.dart';

import '../models/device_status.dart';
import '../models/sensor.dart';
import '../state/shell_scope.dart';
import '../state/status_controller.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/map_view.dart';
import '../widgets/node_sheet.dart';

/// "Map · Node and evacuation area" in Figma. Tap the sensor node to slide
/// up its details sheet (300 ms, drag down to close).
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final status = StatusScope.of(context).status;
    final shell = ShellScope.maybeOf(context)?.actions;

    return AppScaffold(
      title: 'Map',
      currentTab: AppTab.map,
      body: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: MapView(
          level: status?.level ?? StatusLevel.stable,
          onNodeTap: () {
            if (status == null) return;
            showNodeSheet(
              context,
              status,
              onViewReadings: () => shell?.selectTab(AppTab.sensors, sensor: SensorKind.soil),
            );
          },
        ),
      ),
    );
  }
}
