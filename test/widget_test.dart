import 'package:cavaciuti_ops/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows dashboard and navigates to workboard', (tester) async {
    final store = OperationsStore(
      screenshotMode: true,
      initialRecords: screenshotRecords,
    );

    await tester.pumpWidget(OperationsApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Daily operations cockpit'), findsOneWidget);
    expect(find.text('Priority queue'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('Operational records'), findsOneWidget);
    expect(find.text('Lobby access reader fault'), findsOneWidget);
  });

  testWidgets('creates a local operations record', (tester) async {
    final store = OperationsStore(screenshotMode: true, initialRecords: []);

    await tester.pumpWidget(OperationsApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('newRecordButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('titleField')),
      'Walk-in reservation request',
    );
    await tester.enterText(find.byKey(const Key('ownerField')), 'Front office');
    await tester.enterText(
      find.byType(TextFormField).last,
      'Hold a room until confirmation.',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saveRecordButton')));
    await tester.pumpAndSettle();

    expect(store.records, hasLength(1));
    expect(store.records.single.title, 'Walk-in reservation request');
  });
}
