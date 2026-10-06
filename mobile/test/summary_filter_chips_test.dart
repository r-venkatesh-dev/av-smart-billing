import 'package:av_smartbilling_mobile/src/widgets/summary_filter_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SummaryFilterChips renders all chips and handles selection', (
    tester,
  ) async {
    String selected = 'all';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SummaryFilterChips<String>(
                selectedValue: selected,
                onSelected: (val) => setState(() => selected = val),
                items: const [
                  SummaryChipItem(
                    value: 'all',
                    label: 'All',
                    count: 48,
                    variant: SummaryChipVariant.primary,
                  ),
                  SummaryChipItem(
                    value: 'active',
                    label: 'Active',
                    count: 42,
                    variant: SummaryChipVariant.success,
                  ),
                  SummaryChipItem(
                    value: 'low_stock',
                    label: 'Low Stock',
                    count: 4,
                    variant: SummaryChipVariant.warning,
                  ),
                  SummaryChipItem(
                    value: 'inactive',
                    label: 'Inactive',
                    count: 2,
                    variant: SummaryChipVariant.neutral,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('48'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Low Stock'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Tap on 'Active' chip
    await tester.tap(find.text('Active'));
    await tester.pumpAndSettle();

    expect(selected, 'active');
  });

  testWidgets('SummaryFilterChips does not overflow on a narrow 320px screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SummaryFilterChips<String>(
            selectedValue: 'all',
            onSelected: (_) {},
            items: const [
              SummaryChipItem(
                value: 'all',
                label: 'All',
                count: 100,
                variant: SummaryChipVariant.primary,
              ),
              SummaryChipItem(
                value: 'active',
                label: 'Active',
                count: 85,
                variant: SummaryChipVariant.success,
              ),
              SummaryChipItem(
                value: 'low_stock',
                label: 'Low Stock',
                count: 10,
                variant: SummaryChipVariant.warning,
              ),
              SummaryChipItem(
                value: 'inactive',
                label: 'Inactive',
                count: 5,
                variant: SummaryChipVariant.neutral,
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
