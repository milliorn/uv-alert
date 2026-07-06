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

/// Padding inside the ring, expressed as a multiple of the ring's stroke
/// width, so the number never touches or overflows past the ring border
/// even for wider content than a typical "9.1"-style reading (e.g. a
/// negative sign or an unexpectedly long value).
const double _ringInnerPaddingFactor = 1.5;

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

/// Truncates (not rounds) [uvIndex] to one decimal place, per WHO's
/// convention of truncating fractional UV readings rather than rounding
/// them (e.g. 3.01 -> 3.0, 2.99 -> 2.9).
double _truncateToTenth(double uvIndex) =>
    (uvIndex * _tenthsPerUnit).truncateToDouble() / _tenthsPerUnit;

/// Number of tenths in one whole UV index unit, used to truncate to one
/// decimal place without rounding.
const double _tenthsPerUnit = 10;

/// The WHO risk band for a given UV index: its display color and label.
///
/// Bands on the same truncated-to-one-decimal value that is displayed, so
/// the shown number and its color/label can never disagree (e.g. a raw
/// 5.04 truncates to the displayed "5.0" and bands as Moderate, not High).
({Color color, String label}) _whoRiskBand(double uvIndex) {
  final double v = _truncateToTenth(uvIndex);

  if (v <= _whoLowMax) return (color: _whoColorLow, label: 'Low');

  if (v <= _whoModerateMax) {
    return (color: _whoColorModerate, label: 'Moderate');
  }

  if (v <= _whoHighMax) return (color: _whoColorHigh, label: 'High');

  if (v <= _whoVeryHighMax) {
    return (color: _whoColorVeryHigh, label: 'Very High');
  }

  return (color: _whoColorExtreme, label: 'Extreme');
}

/// Returns the WHO risk-band color for [uvIndex].
///
/// Exposed for tests only; [UvCurrentDisplay] itself reads bands via the
/// private [_whoRiskBand].
@visibleForTesting
Color whoRiskColor(double uvIndex) => _whoRiskBand(uvIndex).color;

/// Returns the WHO risk-band label for [uvIndex].
///
/// Exposed for tests only; [UvCurrentDisplay] itself reads bands via the
/// private [_whoRiskBand].
@visibleForTesting
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
    final String uviLabel = _truncateToTenth(uvIndex).toStringAsFixed(1);

    final TextStyle numberStyle =
        (theme.textTheme.displayLarge ?? const TextStyle(fontSize: 48))
            .copyWith(color: color, fontWeight: FontWeight.bold);

    final double fontSize = MediaQuery.textScalerOf(
      context,
    ).scale(numberStyle.fontSize ?? 48);
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
              padding: EdgeInsets.all(strokeWidth * _ringInnerPaddingFactor),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: strokeWidth),
              ),
              child: FittedBox(
                child: Text(uviLabel, style: numberStyle, maxLines: 1),
              ),
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
