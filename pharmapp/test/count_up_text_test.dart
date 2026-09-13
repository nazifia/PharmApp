import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharmapp/shared/widgets/in_view.dart';

void main() {
  testWidgets('CountUpText counts to the target and keeps prefix/suffix/format',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Column(children: [
      CountUpText('₦10,000.50'),
      CountUpText('12%'),
      CountUpText('₦1.5M'),
      CountUpText('No data'),
      CountUpText('13 Sep 2026'),
      CountUpText('08012345678'),
    ])));
    await tester.pump(); // post-frame: InView marks visible
    expect(find.text('₦0.00'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('13 Sep 2026'), findsOneWidget); // static: date
    expect(find.text('08012345678'), findsOneWidget); // static: phone
    await tester.pumpAndSettle();
    expect(find.text('₦10,000.50'), findsOneWidget);
    expect(find.text('12%'), findsOneWidget);
    expect(find.text('₦1.5M'), findsOneWidget);
    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('InView stays hidden until scrolled into the viewport',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(child: Column(children: [
      const SizedBox(height: 2000),
      InView(builder: (_, v) => Text(v ? 'seen' : 'unseen')),
    ]))));
    await tester.pump();
    expect(find.text('unseen'), findsOneWidget);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('seen'), findsOneWidget);
  });
}
