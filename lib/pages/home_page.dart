import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_mekan_page.dart';
import 'mekan_detay_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
//import '../models/mekan.dart';
import '../services/mekan_service.dart';

final supabase = Supabase.instance.client;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final MekanService _service;
  StreamSubscription<AuthState>? _authSub;

  User? _user;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _service = MekanService(supabase);

    // İlk açılışta mevcut user'ı al
    _user = supabase.auth.currentUser;
    if (_user != null) {
      _loadCurrentUserProfilePhoto();
    }

    // Auth değişimlerini dinle (login/logout olunca ikon değişsin)
    _authSub = supabase.auth.onAuthStateChange.listen((data) {
      setState(() {
        _user = data.session?.user;
      });

      // kullanıcı değiştiyse profil foto url'ini çek
      if (_user != null) {
        _loadCurrentUserProfilePhoto();
      } else {
        setState(() => _profilePhotoUrl = null);
      }
    });
  }

  Future<void> _loadCurrentUserProfilePhoto() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final row = await supabase
          .from('kullanici')
          .select('profil_fotograf_url')
          .eq('kullaniciid', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = (row?['profil_fotograf_url'] as String?);
      });
    } catch (_) {
      // sessiz geç (RLS/row yoksa bile app çalışsın)
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saklı Kent🗺️ '),
        actions: [
          if (_user == null)
            IconButton(
              tooltip: 'Giriş Yap',
              icon: const Icon(Icons.login),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(userId: _user!.id),
                    ),
                  ).then((_) => _loadCurrentUserProfilePhoto());
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                      ? NetworkImage(_profilePhotoUrl!)
                      : null,
                  child: (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Çıkış Yap',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await supabase.auth.signOut();
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Çıkış yapıldı')));
              },
            ),
          ],
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        //stream sayesinde dinamik bir görünüm elde ediyoruz. mekan eklediğimizde direkt olarak sayfada görünme işlemini stream yapıyor.
        stream: supabase
            .from('mekan')
            .stream(
              primaryKey: ['id'],
            ) //PK yı kontrol ederek neyin değişiştiğini anlıyor
            .order('olusturmatarihi', ascending: false),

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
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final m = mekanlar[i];
              final id = m['id'].toString();
              final ad = (m['mekanadi'] ?? '').toString();
              final sehir = (m['sehir'] ?? '').toString();
              final aciklama = (m['aciklama'] ?? '').toString();
              final butce = m['butceseviyesi'];
              final kapakUrl = (m['kapak_fotograf_url'] ?? '').toString();

              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MekanDetayPage(mekanId: id),
                      ),
                    );
                  },

                  // ✅ FOTOĞRAF (solda thumbnail)
                  leading: (kapakUrl.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            kapakUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackThumb(),
                          ),
                        )
                      : _fallbackThumb(),

                  title: Text(ad),
                  subtitle: Text(
                    [
                      if (sehir.isNotEmpty) sehir,
                      if (aciklama.isNotEmpty) aciklama,
                      if (butce != null) 'Bütçe: $butce/5',
                    ].join(' • '),
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mekan eklemek için önce giriş yapmalısın.'),
              ),
            );
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
            return;
          }

          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMekanPage()),
          );
          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('Mekan Ekle'),
      ),
    );
  }
}

Widget _fallbackThumb() {
  return Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Icon(Icons.image_outlined),
  );
}
