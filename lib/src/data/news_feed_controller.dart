import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/news_article.dart';
import 'news_repository.dart';

/// Drives the paginated feed: the first page, every subsequent page and
/// pull-to-refresh, with the errors of each kept apart so a failed
/// "load more" never blanks out the stories already on screen.
class NewsFeedController extends ChangeNotifier {
  NewsFeedController({NewsRepository? repository})
      : _repository = repository ?? NewsRepository();

  final NewsRepository _repository;

  final List<NewsArticle> _articles = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;

  bool _isLoadingFirstPage = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  Object? _initialError;
  Object? _pageError;

  List<NewsArticle> get articles => List.unmodifiable(_articles);
  bool get isLoadingFirstPage => _isLoadingFirstPage;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  Object? get initialError => _initialError;
  Object? get pageError => _pageError;
  bool get isEmpty => _articles.isEmpty;

  Future<void> loadInitial() async {
    _isLoadingFirstPage = true;
    _initialError = null;
    notifyListeners();

    try {
      final page = await _repository.fetchPage();
      _articles
        ..clear()
        ..addAll(page.articles);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
    } catch (error, stack) {
      _initialError = error;
      debugPrint('Failed to load the first news page: $error\n$stack');
    } finally {
      _isLoadingFirstPage = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoadingFirstPage || !_hasMore) return;

    _isLoadingMore = true;
    _pageError = null;
    notifyListeners();

    try {
      final page = await _repository.fetchPage(startAfter: _cursor);
      _articles.addAll(page.articles);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
    } catch (error, stack) {
      _pageError = error;
      debugPrint('Failed to load the next news page: $error\n$stack');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh: replaces the list only once the new first page arrives,
  /// so a failed refresh leaves the current stories untouched.
  Future<void> refresh() async {
    try {
      final page = await _repository.fetchPage();
      _articles
        ..clear()
        ..addAll(page.articles);
      _cursor = page.cursor;
      _hasMore = page.hasMore;
      _initialError = null;
      _pageError = null;
    } catch (error, stack) {
      debugPrint('Failed to refresh the news feed: $error\n$stack');
      if (_articles.isEmpty) _initialError = error;
    } finally {
      notifyListeners();
    }
  }
}
