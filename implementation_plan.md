# Implementation Plan - Trailing Pane Explicit Sizing

## 1. Objectives
Modify `app_flutter/lib/features/layout/split_workspace.dart` to calculate and apply explicit non-negative dimensions (`width` and `height`) for the trailing pane Positioned widget. This prevents negative sizing crashes on window resize when the remaining space drops below zero.

## 2. File Modifications

### `app_flutter/lib/features/layout/split_workspace.dart`
- Around lines 195-201, replace the `trailingWidget` declaration with:
```dart
        final double? trailingWidth = isHorizontal
            ? math.max(0.0, totalSize - clampedFirstPane - widget.dividerSize)
            : null;
        final double? trailingHeight = isHorizontal
            ? null
            : math.max(0.0, totalSize - clampedFirstPane - widget.dividerSize);

        final trailingWidget = Positioned(
          left: isHorizontal ? clampedFirstPane + widget.dividerSize : 0,
          right: isHorizontal ? null : 0,
          top: isHorizontal ? 0 : clampedFirstPane + widget.dividerSize,
          bottom: isHorizontal ? 0 : null,
          width: trailingWidth,
          height: trailingHeight,
          child: trailingPane,
        );
```

## 3. Success / Verification Criteria
- Run unit tests using `flutter test` and confirm they compile and pass.
- Commit the changes and push them to the GitHub `main` branch.
- Verify `git diff origin/main` is completely empty.
