import 'dart:math' as math;

/// Number of degrees in a half circle (pi radians), used to convert between
/// degrees and radians.
const double degreesPerHalfCircle = 180;

/// Converts [degrees] to radians.
double degToRad(double degrees) => degrees * math.pi / degreesPerHalfCircle;

/// Converts [radians] to degrees.
double radToDeg(double radians) => radians * degreesPerHalfCircle / math.pi;
