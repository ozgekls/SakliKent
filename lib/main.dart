import 'package:flutter/material.dart';
//import 'package:saklikent/deneme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'pages/home_page.dart';
import 'pages/main_shell_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://knobkkkxppbtxlfuyxlx.supabase.co',
    anonKey: 'sb_publishable_Dz2S7e5LIK3dOzer1eiRaA_tliG5mQF',
  );

  runApp(const SakliKentApp());
}

final supabase = Supabase.instance.client;

class SakliKentApp extends StatelessWidget {
  const SakliKentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saklı Kent',
      theme: ThemeData(useMaterial3: true),
      home: const MainShellPage(),
    );
  }
}
