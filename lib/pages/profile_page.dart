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

  // ✅ YENİ: Takip istatistikleri
  int _takipEdilenSayisi = 0; // Bu kişiyi kaç kişi takip ediyor
  int _takipEttigiSayisi = 0; // Bu kişi kaç kişiyi takip ediyor
  bool _benTakipEdiyorum = false; // Ben bu kişiyi takip ediyor muyum?
  bool _takipLoading = false;

  String? _profilFotoUrl;
  bool _photoSaving = false;

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
        _takipEdilenSayisi = 0;
        _takipEttigiSayisi = 0;
        _profilFotoUrl = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ✅ YENİ: Takip istatistikleriyle birlikte kullanıcı bilgisi
      final userRow = await supabase
          .from('v_kullanici_takip_istatistik')
          .select()
          .eq('kullaniciid', uid)
          .maybeSingle();

      if (userRow == null) {
        throw 'Kullanıcı kaydı bulunamadı.';
      }

      _username = (userRow['kullaniciadi'] ?? 'Kullanıcı').toString();
      _email = (userRow['email'] ?? '').toString();
      _profilFotoUrl = (userRow['profil_fotograf_url'] as String?)?.trim();

      // ✅ Takip sayıları
      _takipEdilenSayisi = (userRow['takip_edilen_sayisi'] ?? 0) as int;
      _takipEttigiSayisi = (userRow['takip_ettigi_sayisi'] ?? 0) as int;

      // Mekan istatistikleri (view'dan geliyor)
      _ziyaretCount = (userRow['ziyaret_sayisi'] ?? 0) as int;
      _ekledikCount = (userRow['eklenen_mekan_sayisi'] ?? 0) as int;

      // Kaydetme sadece kendi profilinde
      if (_isOwnProfile) {
        final kaydetRows = await supabase
            .from('kaydedilenler')
            .select('mekanid')
            .eq('kullaniciid', uid);
        _kaydetCount = (kaydetRows as List).length;
      } else {
        _kaydetCount = 0;
      }

      // ✅ YENİ: Ben bu kişiyi takip ediyor muyum?
      if (!_isOwnProfile) {
        final myId = supabase.auth.currentUser?.id;
        if (myId != null) {
          final takipRow = await supabase
              .from('takipler')
              .select('id')
              .eq('takip_eden_id', myId)
              .eq('takip_edilen_id', uid)
              .maybeSingle();

          _benTakipEdiyorum = takipRow != null;
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ YENİ: Takip et/bırak
  Future<void> _toggleTakip() async {
    final myId = supabase.auth.currentUser?.id;
    final targetId = _effectiveUserId;

    if (myId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Takip etmek için giriş yapmalısın')),
      );
      return;
    }

    if (targetId == null || _isOwnProfile) return;

    setState(() => _takipLoading = true);

    try {
      if (_benTakipEdiyorum) {
        // Takibi bırak
        await supabase
            .from('takipler')
            .delete()
            .eq('takip_eden_id', myId)
            .eq('takip_edilen_id', targetId);

        if (mounted) {
          setState(() {
            _benTakipEdiyorum = false;
            _takipEdilenSayisi = (_takipEdilenSayisi - 1).clamp(0, 999999);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$_username takipten çıkarıldı')),
          );
        }
      } else {
        // Takip et
        await supabase.from('takipler').insert({
          'takip_eden_id': myId,
          'takip_edilen_id': targetId,
        });

        if (mounted) {
          setState(() {
            _benTakipEdiyorum = true;
            _takipEdilenSayisi++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$_username takip ediliyor ✅')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    } finally {
      if (mounted) setState(() => _takipLoading = false);
    }
  }

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

  // ✅ YENİ: Takipçiler listesi sayfası
  void _openTakipcilerPage() {
    final uid = _effectiveUserId;
    if (uid == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TakipcilerPage(userId: uid, userName: _username),
      ),
    );
  }

  // ✅ YENİ: Takip edilenler listesi sayfası
  void _openTakipEdilenlerPage() {
    final uid = _effectiveUserId;
    if (uid == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TakipEdilenlerPage(userId: uid, userName: _username),
      ),
    );
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

          // ✅ YENİ: Takip istatistikleri
          _buildTakipStats(),

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

        // ✅ YENİ: Takip butonu (başka kullanıcının profilindeyse)
        if (!_isOwnProfile) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _takipLoading ? null : _toggleTakip,
              icon: Icon(
                _benTakipEdiyorum
                    ? Icons.person_remove_outlined
                    : Icons.person_add_outlined,
                size: 20,
              ),
              label: Text(
                _benTakipEdiyorum ? 'Takipten Çık' : 'Takip Et',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _benTakipEdiyorum
                    ? Colors.grey.shade300
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: _benTakipEdiyorum ? Colors.black87 : null,
              ),
            ),
          ),
        ],

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

  // ✅ YENİ: Takip istatistikleri widget
  Widget _buildTakipStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.people_outline,
            title: 'Takipçi',
            value: _takipEdilenSayisi,
            onTap: _openTakipcilerPage,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            icon: Icons.person_add_outlined,
            title: 'Takip',
            value: _takipEttigiSayisi,
            onTap: _openTakipEdilenlerPage,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required int value,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, size: 28, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
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

// ============================================
// ✅ YENİ: TAKİPÇİLER SAYFASI
// ============================================
class TakipcilerPage extends StatefulWidget {
  final String userId;
  final String userName;

  const TakipcilerPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<TakipcilerPage> createState() => _TakipcilerPageState();
}

class _TakipcilerPageState extends State<TakipcilerPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _takipciler = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Bu kullanıcıyı takip edenleri getir
      final data = await supabase
          .from('v_takip_listesi')
          .select()
          .eq('takip_edilen_kullanici_id', widget.userId)
          .order('takip_tarihi', ascending: false);

      _takipciler = (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.userName} - Takipçiler')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Hata: $_error'))
          : _takipciler.isEmpty
          ? const Center(child: Text('Henüz takipçi yok'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _takipciler.length,
              itemBuilder: (context, i) {
                final t = _takipciler[i];
                final userId = (t['takip_eden_kullanici_id'] ?? '').toString();
                final userName = (t['takip_eden_adi'] ?? 'Kullanıcı')
                    .toString();
                final userFoto = t['takip_eden_foto'] as String?;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (userFoto != null && userFoto.isNotEmpty)
                          ? NetworkImage(userFoto)
                          : null,
                      child: (userFoto == null || userFoto.isEmpty)
                          ? Text(userName[0].toUpperCase())
                          : null,
                    ),
                    title: Text(userName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfilePage(userId: userId),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ============================================
// ✅ YENİ: TAKİP EDİLENLER SAYFASI
// ============================================
class TakipEdilenlerPage extends StatefulWidget {
  final String userId;
  final String userName;

  const TakipEdilenlerPage({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<TakipEdilenlerPage> createState() => _TakipEdilenlerPageState();
}

class _TakipEdilenlerPageState extends State<TakipEdilenlerPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _takipEdilenler = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Bu kullanıcının takip ettiklerini getir
      final data = await supabase
          .from('v_takip_listesi')
          .select()
          .eq('takip_eden_kullanici_id', widget.userId)
          .order('takip_tarihi', ascending: false);

      _takipEdilenler = (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.userName} - Takip Edilenler')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Hata: $_error'))
          : _takipEdilenler.isEmpty
          ? const Center(child: Text('Henüz kimseyi takip etmiyor'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _takipEdilenler.length,
              itemBuilder: (context, i) {
                final t = _takipEdilenler[i];
                final userId = (t['takip_edilen_kullanici_id'] ?? '')
                    .toString();
                final userName = (t['takip_edilen_adi'] ?? 'Kullanıcı')
                    .toString();
                final userFoto = t['takip_edilen_foto'] as String?;

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (userFoto != null && userFoto.isNotEmpty)
                          ? NetworkImage(userFoto)
                          : null,
                      child: (userFoto == null || userFoto.isEmpty)
                          ? Text(userName[0].toUpperCase())
                          : null,
                    ),
                    title: Text(userName),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfilePage(userId: userId),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
