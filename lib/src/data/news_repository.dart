import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/news_article.dart';

/// One page of stories plus the cursor needed to ask for the next one.
class NewsPage {
  const NewsPage({
    required this.articles,
    required this.cursor,
    required this.hasMore,
  });

  final List<NewsArticle> articles;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
}

/// Reads the `news` collection out of the project's named Firestore database.
class NewsRepository {
  NewsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ??
            FirebaseFirestore.instanceFor(
              app: Firebase.app(),
              databaseId: databaseId,
            );

  /// The Firebase project has no `(default)` database — the only one that
  /// exists is named `main`, so every client has to address it explicitly.
  static const databaseId = 'main';
  static const collectionPath = 'news';
  static const pageSize = 15;

  final FirebaseFirestore _firestore;

  Future<NewsPage> fetchPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = pageSize,
  }) async {
    var query = _firestore
        .collection(collectionPath)
        .orderBy('publishedAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return NewsPage(
      articles: snapshot.docs.map(NewsArticle.fromFirestore).toList(),
      cursor: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
      hasMore: snapshot.docs.length == limit,
    );
  }
}
