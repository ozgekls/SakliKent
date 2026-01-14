import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl =
      'https://knobkkkxppbtxlfuyxlx.supabase.co'; // Buraya kendi URL'ini yaz
  static const String supabaseAnonKey =
      'sb_publishable_Dz2S7e5LIK3dOzer1eiRaA_tliG5mQF'; // Buraya kendi Anon Key'ini yaz

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
