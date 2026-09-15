import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/news_article.dart';
import '../theme/fulldive_theme.dart';

/// The publisher's own page, opened inside the app instead of handing the
/// reader off to an external browser.
class WebArticleScreen extends StatefulWidget {
  const WebArticleScreen({super.key, required this.article});

  final NewsArticle article;

  static Route<void> route(NewsArticle article) => MaterialPageRoute<void>(
        builder: (_) => WebArticleScreen(article: article),
      );

  @override
  State<WebArticleScreen> createState() => _WebArticleScreenState();
}

class _WebArticleScreenState extends State<WebArticleScreen> {
  late final WebViewController _controller;

  double _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(FulldiveColors.navy)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress / 100),
          onPageStarted: (_) => setState(() {
            _progress = 0;
            _failed = false;
          }),
          onPageFinished: (_) => setState(() => _progress = 1),
          // Only the main document counts as a failure; a blocked tracker or
          // a missing image must not replace the article with an error page.
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) setState(() => _failed = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.article.sourceUrl));
  }

  /// Back walks the page history first, and only then leaves the screen.
  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop) return;
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openExternally() async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(widget.article.sourceUrl);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the original article')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(widget.article.sourceUrl)?.host ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.article.sourceName.isEmpty ? 'Original story' : widget.article.sourceName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (host.isNotEmpty)
                Text(
                  host,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: FulldiveColors.textTertiary,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Open in browser',
              icon: const Icon(Icons.open_in_browser),
              onPressed: _openExternally,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: SizedBox(
              height: 2,
              child: _progress < 1
                  ? LinearProgressIndicator(
                      value: _progress == 0 ? null : _progress,
                      backgroundColor: FulldiveColors.navyDeep,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        body: _failed
            ? _LoadFailed(
                onRetry: () {
                  setState(() => _failed = false);
                  _controller.reload();
                },
                onOpenExternally: _openExternally,
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry, required this.onOpenExternally});

  final VoidCallback onRetry;
  final VoidCallback onOpenExternally;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52, color: FulldiveColors.textTertiary),
            const SizedBox(height: 18),
            const Text(
              'Could not load the page',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: FulldiveColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check the connection, or open the story in your browser.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: FulldiveColors.textSecondary),
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
            TextButton(
              onPressed: onOpenExternally,
              style: TextButton.styleFrom(foregroundColor: FulldiveColors.orange),
              child: const Text('Open in browser'),
            ),
          ],
        ),
      ),
    );
  }
}
