import 'package:cloud_firestore/cloud_firestore.dart';

/// A single story as stored in the `news` collection of Cloud Firestore.
class NewsArticle {
  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.imageUrl,
    required this.sourceName,
    required this.sourceUrl,
    required this.author,
    required this.publishedAt,
    required this.tags,
  });

  final String id;
  final String title;
  final String summary;
  final String content;
  final String imageUrl;
  final String sourceName;
  final String sourceUrl;
  final String author;
  final DateTime publishedAt;
  final List<String> tags;

  bool get hasImage => imageUrl.isNotEmpty;

  /// Rough reading time at 200 words per minute, never less than a minute.
  int get readingTimeMinutes {
    final words = content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return words <= 200 ? 1 : (words / 200).ceil();
  }

  /// Body split into paragraphs for rendering. Feeds routinely repeat the
  /// teaser as the opening paragraph, so a leading duplicate of the summary
  /// is dropped — it is already shown above the body as the lead.
  List<String> get paragraphs {
    final paragraphs = content
        .split(RegExp(r'\n{1,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isNotEmpty && summary.isNotEmpty) {
      final lead = _comparable(summary);
      final first = _comparable(paragraphs.first);
      if (lead.isNotEmpty && (first.startsWith(lead) || lead.startsWith(first))) {
        paragraphs.removeAt(0);
      }
    }
    return List.unmodifiable(paragraphs);
  }

  /// Lowercased, whitespace-collapsed and shorn of the ellipsis that
  /// truncated summaries end with, so the two can be compared.
  static String _comparable(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[…\.]+$'), '')
      .trim();

  factory NewsArticle.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      NewsArticle.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});

  /// Every field is read defensively: the collection is filled by an external
  /// content service, so a malformed document degrades instead of throwing.
  factory NewsArticle.fromMap(String id, Map<String, dynamic> data) {
    return NewsArticle(
      id: id,
      title: _string(data['title']),
      summary: _string(data['summary']),
      content: _string(data['content']),
      imageUrl: _string(data['imageUrl']),
      sourceName: _string(data['sourceName']),
      sourceUrl: _string(data['sourceUrl']),
      author: _string(data['author']),
      publishedAt: _dateTime(data['publishedAt']),
      tags: _stringList(data['tags']),
    );
  }

  static String _string(Object? value) => value is String ? value : '';

  static DateTime _dateTime(Object? value) => switch (value) {
        Timestamp(:final seconds, :final nanoseconds) => DateTime
            .fromMillisecondsSinceEpoch(seconds * 1000 + nanoseconds ~/ 1000000),
        final int millis => DateTime.fromMillisecondsSinceEpoch(millis),
        final String iso => DateTime.tryParse(iso) ?? DateTime.now(),
        _ => DateTime.now(),
      };

  static List<String> _stringList(Object? value) => value is List
      ? value.whereType<String>().toList(growable: false)
      : const <String>[];
}
