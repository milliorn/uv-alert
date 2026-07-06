import 'package:flutter/material.dart';

/// Upper bound (inclusive) of the WHO "Low" UV risk band.
const double whoLowMax = 2;

/// Upper bound (inclusive) of the WHO "Moderate" UV risk band.
const double whoModerateMax = 5;

/// Upper bound (inclusive) of the WHO "High" UV risk band.
const double whoHighMax = 7;

/// Upper bound (inclusive) of the WHO "Very High" UV risk band.
const double whoVeryHighMax = 10;

// Sourced from WHO's "UV Index Symbol Colour Standards (PMS and RGB)" table,
// vendored at docs/adr/who-uv-index-colour-standards.pdf: Low RGB(40,149,0)
// Pantone 375, Moderate RGB(247,228,0) Pantone 102, High RGB(248,89,0)
// Pantone 151, Very High RGB(216,0,29) Pantone 032, Extreme RGB(107,73,200)
// Pantone 265.

/// WHO risk-band color for a UV index of 0-2 ("Low").
const Color whoColorLow = Color(0xFF289500);

/// WHO risk-band color for a UV index of 3-5 ("Moderate").
const Color whoColorModerate = Color(0xFFF7E400);

/// WHO risk-band color for a UV index of 6-7 ("High").
const Color whoColorHigh = Color(0xFFF85900);

/// WHO risk-band color for a UV index of 8-10 ("Very High").
const Color whoColorVeryHigh = Color(0xFFD8001D);

/// WHO risk-band color for a UV index of 11+ ("Extreme").
const Color whoColorExtreme = Color(0xFF6B49C8);

/// Number of tenths in one whole UV index unit, used to truncate to one
/// decimal place without rounding.
const double _tenthsPerUnit = 10;

/// Truncates (not rounds) [uvIndex] to one decimal place, per WHO's
/// convention of truncating fractional UV readings rather than rounding
/// them (e.g. 3.01 -> 3.0, 2.99 -> 2.9).
double truncateToTenth(double uvIndex) =>
    (uvIndex * _tenthsPerUnit).truncateToDouble() / _tenthsPerUnit;

/// The WHO risk band for a given UV index: its display color and label.
///
/// Bands on the same truncated-to-one-decimal value that is displayed, so
/// the shown number and its color/label can never disagree (e.g. a raw
/// 5.04 truncates to the displayed "5.0" and bands as Moderate, not High).
({Color color, String label}) whoRiskBand(double uvIndex) {
  final double v = truncateToTenth(uvIndex);

  if (v <= whoLowMax) return (color: whoColorLow, label: 'Low');

  if (v <= whoModerateMax) {
    return (color: whoColorModerate, label: 'Moderate');
  }

  if (v <= whoHighMax) return (color: whoColorHigh, label: 'High');

  if (v <= whoVeryHighMax) {
    return (color: whoColorVeryHigh, label: 'Very High');
  }

  return (color: whoColorExtreme, label: 'Extreme');
}

/// Returns the WHO risk-band color for [uvIndex].
Color whoRiskColor(double uvIndex) => whoRiskBand(uvIndex).color;

/// Returns the WHO risk-band label for [uvIndex].
String whoRiskLabel(double uvIndex) => whoRiskBand(uvIndex).label;
