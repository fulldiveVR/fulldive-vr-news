import 'package:flutter/material.dart';

import '../models/news_article.dart';
import '../theme/fulldive_theme.dart';
import '../widgets/article_meta.dart';
import '../widgets/news_card.dart';
import 'web_article_screen.dart';

/// Full-screen reader for a single story.
class NewsArticleScreen extends StatelessWidget {
  const NewsArticleScreen({super.key, required this.article});

  final NewsArticle article;

  static Route<void> route(NewsArticle article) => MaterialPageRoute<void>(
        builder: (_) => NewsArticleScreen(article: article),
      );

  @override
  Widget build(BuildContext context) {
    final paragraphs = article.paragraphs;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (article.hasImage)
            SliverAppBar(
              pinned: true,
              expandedHeight: 260,
              backgroundColor: FulldiveColors.navyDeep,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    NewsImage(url: article.imageUrl, heroTag: article.id),
                    // Keeps the back button legible over bright photos.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xB3000000), Color(0x00000000), Color(0x66212E47)],
                          stops: [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [_OpenOriginalButton(article: article)],
            )
          else
            SliverAppBar(
              pinned: true,
              title: Text(article.sourceName),
              actions: [_OpenOriginalButton(article: article)],
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList.list(
              children: [
                if (article.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in article.tags) TagChip(label: tag),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  article.title,
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1.24,
                    fontWeight: FontWeight.w800,
                    color: FulldiveColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ArticleMetaLine(article: article),
                if (article.author.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'By ${article.author}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: FulldiveColors.textTertiary,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                if (article.summary.isNotEmpty) ...[
                  Text(
                    article.summary,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: FulldiveColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                for (final paragraph in paragraphs) ...[
                  Text(
                    paragraph,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.62,
                      color: FulldiveColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (article.sourceUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openOriginal(context),
                      icon: const Icon(Icons.article_outlined, size: 18),
                      label: Text(
                        article.sourceName.isEmpty
                            ? 'Read the full story'
                            : 'Read the full story on ${article.sourceName}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the publisher's page in the in-app browser, keeping the reader
  /// inside Fulldive VR News.
  void _openOriginal(BuildContext context) {
    Navigator.of(context).push(WebArticleScreen.route(article));
  }
}

class _OpenOriginalButton extends StatelessWidget {
  const _OpenOriginalButton({required this.article});

  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    if (article.sourceUrl.isEmpty) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Open original',
      icon: const Icon(Icons.public),
      onPressed: () => Navigator.of(context).push(WebArticleScreen.route(article)),
    );
  }
}
