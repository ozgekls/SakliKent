import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'visited_list_page.dart';
import 'saved_list_page.dart';
import 'my_places_page.dart';

final supabase = Supabase.instance.client;

class ProfilePage extends StatefulWidget {
  /// null ise currentUser profili
  final String? userId;
  const ProfilePage({super.key, this.userId});

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

  // ✅ Profil foto
  String? _profilFotoUrl;
  bool _photoSaving = false;

  // Web/desktop için seçilen dosya önizleme
  File? _pickedFile;
  Uint8List? _pickedBytes;

  StreamSubscription<AuthState>? _authSub;

  String? get _effectiveUserId =>
      widget.userId ?? supabase.auth.currentUser?.id;

  bool get _isOwnProfile {
    final cu = supabase.auth.currentUser;
    final uid = _effectiveUserId;
    return cu != null && uid != null && cu.id == uid;
  }

  @override
  void initState() {
    super.initState();

    _authSub = supabase.auth.onAuthStateChange.listen((_) {
      _loadProfile();
    });

    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = _effectiveUserId;

    // logout / guest
    if (uid == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _username = 'Misafir';
        _email = 'Giriş yapmadın';
        _ziyaretCount = 0;
        _kaydetCount = 0;
        _ekledikCount = 0;
        _profilFotoUrl = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userRow = await supabase
          .from('kullanici')
          .select('kullaniciadi, email, profil_fotograf_url')
          .eq('kullaniciid', uid)
          .maybeSingle();

      if (userRow == null) {
        throw 'Kullanıcı kaydı bulunamadı (kullanici tablosu).';
      }

      _username = (userRow['kullaniciadi'] ?? 'Kullanıcı').toString();
      _email = (userRow['email'] ?? '').toString();
      _profilFotoUrl = (userRow['profil_fotograf_url'] as String?)?.trim();

      final ziyaretRows = await supabase
          .from('ziyaretler')
          .select('id')
          .eq('kullaniciid', uid);
      _ziyaretCount = (ziyaretRows as List).length;

      if (_isOwnProfile) {
        final kaydetRows = await supabase
            .from('kaydedilenler')
            .select('mekanid')
            .eq('kullaniciid', uid);
        _kaydetCount = (kaydetRows as List).length;

        final ekledikRows = await supabase
            .from('mekan')
            .select('id')
            .eq('ekleyenkullaniciid', uid);
        _ekledikCount = (ekledikRows as List).length;
      } else {
        _kaydetCount = 0;
        _ekledikCount = 0;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ Foto seç
  Future<void> _pickProfilePhoto() async {
    if (!_isOwnProfile) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedBytes = bytes;
        _pickedFile = null;
      });
    } else {
      setState(() {
        _pickedFile = File(picked.path);
        _pickedBytes = null;
      });
    }

    await _uploadAndSaveProfilePhoto();
  }

  Future<void> _uploadAndSaveProfilePhoto() async {
    final uid = _effectiveUserId;
    if (uid == null) return;

    if (!kIsWeb && _pickedFile == null) return;
    if (kIsWeb && _pickedBytes == null) return;

    setState(() => _photoSaving = true);

    try {
      final rand = Random().nextInt(1 << 32);
      final path =
          'profil/$uid/${DateTime.now().microsecondsSinceEpoch}_$rand.jpg';

      if (kIsWeb) {
        await supabase.storage.from('images').uploadBinary(path, _pickedBytes!);
      } else {
        await supabase.storage.from('images').upload(path, _pickedFile!);
      }

      final url = supabase.storage.from('images').getPublicUrl(path);

      // DB update
      await supabase
          .from('kullanici')
          .update({'profil_fotograf_url': url})
          .eq('kullaniciid', uid);

      if (!mounted) return;
      setState(() {
        _profilFotoUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafı güncellendi ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf güncellenemedi: $e')));
    } finally {
      if (mounted) setState(() => _photoSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _effectiveUserId;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: Center(child: Text('Hata: $_error')),
      );
    }

    // guest
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Profilini görmek için giriş yapmalısın.'),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
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
                MaterialPageRoute(builder: (_) => VisitedListPage(userId: uid)),
              );
            },
          ),

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
                        builder: (_) => SavedListPage(userId: uid),
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
                        builder: (_) => MyPlacesPage(userId: uid),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final hasUrl = (_profilFotoUrl != null && _profilFotoUrl!.isNotEmpty);

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 46,
              backgroundImage: hasUrl ? NetworkImage(_profilFotoUrl!) : null,
              child: !hasUrl
                  ? Text(
                      _username.isEmpty ? '?' : _username[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28),
                    )
                  : null,
            ),

            // ✅ sadece kendi profilinde foto değiştir butonu
            if (_isOwnProfile)
              InkWell(
                onTap: _photoSaving ? null : _pickProfilePhoto,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: _photoSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.white,
                        ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),
        Text(
          _username,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(_email, style: const TextStyle(color: Colors.black54)),

        if (_isOwnProfile) ...[
          const SizedBox(height: 10),
          Text(
            'Profil fotoğrafını değiştirmek için kameraya dokun',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.55),
            ),
          ),
        ],
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
