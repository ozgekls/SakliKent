import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart'; // Mekanlar sayfan (liste)
import 'profile_page.dart'; // Profil sayfan
// import 'kesfet_page.dart';   // varsa ekle, yoksa placeholder kullanacağız

final supabase = Supabase.instance.client;

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 1; // app açılınca Mekanlar seçili gelsin (istersen 0 yap)

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    final pages = <Widget>[
      const _KesfetPlaceholder(),
      const HomePage(),
      // giriş yoksa bile profil açılabilir; içeride "giriş yap" gösterebilirsin
      ProfilePage(userId: user?.id ?? ''), // user yoksa boş string
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Mekanlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _KesfetPlaceholder extends StatelessWidget {
  const _KesfetPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Keşfet sayfası (sonra yapacağız)'));
  }
}
