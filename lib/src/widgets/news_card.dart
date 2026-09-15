import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/news_article.dart';
import '../theme/fulldive_theme.dart';
import 'article_meta.dart';

/// A story in the feed: cover image, title, teaser and source/date footer.
class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.article, required this.onTap});

  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (article.hasImage)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: NewsImage(url: article.imageUrl, heroTag: article.id),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.tags.isNotEmpty) ...[
                    TagChip(label: article.tags.first),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.28,
                      fontWeight: FontWeight.w700,
                      color: FulldiveColors.textPrimary,
                    ),
                  ),
                  if (article.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: FulldiveColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ArticleMetaLine(article: article),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Network image with brand-coloured placeholder and fallback states.
class NewsImage extends StatelessWidget {
  const NewsImage({super.key, required this.url, this.heroTag});

  final String url;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, _) => const ColoredBox(
        color: FulldiveColors.navyToolbar,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, _, _) => const ColoredBox(
        color: FulldiveColors.navyToolbar,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: FulldiveColors.textTertiary,
          ),
        ),
      ),
    );

    return heroTag == null ? image : Hero(tag: heroTag!, child: image);
  }
}

/// Small orange-tinted topic chip.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: FulldiveColors.orange.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: FulldiveColors.orange,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
