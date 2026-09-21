import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulldive_vr_news/src/screens/contact_screen.dart';

/// The contact page is what Play's News and Magazines review looks for, so
/// the details on it are pinned here rather than left to drift.
void main() {
  test('the version shown on the contact page matches pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([0-9.]+)\+', multiLine: true)
        .firstMatch(pubspec)
        ?.group(1);

    expect(version, isNotNull, reason: 'no version: line in pubspec.yaml');
    expect(FulldiveContact.appVersion, version);
  });

  test('contact details are real addresses, not placeholders', () {
    expect(FulldiveContact.email, contains('@'));
    for (final url in const [
      FulldiveContact.contactPage,
      FulldiveContact.privacyPolicy,
      FulldiveContact.termsOfUse,
    ]) {
      expect(url, startsWith('https://'));
      // fulldive.com answers 308 without the trailing slash.
      expect(url, endsWith('/'));
    }
    expect(FulldiveContact.publisher, isNotEmpty);
  });

  testWidgets('the contact page shows the address in plain text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ContactScreen()),
    );

    // A reviewer has to be able to read the address off the screen, whether
    // or not the tap opens anything.
    expect(find.text('Contact us'), findsOneWidget);
    expect(find.text(FulldiveContact.email), findsOneWidget);
    expect(find.textContaining('fulldive.com/pages/contact-us'), findsOneWidget);
    expect(find.textContaining('fulldive.com/privacy-policy'), findsOneWidget);
    expect(find.textContaining(FulldiveContact.publisher), findsWidgets);
  });
}
