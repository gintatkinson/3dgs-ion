import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

/// Central registry of colour schemes and [ThemeData] factories.
///
/// Keeps all Material/Cupertino theming in one place so that light/dark
/// variants stay consistent. Use [light] / [dark] to build themes; use
/// [customSchemes] to offer scheme selection in a settings UI. There is no
/// mutable state — the class is a static namespace.
///
/// **Edge cases**: passing `null` for [custom] falls back to the first
/// entry in [customSchemes] (Greys).
class AppThemes {
  AppThemes._();

  /// Built-in colour schemes exposed for user selection.
  ///
  /// Each entry defines light + dark palettes. The list is fixed at
  /// compile time. Index 0 (Greys) is the fallback when the persisted
  /// index is out of range. An empty list would cause a runtime bounds
  /// error — but it is defined as a non-empty literal.
  static const List<FlexSchemeData> customSchemes = [
    FlexSchemeData(
      name: 'Greys',
      description: 'Professional grey-based theme',
      light: FlexSchemeColor(
        primary: Color(0xFF5C5C5C),
        secondary: Color(0xFF9E9E9E),
        tertiary: Color(0xFFBDBDBD),
        appBarColor: Color(0xFF424242),
        error: Color(0xFFB3261E),
      ),
      dark: FlexSchemeColor(
        primary: Color(0xFFBDBDBD),
        secondary: Color(0xFF757575),
        tertiary: Color(0xFF616161),
        appBarColor: Color(0xFF212121),
        error: Color(0xFFF2B8B5),
      ),
    ),
    FlexSchemeData(
      name: 'Blue Whale',
      description: 'Deep blue ocean theme',
      light: FlexSchemeColor(
        primary: Color(0xFF1A73E0 + 8),
        secondary: Color(0xFF4FC3F7),
        tertiary: Color(0xFF81D4FA),
        appBarColor: Color(0xFF1565C0),
        error: Color(0xFFB3261E),
      ),
      dark: FlexSchemeColor(
        primary: Color(0xFF8AB4F8),
        secondary: Color(0xFF4FC3F7),
        tertiary: Color(0xFF81D4FA),
        appBarColor: Color(0xFF0D47A1),
        error: Color(0xFFF2B8B5),
      ),
    ),
    FlexSchemeData(
      name: 'Mandy Red',
      description: 'Bold red accent theme',
      light: FlexSchemeColor(
        primary: Color(0xFFD32F2F),
        secondary: Color(0xFFE57373),
        tertiary: Color(0xFFFFCDD2),
        appBarColor: Color(0xFFB71C1C),
        error: Color(0xFFB3261E),
      ),
      dark: FlexSchemeColor(
        primary: Color(0xFFEF9A9A),
        secondary: Color(0xFFE57373),
        tertiary: Color(0xFFFFCDD2),
        appBarColor: Color(0xFFC62828),
        error: Color(0xFFF2B8B5),
      ),
    ),
    FlexSchemeData(
      name: 'Wasabi',
      description: 'Fresh green theme',
      light: FlexSchemeColor(
        primary: Color(0xFF43A047),
        secondary: Color(0xFF81C784),
        tertiary: Color(0xFFA5D6A7),
        appBarColor: Color(0xFF2E7D32),
        error: Color(0xFFB3261E),
      ),
      dark: FlexSchemeColor(
        primary: Color(0xFFA5D6A7),
        secondary: Color(0xFF81C784),
        tertiary: Color(0xFF66BB6A),
        appBarColor: Color(0xFF1B5E20),
        error: Color(0xFFF2B8B5),
      ),
    ),
    FlexSchemeData(
      name: 'Deep Purple',
      description: 'Rich purple theme',
      light: FlexSchemeColor(
        primary: Color(0xFF7B1FA2),
        secondary: Color(0xFFCE93D8),
        tertiary: Color(0xFFE1BEE7),
        appBarColor: Color(0xFF4A148C),
        error: Color(0xFFB3261E),
      ),
      dark: FlexSchemeColor(
        primary: Color(0xFFCE93D8),
        secondary: Color(0xFFBA68C8),
        tertiary: Color(0xFFAB47BC),
        appBarColor: Color(0xFF6A1B9A),
        error: Color(0xFFF2B8B5),
      ),
    ),
    FlexSchemeData(
      name: 'Material Baseline',
      description: 'Standard Material 3 baseline',
      light: FlexSchemeColor(
        primary: Color(0xFF6750A4),
        secondary: Color(0xFF625B71),
        tertiary: Color(0xFF7D5260),
        appBarColor: Color(0xFF6750A4),
        error: Color(0xFFB3261E),
      ),
      dark: FlexSchemeColor(
        primary: Color(0xFFD0BCFF),
        secondary: Color(0xFFCCC2DC),
        tertiary: Color(0xFFEFB8C8),
        appBarColor: Color(0xFF4F378B),
        error: Color(0xFFF2B8B5),
      ),
    ),
  ];

  /// Builds a light [ThemeData] from an optional custom scheme.
  ///
  /// When [custom] is null the first scheme (Greys) is used. Does not
  /// cache — every call constructs a new [ThemeData].
  static ThemeData light({FlexSchemeData? custom}) {
    final data = custom ?? customSchemes[0];
    return FlexThemeData.light(
      colors: data.light,
      appBarStyle: FlexAppBarStyle.primary,
      appBarElevation: 4.0,
      tabBarStyle: FlexTabBarStyle.forBackground,
      bottomAppBarElevation: 8.0,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      subThemesData: _subThemes(inputAlpha: 13),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
      useMaterial3: true,
    );
  }

  /// Builds a dark [ThemeData] from an optional custom scheme.
  ///
  /// When [custom] is null the first scheme (Greys) is used. Does not
  /// cache — every call constructs a new [ThemeData].
  static ThemeData dark({FlexSchemeData? custom}) {
    final data = custom ?? customSchemes[0];
    return FlexThemeData.dark(
      colors: data.dark,
      appBarStyle: FlexAppBarStyle.material,
      appBarElevation: 4.0,
      tabBarStyle: FlexTabBarStyle.forBackground,
      bottomAppBarElevation: 8.0,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      subThemesData: _subThemes(inputAlpha: 20),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
      useMaterial3: true,
    );
  }

  /// Shared sub-theme configuration used by both [light] and [dark].
  ///
  /// [inputAlpha] controls the background alpha of input decorators.
  /// Intended values: 13 for light, 20 for dark. Extreme values (e.g. 0
  /// or 255) may reduce readability but will not throw.
  static FlexSubThemesData _subThemes({required int inputAlpha}) => FlexSubThemesData(
    useM2StyleDividerInM3: true,
    adaptiveElevationShadowsBack: FlexAdaptive.all(),
    adaptiveAppBarScrollUnderOff: FlexAdaptive.all(),
    defaultRadius: 4.0,
    elevatedButtonSchemeColor: SchemeColor.onPrimary,
    elevatedButtonSecondarySchemeColor: SchemeColor.primary,
    inputDecoratorSchemeColor: SchemeColor.onSurface,
    inputDecoratorIsFilled: true,
    inputDecoratorBackgroundAlpha: inputAlpha,
    inputDecoratorBorderSchemeColor: SchemeColor.primary,
    inputDecoratorBorderType: FlexInputBorderType.outline,
    listTileContentPadding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
    listTileMinVerticalPadding: 4.0,
    fabUseShape: true,
    fabAlwaysCircular: true,
    fabSchemeColor: SchemeColor.secondary,
    chipSchemeColor: SchemeColor.primary,
    chipRadius: 20.0,
    popupMenuElevation: 8.0,
    alignedDropdown: true,
    tooltipRadius: 4,
    dialogElevation: 24.0,
    datePickerHeaderBackgroundSchemeColor: SchemeColor.primary,
    snackBarBackgroundSchemeColor: SchemeColor.inverseSurface,
    appBarScrolledUnderElevation: 4.0,
    tabBarIndicatorSize: TabBarIndicatorSize.tab,
    tabBarIndicatorWeight: 2,
    tabBarIndicatorTopRadius: 0,
    tabBarDividerColor: const Color(0x00000000),
    drawerElevation: 16.0,
    drawerWidth: 280.0,
    bottomSheetElevation: 10.0,
    bottomSheetModalElevation: 20.0,
    bottomNavigationBarSelectedLabelSchemeColor: SchemeColor.primary,
    bottomNavigationBarMutedUnselectedLabel: true,
    bottomNavigationBarSelectedIconSchemeColor: SchemeColor.primary,
    bottomNavigationBarMutedUnselectedIcon: true,
    bottomNavigationBarElevation: 8.0,
    menuElevation: 8.0,
    menuBarRadius: 0.0,
    menuBarElevation: 1.0,
    navigationBarSelectedLabelSchemeColor: SchemeColor.onSurface,
    navigationBarUnselectedLabelSchemeColor: SchemeColor.onSurface,
    navigationBarMutedUnselectedLabel: true,
    navigationBarSelectedIconSchemeColor: SchemeColor.onSurface,
    navigationBarUnselectedIconSchemeColor: SchemeColor.onSurface,
    navigationBarMutedUnselectedIcon: true,
    navigationBarIndicatorSchemeColor: SchemeColor.secondary,
    navigationBarBackgroundSchemeColor: SchemeColor.surfaceContainer,
    navigationBarElevation: 0.0,
    navigationRailSelectedLabelSchemeColor: SchemeColor.onSurface,
    navigationRailUnselectedLabelSchemeColor: SchemeColor.onSurface,
    navigationRailMutedUnselectedLabel: true,
    navigationRailSelectedIconSchemeColor: SchemeColor.onSurface,
    navigationRailUnselectedIconSchemeColor: SchemeColor.onSurface,
    navigationRailMutedUnselectedIcon: true,
    navigationRailUseIndicator: true,
    navigationRailIndicatorSchemeColor: SchemeColor.secondary,
  );
}
