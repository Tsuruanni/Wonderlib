import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owlio_admin/core/widgets/admin_nav_list_item.dart';

void main() {
  group('AdminNavListItem', () {
    testWidgets('renders icon and label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdminNavListItem(
            icon: Icons.menu_book,
            label: 'Kitaplar',
            isActive: false,
            onTap: () {},
          ),
        ),
      ));

      expect(find.byIcon(Icons.menu_book), findsOneWidget);
      expect(find.text('Kitaplar'), findsOneWidget);
    });

    testWidgets('fires onTap callback when tapped', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdminNavListItem(
            icon: Icons.menu_book,
            label: 'Kitaplar',
            isActive: false,
            onTap: () => tapCount++,
          ),
        ),
      ));

      await tester.tap(find.text('Kitaplar'));
      await tester.pump();
      expect(tapCount, 1);
    });

    testWidgets('active item uses accent color for text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdminNavListItem(
            icon: Icons.menu_book,
            label: 'Kitaplar',
            isActive: true,
            onTap: () {},
          ),
        ),
      ));

      final text = tester.widget<Text>(find.text('Kitaplar'));
      expect(text.style?.color, const Color(0xFF4F46E5));
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('inactive item uses grey color', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdminNavListItem(
            icon: Icons.menu_book,
            label: 'Kitaplar',
            isActive: false,
            onTap: () {},
          ),
        ),
      ));

      final text = tester.widget<Text>(find.text('Kitaplar'));
      expect(text.style?.color, Colors.grey.shade800);
    });
  });
}
