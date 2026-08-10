import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://tijezquislhgmfchbkyt.supabase.co',
    publishableKey: 'sb_publishable_IoIiF6bHkE31U9qEVCZ1lg_ykCNYCwz',
  );
  runApp(const GetSetWellApp());
}
