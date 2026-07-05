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

/// WHO risk-band color for a UV index of 0-2 ("Low").
const Color _whoColorLow = Color(0xFF4CAF50);

/// WHO risk-band color for a UV index of 3-5 ("Moderate").
const Color _whoColorModerate = Color(0xFFFFC107);

/// WHO risk-band color for a UV index of 6-7 ("High").
const Color _whoColorHigh = Color(0xFFFF9800);

/// WHO risk-band color for a UV index of 8-10 ("Very High").
const Color _whoColorVeryHigh = Color(0xFFF44336);

/// WHO risk-band color for a UV index of 11+ ("Extreme").
const Color _whoColorExtreme = Color(0xFF9C27B0);

/// Returns the WHO risk-band color for [uvIndex].
Color whoRiskColor(double uvIndex) {
  if (uvIndex <= _whoLowMax) return _whoColorLow;
  if (uvIndex <= _whoModerateMax) return _whoColorModerate;
  if (uvIndex <= _whoHighMax) return _whoColorHigh;
  if (uvIndex <= _whoVeryHighMax) return _whoColorVeryHigh;
  return _whoColorExtreme;
}

/// Returns the WHO risk-band label for [uvIndex].
String whoRiskLabel(double uvIndex) {
  if (uvIndex <= _whoLowMax) return 'Low';
  if (uvIndex <= _whoModerateMax) return 'Moderate';
  if (uvIndex <= _whoHighMax) return 'High';
  if (uvIndex <= _whoVeryHighMax) return 'Very High';
  return 'Extreme';
}

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
    final Color color = whoRiskColor(uvIndex);
    final String risk = whoRiskLabel(uvIndex);
    final String uviLabel = uvIndex.toStringAsFixed(1);

    final TextStyle numberStyle = (theme.textTheme.displayLarge ??
            const TextStyle(fontSize: 48))
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
