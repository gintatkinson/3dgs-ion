class CoordinateValidationException implements Exception {
  final String message;

  CoordinateValidationException(this.message);

  @override
  String toString() => 'CoordinateValidationException: $message';
}

class VirtualCamera {
  final double latitude;
  final double longitude;
  final double altitude;
  final double heading;
  final double pitch;
  final double roll;

  VirtualCamera({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.heading,
    required this.pitch,
    required this.roll,
  }) {
    if (latitude.isNaN || latitude.isInfinite ||
        longitude.isNaN || longitude.isInfinite ||
        altitude.isNaN || altitude.isInfinite ||
        heading.isNaN || heading.isInfinite ||
        pitch.isNaN || pitch.isInfinite ||
        roll.isNaN || roll.isInfinite) {
      throw CoordinateValidationException('Coordinates and orientation values must be finite numbers.');
    }
    if (latitude < -90.0 || latitude > 90.0) {
      throw CoordinateValidationException('Latitude must be in the range [-90.0, 90.0].');
    }
    if (longitude < -180.0 || longitude > 180.0) {
      throw CoordinateValidationException('Longitude must be in the range [-180.0, 180.0].');
    }
    if (altitude < -100.0) {
      throw CoordinateValidationException('Altitude must be greater than or equal to -100.0 meters.');
    }
  }

  /// Creates a copy of VirtualCamera with clamped values if they exceed boundaries.
  /// Clamps altitude to at least -100.0, latitude to [-90, 90], and longitude to [-180, 180].
  factory VirtualCamera.clamped({
    required double latitude,
    required double longitude,
    required double altitude,
    required double heading,
    required double pitch,
    required double roll,
  }) {
    final double lat = (latitude.isNaN || latitude.isInfinite) ? 0.0 : latitude;
    final double lng = (longitude.isNaN || longitude.isInfinite) ? 0.0 : longitude;
    final double alt = (altitude.isNaN || altitude.isInfinite) ? 0.0 : altitude;
    final double head = (heading.isNaN || heading.isInfinite) ? 0.0 : heading;
    final double pit = (pitch.isNaN || pitch.isInfinite) ? 0.0 : pitch;
    final double rl = (roll.isNaN || roll.isInfinite) ? 0.0 : roll;

    final double clampedLat = lat.clamp(-90.0, 90.0);
    final double clampedLng = lng.clamp(-180.0, 180.0);
    final double clampedAlt = alt < -100.0 ? -100.0 : alt;
    return VirtualCamera(
      latitude: clampedLat,
      longitude: clampedLng,
      altitude: clampedAlt,
      heading: head,
      pitch: pit,
      roll: rl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! VirtualCamera) return false;
    return other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude &&
        other.heading == heading &&
        other.pitch == pitch &&
        other.roll == roll;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, altitude, heading, pitch, roll);

  @override
  String toString() {
    return 'VirtualCamera(latitude: $latitude, longitude: $longitude, altitude: $altitude, heading: $heading, pitch: $pitch, roll: $roll)';
  }
}
