import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pinpoint/core/widgets/responsive_content.dart';

void main() {
  testWidgets('centers content within its maximum width', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveContent(
            maxWidth: 700,
            child: SizedBox.expand(key: ValueKey('responsive-content')),
          ),
        ),
      ),
    );

    final content = find.byKey(const ValueKey('responsive-content'));
    expect(tester.getSize(content).width, 700);
    expect(tester.getTopLeft(content).dx, 450);
  });
}
