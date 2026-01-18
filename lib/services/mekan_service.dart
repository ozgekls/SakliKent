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

  Future<List<Map<String, dynamic>>> getKategoriler() async {
    final res = await client
        .from('kategori')
        .select('kategoriid, kategoriadi')
        .order('kategoriadi', ascending: true);

    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Yeni mekan ekleme (RLS için EkleyenKullaniciID auth.uid() olmalı)
  Future<String> addMekanReturnId({
    required String mekanAdi,
    required String? sehir,
    required String? aciklama,
    required int? butceSeviyesi,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('Giriş yapmadan mekan ekleyemezsin.');

    final inserted = await client
        .from('mekan')
        .insert({
          'mekanadi': mekanAdi,
          'sehir': sehir,
          'aciklama': aciklama,
          'butceseviyesi': butceSeviyesi,
          'ekleyenkullaniciid': user.id,
        })
        .select('id')
        .single();

    return inserted['id'].toString();
  }

  Future<void> addMekanKategoriler({
    required String mekanId,
    required List<String> kategoriIds,
  }) async {
    if (kategoriIds.isEmpty) return;

    final rows = kategoriIds
        .map((kid) => {'mekanid': mekanId, 'kategoriid': kid})
        .toList();

    await client.from('mekankategori').insert(rows);
  }

  Future<List<Map<String, dynamic>>> getKesfetFiltreli(
    Map<String, dynamic> params,
  ) async {
    final res = await client.rpc('f_kesfet_filtre', params: params);
    return (res as List).cast<Map<String, dynamic>>();
  }
}
