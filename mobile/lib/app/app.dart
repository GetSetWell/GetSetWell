import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_router.dart';

class GetSetWellApp extends StatelessWidget {
  const GetSetWellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GetSetWell',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.darkTheme,

      routerConfig: appRouter,
    );
  }
}