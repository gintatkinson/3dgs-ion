import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/domain/type_descriptor.dart';
import 'package:app_flutter/features/properties/property_grid.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/core/theme/theme_service.dart';

class FakeThemeService implements ThemeService {
  @override
  Future<ThemeMode> loadThemeMode() async => ThemeMode.system;
  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
  @override
  Future<int> loadThemeScheme() async => 0;
  @override
  Future<void> saveThemeScheme(int scheme) async {}
  @override
  Future<double> loadTextScale() async => 1.0;
  @override
  Future<void> saveTextScale(double scale) async {}
  @override
  Future<Axis> loadLayoutSplitAxis() async => Axis.vertical;
  @override
  Future<void> saveLayoutSplitAxis(Axis axis) async {}
  @override
  Future<double> loadPanelOpacity() async => 0.85;
  @override
  Future<void> savePanelOpacity(double opacity) async {}
}

void main() {
  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider<ThemeController>(
      create: (_) => ThemeController(FakeThemeService()),
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  Finder findTextFieldByLabel(String labelText) {
    final Finder columnFinder = find.byWidgetPredicate((Widget widget) {
      if (widget is Column) {
        final List<Widget> children = widget.children;
        if (children.isNotEmpty && children.first is Text) {
          final Text textWidget = children.first as Text;
          if (textWidget.data == labelText) {
            return true;
          }
        }
      }
      return false;
    });
    return find.descendant(
      of: columnFinder,
      matching: find.byType(TextField),
    );
  }

  Finder findDropdownByLabel(String labelText) {
    final Finder columnFinder = find.byWidgetPredicate((Widget widget) {
      if (widget is Column) {
        final List<Widget> children = widget.children;
        if (children.isNotEmpty && children.first is Text) {
          final Text textWidget = children.first as Text;
          if (textWidget.data == labelText) {
            return true;
          }
        }
      }
      return false;
    });
    return find.descendant(
      of: columnFinder,
      matching: find.byType(DropdownButtonFormField<String>),
    );
  }

  testWidgets('Highlights first section when activeView matches section label',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        PropertyGrid(
          activeView: 'Primary',
          fields: const [
            FieldDescriptor(
                key: 'f1',
                label: 'Field 1',
                type: 'string',
                sectionLabel: 'Primary',
                sectionOrder: 0),
            FieldDescriptor(
                key: 'f2',
                label: 'Field 2',
                type: 'string',
                sectionLabel: 'Secondary',
                sectionOrder: 0),
          ],
        ),
      ),
    );

    expect(find.text('Active Reference'), findsOneWidget);

    final List<Opacity> opacities =
        tester.widgetList<Opacity>(find.byType(Opacity)).toList();
    expect(opacities[0].opacity, 1.0);
    expect(opacities[1].opacity, 0.65);
  });

  testWidgets('Highlights first section when activeView is root',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        PropertyGrid(
          activeView: 'root',
          fields: const [
            FieldDescriptor(
                key: 'f1',
                label: 'Field 1',
                type: 'string',
                sectionLabel: 'Alpha',
                sectionOrder: 0),
            FieldDescriptor(
                key: 'f2',
                label: 'Field 2',
                type: 'string',
                sectionLabel: 'Beta',
                sectionOrder: 0),
          ],
        ),
      ),
    );

    expect(find.text('Active Reference'), findsOneWidget);

    final List<Opacity> opacities =
        tester.widgetList<Opacity>(find.byType(Opacity)).toList();
    expect(opacities[0].opacity, 1.0);
    expect(opacities[1].opacity, 0.65);
  });

  testWidgets('Performs pattern validation on blur',
      (WidgetTester tester) async {
    Map<String, dynamic>? savedData;

    await tester.pumpWidget(
      buildTestableWidget(
        PropertyGrid(
          activeView: 'root',
          fields: const [
            FieldDescriptor(
                key: 'code',
                label: 'Code',
                type: 'string',
                pattern: r'^[A-Z]{2}$',
                inputFormatters: ['uppercase', 'maxLength:2']),
          ],
          onSave: (data) {
            savedData = data;
          },
        ),
      ),
    );

    final Finder codeField = findTextFieldByLabel('Code');
    expect(codeField, findsOneWidget);

    await tester.enterText(codeField, 'U1');
    await tester.pumpAndSettle();

    expect(savedData, isNull);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(find.text('Invalid format'), findsOneWidget);
    expect(savedData, isNull);

    await tester.enterText(codeField, 'FI');
    await tester.pumpAndSettle();

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(find.text('Invalid format'), findsNothing);
    expect(savedData, isNotNull);
    expect(savedData!['code'], 'FI');

    final String jsonString =
        const JsonEncoder.withIndent('  ').convert(savedData);
    expect(find.text(jsonString), findsOneWidget);
  });

  testWidgets('Performs numeric min/max validation on blur',
      (WidgetTester tester) async {
    Map<String, dynamic>? savedData;

    await tester.pumpWidget(
      buildTestableWidget(
        PropertyGrid(
          activeView: 'root',
          fields: const [
            FieldDescriptor(
                key: 'value',
                label: 'Value',
                type: 'int',
                minValue: 0,
                maxValue: 100),
          ],
          onSave: (data) {
            savedData = data;
          },
        ),
      ),
    );

    final Finder valueField = findTextFieldByLabel('Value');
    expect(valueField, findsOneWidget);

    await tester.enterText(valueField, '-1');
    await tester.pumpAndSettle();

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(find.text('Value cannot be less than 0'), findsOneWidget);
    expect(savedData, isNull);

    await tester.enterText(valueField, '50');
    await tester.pumpAndSettle();

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(find.text('Value cannot be less than 0'), findsNothing);
    expect(savedData!['value'], 50);

    await tester.enterText(valueField, '101');
    await tester.pumpAndSettle();

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(find.text('Value cannot be greater than 100'), findsOneWidget);

    await tester.enterText(valueField, '100');
    await tester.pumpAndSettle();

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(find.text('Value cannot be greater than 100'), findsNothing);
    expect(savedData!['value'], 100);
  });

  testWidgets('Enum dropdown renders and commits on change',
      (WidgetTester tester) async {
    Map<String, dynamic>? savedData;

    await tester.pumpWidget(
      buildTestableWidget(
        PropertyGrid(
          activeView: 'root',
          fields: const [
            FieldDescriptor(
                key: 'type',
                label: 'Type',
                type: 'enum',
                enumOptions: ['a', 'b', 'c'],
                enumDisplayNames: ['Option A', 'Option B', 'Option C']),
          ],
          onSave: (data) {
            savedData = data;
          },
        ),
      ),
    );

    final Finder dropdownFinder = findDropdownByLabel('Type');
    expect(dropdownFinder, findsOneWidget);

    await tester.tap(find.text('Option A'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Option C').last);
    await tester.pumpAndSettle();

    expect(savedData, isNotNull);
    expect(savedData!['type'], 'c');
  });
}
