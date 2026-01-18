import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_mekan_page.dart';
import 'mekan_detay_page.dart';
import 'login_page.dart';
import 'models/mekan.dart';
import 'services/mekan_service.dart';

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

  @override
  void initState() {
    super.initState();
    _service = MekanService(supabase);

    // İlk açılışta mevcut user'ı al
    _user = supabase.auth.currentUser;

    // Auth değişimlerini dinle (login/logout olunca ikon değişsin)
    _authSub = supabase.auth.onAuthStateChange.listen((data) {
      setState(() {
        _user = data.session?.user;
      });
    });
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
        title: const Text('Saklı Kent'),
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
          else
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
      ),

      body: StreamBuilder<List<Mekan>>(
        stream: _service.streamMekanlar(),
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
              return Card(
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MekanDetayPage(mekanId: m.id),
                      ),
                    );
                  },
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
