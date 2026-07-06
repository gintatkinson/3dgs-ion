import 'dart:ui';

/// Projected screen-space point with a depth value for front/back hemisphere
/// culling. [offset] is the 2D canvas position; [z] is the signed distance
/// from the screen plane — positive values are in front of the camera
/// (visible hemisphere).
class ProjectedPoint {
  /// The 2D canvas-space pixel offset of the projected point.
  final Offset offset;

  /// The signed depth after rotation and tilt; &ge; 0 indicates the point
  /// is on the front (visible) hemisphere.
  final double z;

  /// Creates a projected point from a pixel offset and a signed depth.
  ProjectedPoint(this.offset, this.z);
}
