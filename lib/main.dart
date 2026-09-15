import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/theme/fulldive_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(FulldiveTheme.systemOverlay);
  // Options come from android/app/google-services.json, borrowed from the
  // Unity shell app so this build keeps the same Firebase identity.
  await Firebase.initializeApp();
  runApp(const FulldiveVrNewsApp());
}
