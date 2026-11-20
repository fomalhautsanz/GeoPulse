import 'package:flutter/material.dart';

import '../state/status_controller.dart';
import '../widgets/app_scaffold.dart';

/// Shows the map as unavailable until the node reports real coordinates and
/// evacuation areas are configured.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final status = StatusScope.of(context).status;

    return AppScaffold(
      title: 'Map',
      currentTab: AppTab.map,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined, size: 52),
              const SizedBox(height: 12),
              const Text(
                'Map location unavailable',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                status == null
                    ? 'Waiting for node data. This firmware does not report GPS coordinates or evacuation areas.'
                    : 'Node ${status.nodeId} does not report GPS coordinates. Evacuation areas are not configured.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
