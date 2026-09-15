import 'package:flutter/material.dart';

import '../data/news_feed_controller.dart';
import '../theme/fulldive_theme.dart';
import '../widgets/fulldive_brand.dart';
import '../widgets/news_card.dart';
import 'news_article_screen.dart';

/// Home screen: the paginated VR news feed.
class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final _controller = NewsFeedController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _controller.loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Fetches the next page once the user is within two screens of the end.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      _controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FulldiveWordmarkTitle(),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoadingFirstPage) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.initialError != null && _controller.isEmpty) {
            return _FeedMessage(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load the feed',
              message: 'Check the connection and try again.',
              actionLabel: 'Retry',
              onAction: _controller.loadInitial,
            );
          }

          if (_controller.isEmpty) {
            return _FeedMessage(
              icon: Icons.article_outlined,
              title: 'No stories yet',
              message:
                  'Run the seeding script to fill the news collection in Firestore.',
              actionLabel: 'Reload',
              onAction: _controller.loadInitial,
            );
          }

          return RefreshIndicator(
            onRefresh: _controller.refresh,
            color: FulldiveColors.orange,
            backgroundColor: FulldiveColors.navySurface,
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: _controller.articles.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == _controller.articles.length) {
                  return _FeedFooter(controller: _controller);
                }

                final article = _controller.articles[index];
                return NewsCard(
                  article: article,
                  onTap: () => Navigator.of(context)
                      .push(NewsArticleScreen.route(article)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Bottom-of-list state: spinner while paging, retry on failure, end marker.
class _FeedFooter extends StatelessWidget {
  const _FeedFooter({required this.controller});

  final NewsFeedController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (controller.pageError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: TextButton.icon(
            onPressed: controller.loadMore,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Could not load more — tap to retry'),
            style: TextButton.styleFrom(
              foregroundColor: FulldiveColors.orange,
            ),
          ),
        ),
      );
    }

    if (controller.hasMore) return const SizedBox(height: 8);

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          "That's everything for now",
          style: TextStyle(fontSize: 13, color: FulldiveColors.textTertiary),
        ),
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: FulldiveColors.textTertiary),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: FulldiveColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: FulldiveColors.textSecondary,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
