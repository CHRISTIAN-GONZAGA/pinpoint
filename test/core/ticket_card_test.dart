import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/core/design_system/ticket_card.dart';
import 'package:pinpoint/core/theme/app_theme.dart';

void main() {
  testWidgets('TicketCard shows route code and fare when both exist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: TicketCard(
            title: 'Robinsons',
            category: 'Malls',
            routeCode: 'R1',
            fareLabel: '₱15',
          ),
        ),
      ),
    );

    expect(find.text('Robinsons'), findsOneWidget);
    expect(find.text('Malls'), findsOneWidget);
    expect(find.text('R1'), findsOneWidget);
    expect(find.text('₱15'), findsOneWidget);
    expect(find.byIcon(Icons.place), findsNothing);
  });

  testWidgets('TicketCard uses a pin stub and hides fare when route data is missing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: TicketCard(
            title: 'City Hall',
            category: 'Government',
          ),
        ),
      ),
    );

    expect(find.text('City Hall'), findsOneWidget);
    expect(find.text('Government'), findsOneWidget);
    expect(find.byIcon(Icons.place), findsOneWidget);
    expect(find.textContaining('₱'), findsNothing);
  });
}
