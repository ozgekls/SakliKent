import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/mekan.dart';
import 'services/mekan_service.dart';
import 'add_mekan_page.dart';

final supabase = Supabase.instance.client;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = MekanService(supabase);

    return Scaffold(
      appBar: AppBar(title: const Text('Saklı Kent')),

      // 1) DB’yi dinliyoruz
      body: StreamBuilder<List<Mekan>>(
        stream: service.streamMekanlar(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final mekanlar = snapshot.data ?? [];
          if (mekanlar.isEmpty) {
            return const Center(
              child: Text('Henüz mekan yok. İlk mekanı ekle!'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: mekanlar.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = mekanlar[i];
              return Card(
                child: ListTile(
                  title: Text(m.mekanAdi),
                  subtitle: Text(
                    [
                      if ((m.sehir ?? '').isNotEmpty) m.sehir!,
                      if ((m.aciklama ?? '').isNotEmpty) m.aciklama!,
                      if (m.butceSeviyesi != null)
                        'Bütçe: ${m.butceSeviyesi}/5',
                    ].join(' • '),
                  ),
                ),
              );
            },
          );
        },
      ),

      // 2) Mekan ekleme butonu
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Butona basınca form sayfasına gidiyoruz
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMekanPage()),
          );
          // Geri dönünce ekstra bir şey yapmıyoruz,
          // çünkü StreamBuilder zaten DB değişimini yakalayacak.
        },
        icon: const Icon(Icons.add),
        label: const Text('Mekan Ekle'),
      ),
    );
  }
}
