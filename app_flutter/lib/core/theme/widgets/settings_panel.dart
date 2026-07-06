import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/core/theme/app_themes.dart';
import 'package:app_flutter/core/theme/text_scaler.dart';

/// A bottom-sheet-style settings panel for theme mode, colour scheme, and
/// text size.
///
/// Reads [ThemeController] and [TextScalerController] via
/// `context.watch()` so it rebuilds automatically when the user changes
/// a setting. Embed inside a `showModalBottomSheet` or a [Drawer].
///
/// **State**: stateless — all mutations delegate to the controllers.
/// Rebuilds on every controller notification.
///
/// **Edge cases**: the wrap layout for colour swatches may overflow on
/// very narrow screens (< 300 dp logical width).
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final textScaler = context.watch<TextScalerController>();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Theme', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.settings_brightness, size: 18)),
            ],
            selected: {themeController.themeMode},
            onSelectionChanged: (Set<ThemeMode> newSelection) {
              themeController.updateThemeMode(newSelection.first);
            },
          ),
          const SizedBox(height: 16),
          Text('Workspace Split', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<Axis>(
            segments: const [
              ButtonSegment(
                value: Axis.horizontal,
                icon: Icon(Icons.splitscreen_outlined, size: 18),
                label: Text('Horizontal'),
              ),
              ButtonSegment(
                value: Axis.vertical,
                icon: RotatedBox(
                  quarterTurns: 1,
                  child: Icon(Icons.splitscreen_outlined, size: 18),
                ),
                label: Text('Vertical'),
              ),
            ],
            selected: {themeController.layoutSplitAxis},
            onSelectionChanged: (Set<Axis> newSelection) {
              themeController.updateLayoutSplitAxis(newSelection.first);
            },
          ),
          const SizedBox(height: 16),
          Text('Overlay Opacity', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.opacity, size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
              Expanded(
                child: Slider(
                  value: themeController.panelOpacity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(themeController.panelOpacity * 100).round()}%',
                  onChanged: (value) => themeController.updatePanelOpacity(value),
                ),
              ),
              Icon(Icons.opacity, size: 22, color: cs.onSurface),
            ],
          ),
          const SizedBox(height: 16),

          Text('Color', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(AppThemes.customSchemes.length, (index) {
              final scheme = AppThemes.customSchemes[index];
              final isSelected = index == themeController.currentThemeIndex;
              return GestureDetector(
                onTap: () => themeController.updateThemeScheme(index),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? cs.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: ClipOval(
                    child: Container(
                      color: isDark ? scheme.dark.primary : scheme.light.primary,
                      alignment: Alignment.center,
                      child: isSelected
                          ? Icon(Icons.check, size: 16, color: scheme.light.primary.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          Text('Text Size', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.text_fields, size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
              Expanded(
                child: Slider(
                  key: const Key('settings_text_scale_slider'),
                  value: textScaler.scale,
                  min: 0.7,
                  max: 1.5,
                  divisions: 8,
                  label: '${(textScaler.scale * 100).round()}%',
                  onChanged: (value) => textScaler.setScale(value),
                ),
              ),
              Icon(Icons.text_fields, size: 22, color: cs.onSurface),
            ],
          ),
        ],
      ),
    );
  }
}
