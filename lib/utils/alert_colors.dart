import 'package:flutter/material.dart';

/// The background/foreground color pair used to visually mark government
/// weather alert content, shared by `WeatherAlertBanner` and
/// `AlertListScreen`'s alert cards so the two surfaces read as the same
/// alert "color language" rather than two independently-chosen scheme pairs.
extension AlertColors on ColorScheme {
  /// Background for alert content (the banner, and each card in the full
  /// alert list).
  Color get alertBackground => errorContainer;

  /// Foreground (icon/text) color for content on [alertBackground].
  Color get alertForeground => onErrorContainer;
}
