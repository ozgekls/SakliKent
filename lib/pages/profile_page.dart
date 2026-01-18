import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'visited_list_page.dart';
import 'saved_list_page.dart';
import 'my_places_page.dart';

final supabase = Supabase.instance.client;

class ProfilePage extends StatefulWidget {
  final String userId; // hangi kullanıcının profili
  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  String? _error;

  String _username = 'Kullanıcı';
  String _email = '';

  int _ziyaretCount = 0;
  int _kaydetCount = 0;
  int _ekledikCount = 0;

  bool get _isOwnProfile =>
      supabase.auth.currentUser != null &&
      supabase.auth.currentUser!.id == widget.userId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userRow = await supabase
          .from('kullanici')
          .select('kullaniciadi, email')
          .eq('kullaniciid', widget.userId)
          .single();

      _username = (userRow['kullaniciadi'] ?? 'Kullanıcı').toString();
      _email = (userRow['email'] ?? '').toString();

      // B) ZİYARET SAYISI
      final ziyaretRows = await supabase
          .from('ziyaretler')
          .select('id')
          .eq('kullaniciid', widget.userId);
      _ziyaretCount = (ziyaretRows as List).length;

      // C) KAYDEDİLENLER (sadece kendi profili)
      if (_isOwnProfile) {
        final kaydetRows = await supabase
            .from('kaydedilenler')
            .select('mekanid')
            .eq('kullaniciid', widget.userId);
        _kaydetCount = (kaydetRows as List).length;

        // D) EKLEDİĞİM MEKANLAR
        final ekledikRows = await supabase
            .from('mekan')
            .select('id')
            .eq('ekleyenkullaniciid', widget.userId);
        _ekledikCount = (ekledikRows as List).length;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Hata: $_error'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(),
                const SizedBox(height: 18),
                _sectionTitle('Listelerim'),

                _listTile(
                  icon: Icons.check_circle,
                  title: 'Ziyaret Ettiklerim',
                  subtitle: '$_ziyaretCount mekan',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VisitedListPage(userId: widget.userId),
                      ),
                    );
                  },
                ),

                // private olanlar sadece kendi profilde
                _listTile(
                  icon: Icons.bookmark,
                  title: 'Gitmek İstediklerim',
                  subtitle: _isOwnProfile ? '$_kaydetCount mekan' : 'Gizli',
                  locked: !_isOwnProfile,
                  onTap: !_isOwnProfile
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  SavedListPage(userId: widget.userId),
                            ),
                          );
                        },
                ),

                _listTile(
                  icon: Icons.add_location_alt,
                  title: 'Eklediğim Mekanlar',
                  subtitle: _isOwnProfile ? '$_ekledikCount mekan' : 'Gizli',
                  locked: !_isOwnProfile,
                  onTap: !_isOwnProfile
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MyPlacesPage(userId: widget.userId),
                            ),
                          );
                        },
                ),
              ],
            ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        CircleAvatar(
          radius: 42,
          child: Text(
            _username.isEmpty ? '?' : _username[0].toUpperCase(),
            style: const TextStyle(fontSize: 28),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _username,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(_email, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );

  Widget _listTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool locked = false,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: locked
            ? const Icon(Icons.lock, size: 18)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
