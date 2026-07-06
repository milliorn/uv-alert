import 'package:flutter/material.dart';

/// Ring stroke width, expressed as a fraction of the UV number's rendered
/// font size so it scales with font-size accessibility settings instead of
/// being a fixed pixel value.
const double _ringStrokeWidthFactor = 0.08;

/// Ring diameter, expressed as a multiple of the UV number's rendered font
/// size.
const double _ringDiameterFactor = 2.2;

/// Gap between the ring and the risk label, expressed as a fraction of the
/// UV number's rendered font size.
const double _labelGapFactor = 0.3;

/// Upper bound (inclusive) of the WHO "Low" UV risk band.
const double _whoLowMax = 2;

/// Upper bound (inclusive) of the WHO "Moderate" UV risk band.
const double _whoModerateMax = 5;

/// Upper bound (inclusive) of the WHO "High" UV risk band.
const double _whoHighMax = 7;

/// Upper bound (inclusive) of the WHO "Very High" UV risk band.
const double _whoVeryHighMax = 10;

// Sourced from WHO's "UV Index Symbol Colour Standards (PMS and RGB)"
// table, vendored at docs/adr/who-uv-index-colour-standards.pdf: Low
// RGB(40,149,0) Pantone 375, Moderate RGB(247,228,0) Pantone 102, High
// RGB(248,89,0) Pantone 151, Very High RGB(216,0,29) Pantone 032,
// Extreme RGB(107,73,200) Pantone 265.

/// WHO risk-band color for a UV index of 0-2 ("Low").
const Color _whoColorLow = Color(0xFF289500);

/// WHO risk-band color for a UV index of 3-5 ("Moderate").
const Color _whoColorModerate = Color(0xFFF7E400);

/// WHO risk-band color for a UV index of 6-7 ("High").
const Color _whoColorHigh = Color(0xFFF85900);

/// WHO risk-band color for a UV index of 8-10 ("Very High").
const Color _whoColorVeryHigh = Color(0xFFD8001D);

/// WHO risk-band color for a UV index of 11+ ("Extreme").
const Color _whoColorExtreme = Color(0xFF6B49C8);

/// The WHO risk band for a given UV index: its display color and label.
({Color color, String label}) _whoRiskBand(double uvIndex) {
  if (uvIndex <= _whoLowMax) return (color: _whoColorLow, label: 'Low');

  if (uvIndex <= _whoModerateMax) {
    return (color: _whoColorModerate, label: 'Moderate');
  }

  if (uvIndex <= _whoHighMax) return (color: _whoColorHigh, label: 'High');

  if (uvIndex <= _whoVeryHighMax) {
    return (color: _whoColorVeryHigh, label: 'Very High');
  }

  return (color: _whoColorExtreme, label: 'Extreme');
}

/// Returns the WHO risk-band color for [uvIndex].
Color whoRiskColor(double uvIndex) => _whoRiskBand(uvIndex).color;

/// Returns the WHO risk-band label for [uvIndex].
String whoRiskLabel(double uvIndex) => _whoRiskBand(uvIndex).label;

/// The dashboard hero: a large UV index number inside a WHO-colored ring,
/// with the WHO risk label shown below.
///
/// Sized relative to the ambient text style rather than fixed pixels, so the
/// hero scales correctly under font-size accessibility settings.
class UvCurrentDisplay extends StatelessWidget {
  /// Creates a [UvCurrentDisplay] for the given [uvIndex].
  const UvCurrentDisplay({required this.uvIndex, super.key});

  /// The current UV index reading.
  final double uvIndex;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ({Color color, String label}) band = _whoRiskBand(uvIndex);
    final Color color = band.color;
    final String risk = band.label;
    final String uviLabel = uvIndex.toStringAsFixed(1);

    final TextStyle numberStyle =
        (theme.textTheme.displayLarge ?? const TextStyle(fontSize: 48))
            .copyWith(color: color, fontWeight: FontWeight.bold);

    final double fontSize =
        (numberStyle.fontSize ?? 48) *
        MediaQuery.textScalerOf(context).scale(1);
    final double diameter = fontSize * _ringDiameterFactor;
    final double strokeWidth = fontSize * _ringStrokeWidthFactor;

    return Semantics(
      label: 'UV index $uviLabel, $risk risk',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(
            child: Container(
              width: diameter,
              height: diameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: strokeWidth),
              ),
              child: Text(uviLabel, style: numberStyle),
            ),
          ),
          SizedBox(height: fontSize * _labelGapFactor),
          ExcludeSemantics(
            child: Text(
              risk,
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
