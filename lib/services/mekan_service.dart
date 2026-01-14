import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mekan.dart';

class MekanService {
  MekanService(this.client);
  final SupabaseClient client;

  /// Ana sayfada dinleyeceğimiz stream (yeni kayıt gelince otomatik günceller)
  Stream<List<Mekan>> streamMekanlar() {
    return client.from('mekan').stream(primaryKey: ['id'])
    //.order('OlusturmaTarihi', ascending: false)
    .map((rows) {
      if (rows.isNotEmpty) {
        print('İLK ROW: ${rows.first}');
      }
      return rows.map((r) => Mekan.fromMap(r)).toList();
    });
  }

  /// Yeni mekan ekleme (RLS için EkleyenKullaniciID auth.uid() olmalı)
  Future<void> addMekan({
    required String mekanAdi,
    required String? sehir,
    required String? aciklama,
    required int? butceSeviyesi,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Giriş yapmadan mekan ekleyemezsin (auth gerekli).');
    }

    await client.from('mekan').insert({
      'MekanAdi': mekanAdi,
      'Sehir': sehir,
      'Aciklama': aciklama,
      'ButceSeviyesi': butceSeviyesi,
      'EkleyenKullaniciID': user.id, // RLS CHECK burada geçecek
    });
  }
}
