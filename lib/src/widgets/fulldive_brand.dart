import 'package:flutter/material.dart';

import '../theme/fulldive_theme.dart';

/// The round Fulldive mark — the same artwork the Unity shell app ships as
/// its launcher icon.
class FulldiveMark extends StatelessWidget {
  const FulldiveMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/fulldive_logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// App bar title: the mark, the FULLDIVE wordmark and the "NEWS" suffix.
class FulldiveWordmarkTitle extends StatelessWidget {
  const FulldiveWordmarkTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const FulldiveMark(size: 30),
        const SizedBox(width: 10),
        Image.asset(
          'assets/images/fulldive_wordmark.png',
          height: 15,
          filterQuality: FilterQuality.medium,
        ),
        const SizedBox(width: 8),
        const Text(
          'NEWS',
          style: TextStyle(
            color: FulldiveColors.orange,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }
}
