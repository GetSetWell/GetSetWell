import 'package:flutter/material.dart';

import '../core/routing/gsw_router.dart';
import '../core/theme/gsw_theme.dart';

class GetSetWellApp extends StatelessWidget {
  const GetSetWellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GetSetWell',
      debugShowCheckedModeBanner: false,

      theme: GSWTheme.darkTheme,

      routerConfig: gswRouter,
    );
  }
}
