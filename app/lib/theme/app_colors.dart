import 'package:flutter/material.dart';

/// Every colour used in the app, in one place.
///
/// Names follow the Figma variables in the "GeoPulse" collection
/// (e.g. `brand/primary` -> [brand], `level/watch/container` ->
/// [watchContainer]). Widgets should use these instead of writing
/// `Color(0xFF...)` themselves.
class AppColors {
  AppColors._(); // Only static members; nobody needs to create an AppColors.

  // Brand: header pill, nav bar, primary buttons.
  static const Color brand = Color(0xFFB73737); // brand/primary
  static const Color onBrand = Color(0xFFFFFFFF);

  // Neutrals
  static const Color card = Color(0xFFF3F3F3); // neutral/surface-variant
  static const Color ink = Color(0xFF1F1A1A); // neutral/ink (main text)
  static const Color muted = Color(0xFF5C5454); // neutral/muted (secondary text)
  static const Color outline = Color(0xFFE6E0E0); // neutral/outline (borders)
  static const Color surface = Color(0xFFFFFFFF); // neutral/surface (background)

  // Risk levels ("Reference · Risk colours and motion" in Figma).
  // Neutral when calm, then deeper GeoPulse red as risk rises.
  static const Color stableContainer = Color(0xFFF3F3F3); // level/stable/container
  static const Color stableOn = ink; // level/stable/on
  static const Color watchContainer = Color(0xFFFBE4E2); // level/watch/container
  static const Color watchStrong = Color(0xFFCF6A5E); // level/watch/strong
  static const Color watchOn = Color(0xFF7A2420); // level/watch/on
  static const Color highContainer = brand; // level/high/container
  static const Color highOn = Color(0xFFFFFFFF); // level/high/on
  static const Color criticalContainer = Color(0xFF5E1111); // level/critical/container
  static const Color criticalOn = Color(0xFFFFFFFF); // level/critical/on

  // Wayfinding: water, evacuation area and "you" on the map.
  static const Color wayfinding = Color(0xFF1F5FA8);

  // Soft arch behind the status title, one tint per level. It fades to
  // [surface] (pure white). Watch uses [watchContainer] (#FBE4E2).
  static const Color heroGlow = Color(0xFFEAF0F4); // stable
  static const Color highGlow = Color(0xFFF7D6D3); // high
  static const Color criticalGlow = Color(0xFFF0DCDC); // light maroon tint

  // On the maroon critical-alert header
  static const Color onCriticalMuted = Color(0xD9FFFFFF); // white at 85%
  static const Color sirenHalo = Color(0x26FFFFFF); // white at 15%
  static const Color sirenRing = Color(0x66FFFFFF); // white at 40%

  // Status feedback
  static const Color success = Color(0xFF43A047); // "warning sent" checks
  static const Color banner = Color(0xFF2A2525); // dark "Node offline" banner
  static const Color switchOnDisabled = Color(0xFFDB9B9B); // "always on" switch
  static const Color unreadDot = brand;
  static const Color emptyDot = Color(0x805C5454); // muted at 50%: day with no alerts

  // Map
  static const Color mapLand = Color(0xFFF3F1EF);
  static const Color mapContour = Color(0xFFE4DBD7);
  static const Color mapRoad = Color(0xFFFFFFFF);
  static const Color mapWater = Color(0xFFC9DCEF);
  static const Color youHalo = Color(0x401F5FA8); // wayfinding blue at 25%
  static const Color riskZoneFill = Color(0x1F5E1111); // maroon at 12%
  static const Color riskZoneBorder = Color(0x995E1111); // maroon at 60%

  // Sensors chart
  static const Color chartLine = ink;
  static const Color chartCriticalBand = Color(0xFFFBE4E2);
  static const Color chartWarningBand = Color(0xFFFDF2F1);
  static const Color chartLimitLine = Color(0xFF7A2420);
  static const Color chartBar = Color(0xFFE6E0E0);
  static const Color chartEndDot = Color(0xFFE07A72);

  // Effects
  static const Color shadow = Color(0x40000000); // black at 25%
  static const Color softShadow = Color(0x1A000000); // black at 10%
  static const Color scrim = Color(0x801F1A1A); // behind dialogs and sheets
  static const Color holdFill = Color(0x2EB73737); // hold-to-confirm progress
  static const Color debug = Color(0xFF3D3D3D); // temporary debug button
}
