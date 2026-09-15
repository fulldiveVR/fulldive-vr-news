import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/news_article.dart';
import '../theme/fulldive_theme.dart';

/// "UploadVR · 3h ago · 4 min read" footer shared by the card and the reader.
class ArticleMetaLine extends StatelessWidget {
  const ArticleMetaLine({
    super.key,
    required this.article,
    this.color = FulldiveColors.textTertiary,
  });

  final NewsArticle article;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (article.sourceName.isNotEmpty) article.sourceName,
      formatArticleDate(article.publishedAt),
      '${article.readingTimeMinutes} min read',
    ];

    return Text(
      parts.join('  ·  '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: color),
    );
  }
}

/// Relative for anything from the last week, an absolute date beyond that.
String formatArticleDate(DateTime published) {
  final elapsed = DateTime.now().difference(published);

  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';

  final sameYear = published.year == DateTime.now().year;
  return DateFormat(sameYear ? 'MMM d' : 'MMM d, y').format(published);
}
