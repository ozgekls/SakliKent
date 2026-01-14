/*import 'package:flutter/material.dart';
import 'supabase_config.dart';
import 'screens/auth_screen.dart';
import 'services/mekan_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const SakliKentApp());
}

class SakliKentApp extends StatelessWidget {
  const SakliKentApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFB9A7FF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saklı Kent',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF6F6FB),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F2F8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      routes: {
        '/': (_) => const _AuthWrapper(),
        '/home': (_) => const Shell(),
        '/auth': (_) => const AuthScreen(),
      },
    );
  }
}

class _AuthWrapper extends StatelessWidget {
  const _AuthWrapper();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SupabaseConfig.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = SupabaseConfig.client.auth.currentSession;
        if (session != null) {
          return const Shell();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}

/// -----------------------------
/// SHELL (FANCY TOP BAR + BOTTOM NAV)
/// -----------------------------
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  final pages = const [
    DashboardPage(),
    PlacesPage(),
    MyListsPage(),
    ProfilePage(),
  ];

  String get _title {
    switch (index) {
      case 0:
        return 'Saklı Kent';
      case 1:
        return 'Keşfet';
      case 2:
        return 'Listelerim';
      case 3:
        return 'Profil';
      default:
        return 'Saklı Kent';
    }
  }

  String? get _subtitle {
    switch (index) {
      case 0:
        return 'Şehrin gizli kalmış incileri';
      case 1:
        return 'Filtrele • Ara • Kaydet';
      case 2:
        return 'Kaydettiğin mekanlar';
      case 3:
        return 'Hesabın ve ayarlar';
      default:
        return null;
    }
  }

  List<Widget> get _actions {
    switch (index) {
      case 0:
        return [
          IconButton(
            tooltip: 'Bildirimler',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ];
      case 1:
        return [
          IconButton(
            tooltip: 'Ara',
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
          ),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FancyTopBar(
        title: _title,
        subtitle: _subtitle,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withAlpha((0.70 * 255).round()),
          child: const Icon(Icons.location_city_rounded, size: 18),
        ),
        actions: _actions
            .map(
              (w) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _TopIconButton(child: w),
              ),
            )
            .toList(),
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_rounded),
            label: 'Anasayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_rounded),
            label: 'Keşfet',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_rounded),
            label: 'Listelerim',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

/// -----------------------------
/// FANCY TOP BAR
/// -----------------------------
class FancyTopBar extends StatelessWidget implements PreferredSizeWidget {
  const FancyTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(86);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withAlpha((0.22 * 255).round()),
            Colors.white.withAlpha((0.00 * 255).round()),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.70 * 255).round()),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// -----------------------------
/// DASHBOARD
/// -----------------------------
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Headline(
              title: 'Bugün ne keşfediyoruz?',
              subtitle: 'Şehrin gözden kaçan noktalarını birlikte bulalım.',
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(
                  child: _StatTile(
                    title: 'Toplam Mekan',
                    value: '487',
                    icon: Icons.location_on_rounded,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    title: 'Bu Hafta Eklenen',
                    value: '23',
                    icon: Icons.bolt_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(
                  child: _StatTile(
                    title: 'Ziyaret Ettim',
                    value: '34',
                    icon: Icons.check_circle_rounded,
                    iconColor: Colors.green,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    title: 'Listemde',
                    value: '18',
                    icon: Icons.bookmark_rounded,
                    iconColor: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Hızlı İşlemler',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickAction(
                  label: 'Yeni Mekan',
                  icon: Icons.add_location_rounded,
                  onTap: () => _openNewPlaceSheet(context),
                ),
                _QuickAction(
                  label: 'Arama',
                  icon: Icons.search_rounded,
                  onTap: () {},
                ),
                _QuickAction(
                  label: 'Filtre',
                  icon: Icons.filter_list_rounded,
                  onTap: () {},
                ),
                _QuickAction(
                  label: 'Harita',
                  icon: Icons.map_rounded,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Son Aktiviteler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Tümünü gör',
                    style: TextStyle(color: cs.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                children: const [
                  _ActivityTile(
                    title: 'Mert "Saklı Bahçe" mekanını ekledi',
                    subtitle: '2 dk önce • Kadıköy',
                    icon: Icons.add_location_rounded,
                  ),
                  _ActivityTile(
                    title: 'Zeynep "Seyir Noktası" mekanını ziyaret etti',
                    subtitle: '18 dk önce • Şişli',
                    icon: Icons.check_circle_rounded,
                  ),
                  _ActivityTile(
                    title: 'Ali "Küçük Sahne" için yorum yaptı',
                    subtitle: '1 saat önce • Beyoğlu',
                    icon: Icons.comment_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------
/// KEŞFET (ANA MEKAN LİSTESİ)
/// -----------------------------
class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> with TickerProviderStateMixin {
  late final TabController tab;

  String categoryFilter = 'Tümü';
  String tagFilter = 'Tümü';
  final searchController = TextEditingController();

  List<Map<String, dynamic>> mekanlar = [];
  bool isLoading = true;

  final categories = const [
    _Filter('Tümü', icon: '✨'),
    _Filter('Doğa', icon: '🌿'),
    _Filter('Sanat & Kültür', icon: '🎭'),
    _Filter('Çalışma', icon: '💻'),
    _Filter('Güvenli Alan', icon: '💜'),
  ];

  final tags = const [
    _Filter('Tümü', icon: '✨'),
    _Filter('En Çok Beğeni', icon: '❤️'),
    _Filter('En Çok Yorum', icon: '💬'),
    _Filter('Manzara', icon: '🌅'),
    _Filter('Sessiz', icon: '🤫'),
    _Filter('Ulaşım Kolay', icon: '🚇'),
    _Filter('Bütçe', icon: '💰'),
  ];

  @override
  void initState() {
    super.initState();
    tab = TabController(length: 2, vsync: this);
    searchController.addListener(() => setState(() {}));
    _loadMekanlar();
  }

  @override
  void dispose() {
    tab.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMekanlar() async {
    setState(() => isLoading = true);
    try {
      final data = await MekanService.getMekanlar();
      setState(() {
        mekanlar = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final places = mekanlar.map((m) {
      return Place(
        id: m['id'],
        title: m['MekanAdi'] ?? 'İsimsiz Mekan',
        location: m['Sehir'] ?? 'Bilinmeyen',
        photoUrl: (m['Fotograf'] as List?)?.isNotEmpty == true
            ? m['Fotograf'][0]['FotografURL']
            : '',
        addedBy: m['Kullanici']?['KullaniciAdi'] ?? 'Anonim',
        addedDate: DateTime.parse(m['OlusturmaTarihi']),
        rating: 4.5,
        totalVisits: 0,
        totalComments: 0,
        description: m['Aciklama'] ?? '',
        mainCategory: 'Genel',
        interestFactors: [],
        tags: [],
        comments: [],
      );
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewPlaceSheet(context, onSuccess: _loadMekanlar),
        icon: const Icon(Icons.add_location_rounded),
        label: const Text('Yeni Mekan'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Headline(
                    title: 'Gizli kalan yerleri bul',
                    subtitle: 'Filtrele, ara, kaydet — sonra da keşfe çık.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Mekan ara (isim / ilçe / etiket)...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: (searchController.text.isEmpty)
                          ? null
                          : IconButton(
                              onPressed: () =>
                                  setState(() => searchController.clear()),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                controller: tab,
                isScrollable: true,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: '🔥 Popüler'),
                  Tab(text: '🆕 Yeni Eklenenler'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, i) {
                  final f = categories[i];
                  final selected = categoryFilter == f.label;
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() => categoryFilter = f.label),
                    label: Text('${f.icon}  ${f.label}'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    selectedColor: cs.primary.withAlpha((0.22 * 255).round()),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.black : Colors.black87,
                    ),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemCount: categories.length,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, i) {
                  final f = tags[i];
                  final selected = tagFilter == f.label;
                  return ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() => tagFilter = f.label),
                    label: Text('${f.icon}  ${f.label}'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    selectedColor: cs.secondary.withAlpha((0.22 * 255).round()),
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.black : Colors.black87,
                    ),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemCount: tags.length,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: tab,
                children: [
                  _PlaceList(
                    items: _applyFilters(
                      List<Place>.from(
                        places,
                      )..sort((a, b) => b.totalVisits.compareTo(a.totalVisits)),
                    ),
                    onTap: (p) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlaceDetailPage(place: p),
                      ),
                    ),
                  ),
                  _PlaceList(
                    items: _applyFilters(
                      List<Place>.from(places)
                        ..sort((a, b) => b.addedDate.compareTo(a.addedDate)),
                    ),
                    onTap: (p) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlaceDetailPage(place: p),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Place> _applyFilters(List<Place> input) {
    var result = input;

    final q = searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where(
            (p) =>
                p.title.toLowerCase().contains(q) ||
                p.location.toLowerCase().contains(q) ||
                p.tags.any((t) => t.toLowerCase().contains(q)),
          )
          .toList();
    }

    if (categoryFilter != 'Tümü') {
      result = result.where((p) => p.mainCategory == categoryFilter).toList();
    }

    if (tagFilter != 'Tümü') {
      if (tagFilter == 'En Çok Beğeni') {
        result.sort((a, b) => b.totalVisits.compareTo(a.totalVisits));
      } else if (tagFilter == 'En Çok Yorum') {
        result.sort((a, b) => b.totalComments.compareTo(a.totalComments));
      } else {
        result = result.where((p) => p.tags.contains(tagFilter)).toList();
      }
    }

    return result;
  }
}

/// -----------------------------
/// PLACE LIST + CARD
/// -----------------------------
class _PlaceList extends StatelessWidget {
  const _PlaceList({required this.items, required this.onTap});

  final List<Place> items;
  final void Function(Place place) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('Sonuç bulunamadı.'));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final p = items[i];
        final daysAgo = DateTime.now().difference(p.addedDate).inDays;
        final timeText = daysAgo == 0
            ? 'Bugün'
            : daysAgo == 1
            ? '1 gün önce'
            : '$daysAgo gün önce';

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onTap(p),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFEDEBFF),
                        child: Text(
                          p.addedBy.isNotEmpty
                              ? p.addedBy.characters.first.toUpperCase()
                              : '?',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.addedBy,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeText,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(
                            p.mainCategory,
                          ).withAlpha((0.15 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          p.mainCategory,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _getCategoryColor(p.mainCategory),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 190,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9E8EE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: p.photoUrl.isEmpty
                      ? const Center(
                          child: Icon(Icons.photo_camera_rounded, size: 40),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(p.photoUrl, fit: BoxFit.cover),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              p.location,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            p.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.description,
                        style: const TextStyle(
                          color: Colors.black87,
                          height: 1.25,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: p.interestFactors.take(3).map((factor) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F2F8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              factor,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.favorite_border_rounded, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '${p.totalVisits} beğeni',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${p.totalComments} yorum',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.bookmark_border_rounded, size: 22),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Doğa':
        return Colors.green;
      case 'Sanat & Kültür':
        return Colors.deepPurple;
      case 'Çalışma':
        return Colors.blue;
      case 'Güvenli Alan':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

/// -----------------------------
/// PLACE DETAIL
/// -----------------------------
class PlaceDetailPage extends StatefulWidget {
  const PlaceDetailPage({super.key, required this.place});
  final Place place;

  @override
  State<PlaceDetailPage> createState() => _PlaceDetailPageState();
}

class _PlaceDetailPageState extends State<PlaceDetailPage> {
  bool hasVisited = false;
  bool isInWishlist = false;
  final commentController = TextEditingController();

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.place.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.place.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withAlpha((0.15 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.place.mainCategory,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.place.location,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        size: 18,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.place.rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 240,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9E8EE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: widget.place.photoUrl.isEmpty
                        ? const Center(
                            child: Icon(Icons.photo_camera_rounded, size: 44),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              widget.place.photoUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.place.description,
                    style: const TextStyle(height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'İlgi Çeken Etkenler',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.place.interestFactors
                        .map(
                          (factor) => Chip(
                            label: Text(factor),
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            backgroundColor: const Color(0xFFF3F2F8),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Ekleyen: ${widget.place.addedBy}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () {
                            setState(() => hasVisited = !hasVisited);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  hasVisited
                                      ? 'Ziyaret edildi olarak işaretlendi'
                                      : 'Ziyaret işareti kaldırıldı',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: hasVisited
                                ? Colors.green.withAlpha((0.2 * 255).round())
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                hasVisited
                                    ? Icons.check_circle_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Ziyaret Ettim',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () {
                            setState(() => isInWishlist = !isInWishlist);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isInWishlist
                                      ? 'Listene eklendi'
                                      : 'Listenden çıkarıldı',
                                ),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: isInWishlist
                                ? Colors.orange.withAlpha((0.2 * 255).round())
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isInWishlist
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Listeye Ekle',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Yorumlar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withAlpha((0.15 * 255).round()),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.place.totalComments}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasVisited) ...[
                    TextField(
                      controller: commentController,
                      decoration: InputDecoration(
                        hintText: 'Deneyimini paylaş...',
                        suffixIcon: IconButton(
                          onPressed: () {
                            if (commentController.text.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Yorum eklendi!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                              commentController.clear();
                            }
                          },
                          icon: const Icon(Icons.send_rounded),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F2F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline_rounded, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Yorum yapabilmek için önce mekanı ziyaret etmiş olmalısın.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (widget.place.comments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Henüz yorum yok. İlk sen ol!',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    )
                  else
                    ...widget.place.comments.map(
                      (comment) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFEDEBFF),
                              child: Text(
                                comment.author.characters.first.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.author,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (comment.hasVisited)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: Colors.green,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comment.text,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      height: 1.3,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCommentDate(comment.date),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCommentDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays} gün önce';
    if (diff.inHours > 0) return '${diff.inHours} saat önce';
    if (diff.inMinutes > 0) return '${diff.inMinutes} dakika önce';
    return 'Şimdi';
  }
}

/// -----------------------------
/// NEW PLACE SHEET
/// -----------------------------
void _openNewPlaceSheet(BuildContext context, {VoidCallback? onSuccess}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NewPlaceSheet(onSuccess: onSuccess),
  );
}

class _NewPlaceSheet extends StatefulWidget {
  const _NewPlaceSheet({this.onSuccess});

  final VoidCallback? onSuccess;

  @override
  State<_NewPlaceSheet> createState() => _NewPlaceSheetState();
}

class _NewPlaceSheetState extends State<_NewPlaceSheet> {
  final nameController = TextEditingController();
  final photoUrlController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();

  String mainCategory = 'Doğa';
  int rating = 4;

  final categories = const [
    'Doğa',
    'Sanat & Kültür',
    'Çalışma',
    'Güvenli Alan',
  ];

  final allFactors = const [
    'Sessiz',
    'Manzara',
    'Ulaşım Kolay',
    'Çalışmaya Uygun',
    'Güvenli',
    'Temiz',
    'Huzurlu',
    'Yürüyüş İçin İyi',
    'Fotoğraf',
    'Atmosfer',
    'Kalabalık Değil',
    'Aydınlık',
    'Engelsiz Erişim',
  ];

  List<String> selectedFactors = [];

  @override
  void dispose() {
    nameController.dispose();
    photoUrlController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Yeni Mekan Ekle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Mekan Adı *',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'Örn: Yeşil Patika',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fotoğraf URL',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: photoUrlController,
                  decoration: const InputDecoration(hintText: 'https://...'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Konum *',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    hintText: 'Örn: Kadıköy, İstanbul',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kategori *',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: mainCategory,
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => mainCategory = v ?? mainCategory),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: Color(0xFFF3F2F8),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Değerlendirme *',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) {
                    final idx = i + 1;
                    final filled = idx <= rating;
                    return IconButton(
                      onPressed: () => setState(() => rating = idx),
                      icon: Icon(
                        filled ? Icons.star_rounded : Icons.star_border_rounded,
                        color: filled ? Colors.amber : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Etkenler * (En az 1, en çok 5)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allFactors.map((factor) {
                    final selected = selectedFactors.contains(factor);
                    return FilterChip(
                      selected: selected,
                      label: Text(factor),
                      onSelected: (isSelected) {
                        setState(() {
                          if (isSelected && selectedFactors.length < 5) {
                            selectedFactors.add(factor);
                          } else if (!isSelected) {
                            selectedFactors.remove(factor);
                          }
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: cs.primary.withAlpha((0.18 * 255).round()),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: selected ? cs.primary : Colors.grey.shade300,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Deneyimini Paylaş *',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Bu mekan hakkında kısa ama faydalı bir not yaz...',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          if (nameController.text.isEmpty ||
                              locationController.text.isEmpty ||
                              selectedFactors.isEmpty ||
                              descriptionController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Lütfen zorunlu alanları doldurun!',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          try {
                            await MekanService.addMekan(
                              mekanAdi: nameController.text.trim(),
                              sehir: locationController.text.trim(),
                              aciklama: descriptionController.text.trim(),
                              butceSeviyesi: rating,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Mekan başarıyla eklendi!'),
                                  backgroundColor: Colors.green,
                                ),
                              );

                              widget.onSuccess?.call();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Hata: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Kaydet',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'İptal',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// -----------------------------
/// MY LISTS PAGE
/// -----------------------------
class MyListsPage extends StatelessWidget {
  const MyListsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Headline(
              title: 'Listelerin',
              subtitle: 'Kaydettiğin ve takip ettiğin mekanlar burada.',
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                children: [
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEDEBFF),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                        ),
                      ),
                      title: const Text(
                        'Ziyaret Ettiklerim',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('34 mekan'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEDEBFF),
                        child: Icon(
                          Icons.bookmark_rounded,
                          color: Colors.orange,
                        ),
                      ),
                      title: const Text(
                        'Gitmek İstediklerim',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('18 mekan'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEDEBFF),
                        child: Icon(
                          Icons.add_location_rounded,
                          color: Colors.blue,
                        ),
                      ),
                      title: const Text(
                        'Eklediklerim',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('7 mekan'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------
/// PROFILE PAGE
/// -----------------------------
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SupabaseConfig.client.auth.currentUser;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Headline(
              title: 'Hesabın',
              subtitle: 'Profil ve uygulama ayarlarını yönet.',
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFFEDEBFF),
                    child: Icon(Icons.person_rounded, size: 50),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.userMetadata?['username'] ?? 'Kullanıcı',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'email@example.com',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.settings_rounded),
                      title: const Text('Ayarlar'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.help_outline_rounded),
                      title: const Text('Yardım'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('Hakkında'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.logout_rounded,
                        color: Colors.red,
                      ),
                      title: const Text(
                        'Çıkış Yap',
                        style: TextStyle(color: Colors.red),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        await SupabaseConfig.client.auth.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed('/auth');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------
/// SMALL UI PARTS
/// -----------------------------
class _Headline extends StatelessWidget {
  const _Headline({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: cs.primary.withAlpha((0.14 * 255).round()),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor ?? cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEDEBFF),
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _Filter {
  const _Filter(this.label, {required this.icon});
  final String label;
  final String icon;
}

/// -----------------------------
/// MODELS
/// -----------------------------
class Place {
  final String id;
  final String title;
  final String location;
  final String photoUrl;
  final String addedBy;
  final DateTime addedDate;
  final double rating;
  final int totalVisits;
  final int totalComments;
  final String description;
  final String mainCategory;
  final List<String> interestFactors;
  final List<String> tags;
  final List<Comment> comments;

  Place({
    required this.id,
    required this.title,
    required this.location,
    required this.photoUrl,
    required this.addedBy,
    required this.addedDate,
    required this.rating,
    required this.totalVisits,
    required this.totalComments,
    required this.description,
    required this.mainCategory,
    required this.interestFactors,
    required this.tags,
    required this.comments,
  });
}

class Comment {
  final String author;
  final String text;
  final DateTime date;
  final bool hasVisited;

  Comment({
    required this.author,
    required this.text,
    required this.date,
    required this.hasVisited,
  });
}
*/
