/// Validates a TemporalContext.
/// Property coverage: timestamp, validUntil, velocity
bool validateTemporalContext(Map<String, dynamic> context) {
  final timestamp = context['timestamp'] as String? ?? '';
  final validUntil = context['validUntil'] as String? ?? '';
  if (timestamp.isEmpty || validUntil.isEmpty) {
    return false;
  }
  final ts = DateTime.tryParse(timestamp);
  final vu = DateTime.tryParse(validUntil);
  if (ts == null || vu == null) {
    return false;
  }
  // Temporal Validity: validUntil cannot be prior to timestamp
  return vu.compareTo(ts) >= 0;
}

/// Validates a PostalAddress.
/// Property coverage: address, postalCode, state, city, countryCode
bool validatePostalAddress(Map<String, dynamic> addr) {
  final countryCode = addr['countryCode'] as String? ?? '';
  if (countryCode.isEmpty) {
    return false;
  }
  // Country Code Validation: countryCode must match /^[A-Z]{2}$/ regex
  final countryRegex = RegExp(r'^[A-Z]{2}$');
  return countryRegex.hasMatch(countryCode);
}

/// Validates a PlaceType.
/// Property coverage: identity
bool validatePlaceType(Map<String, dynamic> placeType) {
  const validIdentities = ['zone', 'area', 'cluster'];
  return validIdentities.contains(placeType['identity'] as String? ?? '');
}

/// Validates a LoadSpec.
/// Property coverage: maxVoltage, maxAllocatedPower, capacity, location
bool validateLoadSpec(Map<String, dynamic> spec) {
  final maxVoltage = (spec['maxVoltage'] as num?)?.toDouble() ?? 0.0;
  final maxAllocatedPower = (spec['maxAllocatedPower'] as num?)?.toDouble() ?? 0.0;
  final capacity = (spec['capacity'] as num?)?.toInt() ?? 0;
  // Load Validation: maxVoltage and maxAllocatedPower must be non-negative
  if (maxVoltage < 0 || maxAllocatedPower < 0) {
    return false;
  }
  if (capacity < 0) {
    return false;
  }
  return true;
}

/// Validates slot overlap between two contained units.
/// Property coverage: unitId, startSlot, slotWidth
bool hasSlotOverlap(Map<String, dynamic> unit1, Map<String, dynamic> unit2) {
  final start1 = (unit1['startSlot'] as num?)?.toInt() ?? 0;
  final width1 = (unit1['slotWidth'] as num?)?.toInt() ?? 0;
  final start2 = (unit2['startSlot'] as num?)?.toInt() ?? 0;
  final width2 = (unit2['slotWidth'] as num?)?.toInt() ?? 0;
  return start1 < start2 + width2 &&
      start2 < start1 + width1;
}

/// Validates slot allocations for a containment subsystem to ensure no overlaps.
/// Property coverage: units, validateAllocation, validateSlotOverlap
bool validateUnitAllocation(Map<String, dynamic> subsystem) {
  final unitList = (subsystem['units'] as List<dynamic>?) ?? [];
  for (int i = 0; i < unitList.length; i++) {
    for (int j = i + 1; j < unitList.length; j++) {
      if (hasSlotOverlap(
        unitList[i] as Map<String, dynamic>,
        unitList[j] as Map<String, dynamic>,
      )) {
        return false;
      }
    }
  }
  return true;
}

class ReferenceFrameValidation {
  final bool isValid;
  final Map<String, dynamic> sanitizedFrame;
  final String sanitizedFrameName;

  const ReferenceFrameValidation({
    required this.isValid,
    required this.sanitizedFrame,
    required this.sanitizedFrameName,
  });
}

String sanitizeFrameName(String name) {
  var result = name.trim();
  result = result.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '');
  if (result.toLowerCase().startsWith('the-')) {
    result = result.substring(4);
  }
  return result.toUpperCase();
}

ReferenceFrameValidation validateReferenceFrame(
  Map<String, dynamic> frame, {
  String? frameName,
  bool alternateSystemEnabled = false,
}) {
  if (frameName != null) {
    for (final codeUnit in frameName.codeUnits) {
      if (codeUnit <= 0x1f || codeUnit == 0x7f) {
        return ReferenceFrameValidation(
          isValid: false,
          sanitizedFrame: frame,
          sanitizedFrameName: sanitizeFrameName(frameName),
        );
      }
    }
  }

  if (frame['alternateSystem'] != null && !alternateSystemEnabled) {
    return ReferenceFrameValidation(
      isValid: false,
      sanitizedFrame: frame,
      sanitizedFrameName: frameName != null ? sanitizeFrameName(frameName) : '',
    );
  }

  return ReferenceFrameValidation(
    isValid: true,
    sanitizedFrame: frame,
    sanitizedFrameName: frameName != null ? sanitizeFrameName(frameName) : '',
  );
}
