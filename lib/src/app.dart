import 'package:flutter/material.dart';

import 'screens/news_feed_screen.dart';
import 'theme/fulldive_theme.dart';

class FulldiveVrNewsApp extends StatelessWidget {
  const FulldiveVrNewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fulldive VR News',
      debugShowCheckedModeBanner: false,
      theme: FulldiveTheme.build(),
      home: const NewsFeedScreen(),
    );
  }
}
