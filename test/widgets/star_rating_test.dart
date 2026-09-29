import 'package:bhutan_services/core/strings/app_strings.dart';
import 'package:bhutan_services/shared/widgets/star_rating.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpStars(WidgetTester tester, StarRating stars) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: stars))));

void main() {
  testWidgets('shows whole and half stars, and reads the rating aloud', (tester) async {
    await pumpStars(tester, const StarRating(rating: 3.5));

    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    expect(find.bySemanticsLabel(AppStrings.ratedOutOf5(3.5)), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('becomes a picker when onChanged is given', (tester) async {
    int? picked;
    await pumpStars(tester, StarRating(rating: 0, onChanged: (stars) => picked = stars));

    expect(find.byType(IconButton), findsNWidgets(5));
    await tester.tap(find.byTooltip(AppStrings.starsLabel(4)));
    expect(picked, 4);
  });
}
