import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fulldive_vr_news/src/models/news_article.dart';

NewsArticle article({String summary = '', String content = ''}) => NewsArticle(
      id: 'id',
      title: 'title',
      summary: summary,
      content: content,
      imageUrl: '',
      sourceName: 'UploadVR',
      sourceUrl: '',
      author: '',
      publishedAt: DateTime(2026, 9, 14),
      tags: const [],
    );

void main() {
  group('paragraphs', () {
    test('splits the body on blank lines', () {
      final paragraphs = article(content: 'One.\n\nTwo.\n\nThree.').paragraphs;
      expect(paragraphs, ['One.', 'Two.', 'Three.']);
    });

    test('drops a lead paragraph that repeats the summary', () {
      final paragraphs = article(
        summary: 'A card battler launched a beta.',
        content: 'A card battler launched a beta.\n\nThe beta runs all week.',
      ).paragraphs;
      expect(paragraphs, ['The beta runs all week.']);
    });

    test('drops the lead when the summary was truncated', () {
      final paragraphs = article(
        summary: 'A card battler launched a limited…',
        content: 'A card battler launched a limited beta on Quest.\n\nMore soon.',
      ).paragraphs;
      expect(paragraphs, ['More soon.']);
    });

    test('keeps a lead paragraph that only shares a topic', () {
      final paragraphs = article(
        summary: 'A card battler launched a beta.',
        content: 'Valve announced the Steam Frame price.\n\nMore soon.',
      ).paragraphs;
      expect(paragraphs, ['Valve announced the Steam Frame price.', 'More soon.']);
    });
  });

  group('readingTimeMinutes', () {
    test('never drops below a minute', () {
      expect(article(content: 'Three short words').readingTimeMinutes, 1);
    });

    test('rounds up at 200 words per minute', () {
      expect(article(content: List.filled(450, 'word').join(' ')).readingTimeMinutes, 3);
    });
  });

  group('fromMap', () {
    test('reads the document, defaulting missing fields', () {
      final parsed = NewsArticle.fromMap('abc', {
        'title': 'Steam Frame price revealed',
        'summary': 'Valve opened pre-orders.',
        'content': 'Valve opened pre-orders today.',
        'imageUrl': 'https://example.com/a.jpg',
        'sourceName': 'Road to VR',
        'sourceUrl': 'https://roadtovr.com/a',
        'publishedAt': Timestamp.fromDate(DateTime.utc(2026, 9, 14, 17)),
        'tags': ['SteamVR', 'VR', 7],
      });

      expect(parsed.id, 'abc');
      expect(parsed.title, 'Steam Frame price revealed');
      expect(parsed.publishedAt.toUtc(), DateTime.utc(2026, 9, 14, 17));
      expect(parsed.tags, ['SteamVR', 'VR']); // non-strings are dropped
      expect(parsed.author, ''); // absent field
      expect(parsed.hasImage, isTrue);
    });

    test('survives a document with no fields at all', () {
      final parsed = NewsArticle.fromMap('empty', const {});
      expect(parsed.title, '');
      expect(parsed.hasImage, isFalse);
      expect(parsed.tags, isEmpty);
    });
  });
}
