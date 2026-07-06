import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/core/theme/theme_service.dart';

class FakeThemeService implements ThemeService {
  ThemeMode themeMode = ThemeMode.system;
  int themeScheme = 0;
  double textScale = 1.0;
  Axis? layoutSplitAxis;
  double panelOpacity = 0.85;

  @override
  Future<ThemeMode> loadThemeMode() async => themeMode;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    themeMode = mode;
  }

  @override
  Future<int> loadThemeScheme() async => themeScheme;

  @override
  Future<void> saveThemeScheme(int scheme) async {
    themeScheme = scheme;
  }

  @override
  Future<double> loadTextScale() async => textScale;

  @override
  Future<void> saveTextScale(double scale) async {
    textScale = scale;
  }

  @override
  Future<Axis> loadLayoutSplitAxis() async => layoutSplitAxis ?? Axis.vertical;

  @override
  Future<void> saveLayoutSplitAxis(Axis axis) async {
    layoutSplitAxis = axis;
  }

  @override
  Future<double> loadPanelOpacity() async => panelOpacity;

  @override
  Future<void> savePanelOpacity(double opacity) async {
    panelOpacity = opacity;
  }
}

void main() {
  group('ThemeController - LayoutSplitAxis', () {
    late FakeThemeService fakeThemeService;
    late ThemeController controller;

    setUp(() {
      fakeThemeService = FakeThemeService();
      controller = ThemeController(fakeThemeService);
    });

    test('initial layoutSplitAxis should be Axis.vertical', () {
      expect(controller.layoutSplitAxis, Axis.vertical);
    });

    test('loadSettings loads saved layoutSplitAxis', () async {
      fakeThemeService.layoutSplitAxis = Axis.vertical;
      await controller.loadSettings();
      expect(controller.layoutSplitAxis, Axis.vertical);
    });

    test('updateLayoutSplitAxis updates layoutSplitAxis, calls notifyListeners, and saves to service', () async {
      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.updateLayoutSplitAxis(Axis.horizontal);

      expect(controller.layoutSplitAxis, Axis.horizontal);
      expect(notified, true);
      expect(fakeThemeService.layoutSplitAxis, Axis.horizontal);
    });

    test('updateLayoutSplitAxis with null or same value is a no-op', () async {
      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.updateLayoutSplitAxis(null);
      expect(notified, false);

      await controller.updateLayoutSplitAxis(Axis.vertical);
      expect(notified, false);
    });
  });

  group('ThemeController - PanelOpacity', () {
    late FakeThemeService fakeThemeService;
    late ThemeController controller;

    setUp(() {
      fakeThemeService = FakeThemeService();
      controller = ThemeController(fakeThemeService);
    });

    test('initial panelOpacity should be 0.85', () {
      expect(controller.panelOpacity, 0.85);
    });

    test('loadSettings loads saved panelOpacity', () async {
      fakeThemeService.panelOpacity = 0.5;
      await controller.loadSettings();
      expect(controller.panelOpacity, 0.5);
    });

    test('updatePanelOpacity updates panelOpacity, calls notifyListeners, and saves to service', () async {
      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.updatePanelOpacity(0.7);

      expect(controller.panelOpacity, 0.7);
      expect(notified, true);
      expect(fakeThemeService.panelOpacity, 0.7);
    });

    test('updatePanelOpacity with null or same value is a no-op', () async {
      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.updatePanelOpacity(null);
      expect(notified, false);

      await controller.updatePanelOpacity(0.85);
      expect(notified, false);
    });
  });

  group('SharedPreferencesThemeService - LayoutSplitAxis', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadLayoutSplitAxis returns Axis.vertical by default', () async {
      final service = SharedPreferencesThemeService();
      final axis = await service.loadLayoutSplitAxis();
      expect(axis, Axis.vertical);
    });

    test('saveLayoutSplitAxis persists the value and loadLayoutSplitAxis reads it', () async {
      final service = SharedPreferencesThemeService();
      await service.saveLayoutSplitAxis(Axis.vertical);

      final loaded = await service.loadLayoutSplitAxis();
      expect(loaded, Axis.vertical);
    });

    test('loadLayoutSplitAxis falls back to Axis.vertical if stored value is invalid', () async {
      SharedPreferences.setMockInitialValues({
        'layout_split_axis': 'invalid_value',
      });
      final service = SharedPreferencesThemeService();
      final loaded = await service.loadLayoutSplitAxis();
      expect(loaded, Axis.vertical);
    });
  });

  group('SharedPreferencesThemeService - PanelOpacity', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadPanelOpacity returns 0.85 by default', () async {
      final service = SharedPreferencesThemeService();
      final opacity = await service.loadPanelOpacity();
      expect(opacity, 0.85);
    });

    test('savePanelOpacity persists the value and loadPanelOpacity reads it', () async {
      final service = SharedPreferencesThemeService();
      await service.savePanelOpacity(0.65);

      final loaded = await service.loadPanelOpacity();
      expect(loaded, 0.65);
    });
  });
}
