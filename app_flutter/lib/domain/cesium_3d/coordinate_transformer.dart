import 'dart:typed_data';

import 'virtual_camera.dart';

class CoordinateTransformer {
  /// Transforms ECEF coordinates to local coordinates.
  ///
  /// Rejects coordinates containing NaN or Infinite values.
  @Deprecated('Use transformEcefToLocalOut to avoid GC churn on the hot path.')
  List<double> transformEcefToLocal(double ecefX, double ecefY, double ecefZ) {
    final out = Float64List(3);
    transformEcefToLocalOut(out, ecefX, ecefY, ecefZ);
    return out;
  }

  /// Transforms ECEF coordinates to local coordinates, writing the result
  /// into the caller-provided [out] buffer (must have length >= 3).
  ///
  /// This overload avoids heap allocation on the hot path. Rejects
  /// coordinates containing NaN or Infinite values.
  void transformEcefToLocalOut(
      Float64List out, double ecefX, double ecefY, double ecefZ) {
    if (ecefX.isNaN || ecefX.isInfinite ||
        ecefY.isNaN || ecefY.isInfinite ||
        ecefZ.isNaN || ecefZ.isInfinite) {
      throw CoordinateValidationException(
          'ECEF coordinates must map to real values. '
          'NaN or Infinite coordinates are rejected.');
    }
    out[0] = ecefX * 0.01;
    out[1] = ecefY * 0.01;
    out[2] = ecefZ * 0.01;
  }
}
