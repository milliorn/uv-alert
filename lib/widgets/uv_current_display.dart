import 'package:flutter/material.dart';
import 'package:uvalert/utils/who_risk.dart';

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
    final ({Color color, String label}) band = whoRiskBand(uvIndex);
    final Color color = band.color;
    final String risk = band.label;
    final String uviLabel = truncateToTenth(uvIndex).toStringAsFixed(1);
    final String semanticsLabel = uvIndexSemanticsPhrase(uvIndex);

    final TextStyle numberStyle =
        (theme.textTheme.displayLarge ?? const TextStyle(fontSize: 48))
            .copyWith(color: color, fontWeight: FontWeight.bold);

    final double fontSize = MediaQuery.textScalerOf(
      context,
    ).scale(numberStyle.fontSize ?? 48);
    final double diameter = fontSize * _ringDiameterFactor;
    final double strokeWidth = fontSize * _ringStrokeWidthFactor;

    return Semantics(
      label: semanticsLabel,
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
