import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_page.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

final supabase = Supabase.instance.client;

class MekanDetayPage extends StatefulWidget {
  final String mekanId;
  const MekanDetayPage({super.key, required this.mekanId});

  @override
  State<MekanDetayPage> createState() => _MekanDetayPageState();
}

class _MekanDetayPageState extends State<MekanDetayPage> {
  bool _loading = true;
  String? _error;

  // ✅ Kullanıcı aksiyonları (visited/like)
  bool _visited = false;
  bool _liked = false;
  bool _actionsLoading = false;

  Map<String, dynamic>? _ozet; // view’den gelecek
  List<Map<String, dynamic>> _yorumlar = [];
  List<String> _kategoriler = [];

  // ✅ Kapak foto URL (mekan tablosundan)
  String? _kapakUrl;

  // ✅ Konum bilgileri (mekan tablosundan)
  String? _adres;
  double? _lat;
  double? _lng;
  String? _ownerId;

  // ✅ Düzenleme popup’ı için tüm seçenekler
  List<Map<String, dynamic>> _kategoriOptions = [];
  List<Map<String, dynamic>> _etiketOptions = [];

  bool get _isOwner {
    final myId = supabase.auth.currentUser?.id;
    return myId != null && _ownerId != null && myId == _ownerId;
  }

  // ✅ Yorum özellikleri (beğeni + yanıt)
  final Set<String> _expandedYorumlar = {}; // yorumid
  final Map<String, List<Map<String, dynamic>>> _yanitCache =
      {}; // yorumid -> replies
  final Set<String> _replyLoading = {}; // yorumid loading
  final Set<String> _likeLoading = {}; // yorumid loading

  void _openUserProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfilePage(userId: userId)),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) ÖZET + kategori (view)
      final rows = await supabase
          .from('v_mekanfiltreli')
          .select()
          .eq('id', widget.mekanId);

      if (rows.isEmpty) throw Exception('Mekan bulunamadı');

      final first = rows.first as Map<String, dynamic>;
      _ozet = first;

      _kategoriler = rows
          .map((r) => (r as Map<String, dynamic>)['kategoriadi'])
          .where((x) => x != null)
          .map((x) => x.toString())
          .toSet()
          .toList();

      // 1.1) Mekan tablosundan kapak + konum çek
      final mekanRow = await supabase
          .from('mekan')
          .select(
            'ekleyenkullaniciid, kapak_fotograf_url, adres, latitude, longitude',
          )
          .eq('id', widget.mekanId)
          .maybeSingle();

      _ownerId = (mekanRow?['ekleyenkullaniciid'] as String?);
      _kapakUrl = (mekanRow?['kapak_fotograf_url'] as String?);
      _adres = (mekanRow?['adres'] as String?)?.toString();
      _lat = (mekanRow?['latitude'] as num?)?.toDouble();
      _lng = (mekanRow?['longitude'] as num?)?.toDouble();

      // 2) Yorumlar + kullanıcı bilgisi + yorum beğeni/yanıt sayıları
      final yorumRows = await supabase
          .from('v_yorumlar_detay_v2')
          .select('''
            yorumid,
            mekanid,
            kullaniciid,
            kullaniciadi,
            profil_fotograf_url,
            yorummetni,
            puan,
            yorumtarihi,
            begeni_sayisi,
            benim_begendim,
            yanit_sayisi
          ''')
          .eq('mekanid', widget.mekanId)
          .order('yorumtarihi', ascending: false);

      _yorumlar = (yorumRows as List).cast<Map<String, dynamic>>();

      // 3) Bu kullanıcı visited/liked mi?
      await _loadUserActions();

      // 4) Expanded açık olan yorumların yanıtlarını tekrar çek (refresh)
      for (final yorumId in _expandedYorumlar) {
        await _fetchReplies(yorumId, force: true);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUserActions() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _visited = false;
        _liked = false;
      });
      return;
    }

    final v = await supabase
        .from('ziyaretler')
        .select('id')
        .eq('mekanid', widget.mekanId)
        .eq('kullaniciid', user.id)
        .maybeSingle();

    final l = await supabase
        .from('begeniler')
        .select('mekanid')
        .eq('mekanid', widget.mekanId)
        .eq('kullaniciid', user.id)
        .maybeSingle();

    if (!mounted) return;
    setState(() {
      _visited = v != null;
      _liked = l != null;
    });
  }

  Future<void> _toggleVisited() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ziyaret kaydı için giriş yapmalısın')),
      );
      return;
    }

    setState(() => _actionsLoading = true);

    try {
      if (_visited) {
        await supabase
            .from('ziyaretler')
            .delete()
            .eq('mekanid', widget.mekanId)
            .eq('kullaniciid', user.id);

        if (mounted) setState(() => _visited = false);
      } else {
        await supabase.from('ziyaretler').insert({
          'mekanid': widget.mekanId,
          'kullaniciid': user.id,
        });

        if (mounted) setState(() => _visited = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    } finally {
      if (mounted) setState(() => _actionsLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beğenmek için giriş yapmalısın')),
      );
      return;
    }

    setState(() => _actionsLoading = true);

    try {
      if (_liked) {
        await supabase
            .from('begeniler')
            .delete()
            .eq('mekanid', widget.mekanId)
            .eq('kullaniciid', user.id);

        if (mounted) setState(() => _liked = false);
      } else {
        await supabase.from('begeniler').insert({
          'mekanid': widget.mekanId,
          'kullaniciid': user.id,
        });

        if (mounted) setState(() => _liked = true);
      }

      await _loadAll();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    } finally {
      if (mounted) setState(() => _actionsLoading = false);
    }
  }

  // ============================
  // ✅ Yorum Beğeni Toggle
  // ============================
  Future<void> _toggleYorumBegeni(String yorumId, bool currentlyLiked) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorum beğenmek için giriş yapmalısın')),
      );
      return;
    }
    if (_likeLoading.contains(yorumId)) return;

    setState(() => _likeLoading.add(yorumId));

    try {
      if (currentlyLiked) {
        await supabase
            .from('yorum_begeniler')
            .delete()
            .eq('kullaniciid', user.id)
            .eq('yorumid', yorumId);
      } else {
        await supabase.from('yorum_begeniler').insert({
          'kullaniciid': user.id,
          'yorumid': yorumId,
        });
      }

      await _loadAll();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    } finally {
      if (mounted) setState(() => _likeLoading.remove(yorumId));
    }
  }

  // ============================
  // ✅ Yanıtlar: Fetch + Toggle UI
  // ============================
  Future<void> _fetchReplies(String yorumId, {bool force = false}) async {
    if (!force && _yanitCache.containsKey(yorumId)) return;
    if (_replyLoading.contains(yorumId)) return;

    setState(() => _replyLoading.add(yorumId));

    try {
      final rows = await supabase
          .from('v_yorum_yanit_detay')
          .select('''
            yanitid,
            yorumid,
            kullaniciid,
            kullaniciadi,
            profil_fotograf_url,
            yanit_metni,
            yanit_tarihi
          ''')
          .eq('yorumid', yorumId)
          .order('yanit_tarihi', ascending: true);

      _yanitCache[yorumId] = (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // sessiz geç
    } finally {
      if (mounted) setState(() => _replyLoading.remove(yorumId));
    }
  }

  Future<void> _toggleReplies(String yorumId) async {
    if (_expandedYorumlar.contains(yorumId)) {
      setState(() => _expandedYorumlar.remove(yorumId));
      return;
    }
    setState(() => _expandedYorumlar.add(yorumId));
    await _fetchReplies(yorumId);
  }

  // ============================
  // ✅ Yanıt ekleme
  // ============================
  Future<void> _replyToComment(String yorumId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yanıt vermek için giriş yapmalısın')),
      );
      return;
    }

    final ctrl = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yanıt yaz',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Yanıtınız...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Gönder'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (ok != true) return;

    final text = ctrl.text.trim();
    if (text.isEmpty) return;

    try {
      await supabase.from('yorum_yanit').insert({
        'yorumid': yorumId,
        'kullaniciid': user.id,
        'yanit_metni': text,
      });

      await _fetchReplies(yorumId, force: true);
      if (!_expandedYorumlar.contains(yorumId)) {
        setState(() => _expandedYorumlar.add(yorumId));
      }

      await _loadAll();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    }
  }

  Future<void> _addCommentDialog() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorum eklemek için giriş yapmalısın')),
      );
      return;
    }

    final ctrl = TextEditingController();
    int puan = 5;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yorum Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: puan,
              items: [1, 2, 3, 4, 5]
                  .map((x) => DropdownMenuItem(value: x, child: Text('$x')))
                  .toList(),
              onChanged: (v) => puan = v ?? 5,
              decoration: const InputDecoration(labelText: 'Puan'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Yorum',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await supabase.from('yorum').insert({
      'yorummetni': ctrl.text.trim(),
      'puan': puan,
      'mekanid': widget.mekanId,
      'kullaniciid': user.id,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Yorum eklendi')));

    await _loadAll();
  }

  Future<void> _confirmDeleteMekan() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mekanı sil?'),
        content: const Text('Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await supabase.from('mekan').delete().eq('id', widget.mekanId);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mekan silindi')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Silme başarısız: $e')));
    }
  }

  Future<String?> _pickAndUploadCover(String mekanId) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotoğraf yüklemek için giriş yapmalısın'),
        ),
      );
      return null;
    }

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fotoğraf seçilmedi')));
        return null;
      }

      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fotoğraf okunamadı')));
        return null;
      }

      final name = picked.name;
      final ext = name.contains('.')
          ? name.split('.').last.toLowerCase()
          : 'jpg';

      final path =
          '${user.id}/$mekanId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      const bucket = 'mekan-covers';

      await supabase.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
          );

      final publicUrl = supabase.storage.from(bucket).getPublicUrl(path);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Fotoğraf yüklendi')));

      return publicUrl;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Yükleme hatası: $e')));
      return null;
    }
  }

  // ==========================================================
  // ✅ DÜZENLEME: kategori+etiket seçeneklerini DB’den çek
  // ==========================================================
  Future<void> _loadKategoriEtiketOptions() async {
    final cats = await supabase
        .from('kategori')
        .select('kategoriid,kategoriadi')
        .order('kategoriadi');

    final tags = await supabase
        .from('etiket')
        .select('etiketid,etiketadi')
        .order('etiketadi');

    _kategoriOptions = List<Map<String, dynamic>>.from(cats);
    _etiketOptions = List<Map<String, dynamic>>.from(tags);
  }

  Future<Set<String>> _getMekanKategoriIds() async {
    final rows = await supabase
        .from('mekankategori')
        .select('kategoriid')
        .eq('mekanid', widget.mekanId);

    return rows.map((r) => r['kategoriid'].toString()).toSet();
  }

  Future<Set<String>> _getMekanEtiketIds() async {
    final rows = await supabase
        .from('mekanetiket')
        .select('etiketid')
        .eq('mekanid', widget.mekanId);

    return rows.map((r) => r['etiketid'].toString()).toSet();
  }

  Future<void> _openEditMekan() async {
    // seçenekleri çek (hata olsa bile dialog açılsın)
    try {
      await _loadKategoriEtiketOptions();
    } catch (_) {}

    Set<String> seciliKat = {};
    Set<String> seciliEtiket = {};
    try {
      seciliKat = await _getMekanKategoriIds();
      seciliEtiket = await _getMekanEtiketIds();
    } catch (_) {}

    final nameCtrl = TextEditingController(
      text: (_ozet?['mekanadi'] ?? '').toString(),
    );
    final descCtrl = TextEditingController(
      text: (_ozet?['aciklama'] ?? '').toString(),
    );

    int butce = 3;
    final b = _ozet?['butceseviyesi'];
    if (b is int) butce = b;
    if (b is num) butce = b.toInt();

    String? newCoverUrl;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) {
          final preview = (newCoverUrl ?? _kapakUrl ?? '').trim();

          return AlertDialog(
            title: const Text('Mekanı Düzenle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kapak
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 64,
                          height: 64,
                          color: Colors.black.withOpacity(0.06),
                          child: preview.isNotEmpty
                              ? Image.network(
                                  preview,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image_outlined),
                                )
                              : const Icon(Icons.image_outlined),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final url = await _pickAndUploadCover(
                              widget.mekanId,
                            );
                            if (url == null) return;
                            setLocal(() => newCoverUrl = url);
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Kapak Fotoğrafı Seç'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Mekan adı'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Açıklama'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    value: butce,
                    items: [1, 2, 3, 4, 5]
                        .map(
                          (x) => DropdownMenuItem(value: x, child: Text('$x')),
                        )
                        .toList(),
                    onChanged: (v) => butce = v ?? butce,
                    decoration: const InputDecoration(labelText: 'Bütçe'),
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Kategoriler',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kategoriOptions.map((k) {
                      final id = k['kategoriid'].toString();
                      final ad = k['kategoriadi'].toString();
                      final selected = seciliKat.contains(id);
                      return FilterChip(
                        label: Text(ad),
                        selected: selected,
                        onSelected: (v) {
                          setLocal(() {
                            if (v) {
                              seciliKat.add(id);
                            } else {
                              seciliKat.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Etiketler',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _etiketOptions.map((t) {
                      final id = t['etiketid'].toString();
                      final ad = t['etiketadi'].toString();
                      final selected = seciliEtiket.contains(id);
                      return FilterChip(
                        label: Text(ad),
                        selected: selected,
                        onSelected: (v) {
                          setLocal(() {
                            if (v) {
                              seciliEtiket.add(id);
                            } else {
                              seciliEtiket.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) return;

    try {
      // 1) Mekan update
      final payload = <String, dynamic>{
        'mekanadi': nameCtrl.text.trim(),
        'aciklama': descCtrl.text.trim(),
        'butceseviyesi': butce,
      };

      if (newCoverUrl != null && newCoverUrl!.trim().isNotEmpty) {
        payload['kapak_fotograf_url'] = newCoverUrl!.trim();
      }

      await supabase.from('mekan').update(payload).eq('id', widget.mekanId);

      // 2) ilişkiler: sil -> yeniden ekle
      await supabase
          .from('mekankategori')
          .delete()
          .eq('mekanid', widget.mekanId);
      await supabase.from('mekanetiket').delete().eq('mekanid', widget.mekanId);

      if (seciliKat.isNotEmpty) {
        await supabase
            .from('mekankategori')
            .insert(
              seciliKat
                  .map((kid) => {'mekanid': widget.mekanId, 'kategoriid': kid})
                  .toList(),
            );
      }

      if (seciliEtiket.isNotEmpty) {
        await supabase
            .from('mekanetiket')
            .insert(
              seciliEtiket
                  .map((eid) => {'mekanid': widget.mekanId, 'etiketid': eid})
                  .toList(),
            );
      }

      await _loadAll();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Güncellendi')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Güncelleme başarısız: $e')));
    }
  }

  void _openMap() {
    final lat = _lat;
    final lng = _lng;
    if (lat == null || lng == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPage(
          mekanAdi: (_ozet?['mekanadi'] ?? 'Mekan').toString(),
          lat: lat,
          lng: lng,
          adres: _adres,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (_ozet?['mekanadi'] ?? 'Mekan Detay').toString();
    final kapak = (_kapakUrl ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isOwner) ...[
            IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEditMekan,
            ),
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDeleteMekan,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Hata: $_error'))
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (kapak.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        kapak,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 220,
                          alignment: Alignment.center,
                          color: Colors.black.withOpacity(0.06),
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  _buildOzetCard(),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _actionsLoading ? null : _toggleVisited,
                          icon: Icon(
                            _visited
                                ? Icons.check_circle
                                : Icons.place_outlined,
                          ),
                          label: Text(_visited ? 'Ziyaret Edildi' : 'Visited'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _actionsLoading ? null : _toggleLike,
                          icon: Icon(
                            _liked ? Icons.favorite : Icons.favorite_border,
                          ),
                          label: Text(_liked ? 'Beğenildi' : 'Beğen'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  if (_lat != null && _lng != null)
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _openMap,
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Haritada Gör'),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Bu mekanda harita için koordinat yok.\nAdres: ${(_adres ?? '—')}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                  _buildKategoriCard(),
                  const SizedBox(height: 12),

                  _buildYorumYazPanel(),
                  const SizedBox(height: 12),

                  _buildYorumlarCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildYorumYazPanel() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Yorum yapmak için giriş yapmalısın.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yorum Yap',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _actionsLoading ? null : _addCommentDialog,
                icon: const Icon(Icons.rate_review),
                label: const Text('Yorumunu yaz'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOzetCard() {
    final sehir = (_ozet?['sehir'] ?? '').toString();
    final begeni = (_ozet?['begeni_sayisi'] ?? 0).toString();
    final yorumSayisi = (_ozet?['yorum_sayisi'] ?? 0).toString();

    // ✅ view'lerde bazen genel_ortalama bazen ortalama_puan olabiliyor
    final ortVal = _ozet?['genel_ortalama'] ?? _ozet?['ortalama_puan'] ?? 0;
    final ort = (ortVal is num) ? ortVal.toStringAsFixed(1) : ortVal.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (_ozet?['mekanadi'] ?? '').toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text('Şehir: $sehir'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _chip('Ortalama: $ort'),
                _chip('Yorum: $yorumSayisi'),
                _chip('Beğeni: $begeni'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKategoriCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kategoriler',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (_kategoriler.isEmpty)
              const Text('Kategori yok')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kategoriler.map((k) => _chip(k)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildYorumlarCard() {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Yorumlar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (_yorumlar.isEmpty)
              Text(
                'Henüz yorum yok',
                style: TextStyle(color: cs.onSurfaceVariant),
              )
            else
              ..._yorumlar.map((y) {
                final yorumId = (y['yorumid'] ?? '').toString();

                final metin = (y['yorummetni'] ?? '').toString();
                final puan = (y['puan'] ?? 0).toString();
                final tarih = (y['yorumtarihi'] ?? '').toString();

                final kullaniciAdi =
                    (y['kullaniciadi'] ?? 'Bilinmeyen kullanıcı').toString();
                final profilUrl = y['profil_fotograf_url'] as String?;
                final kullaniciId = (y['kullaniciid'] ?? '').toString();

                final likeCount = (y['begeni_sayisi'] ?? 0) as int;
                final liked = (y['benim_begendim'] ?? false) as bool;
                final replyCount = (y['yanit_sayisi'] ?? 0) as int;

                final expanded = _expandedYorumlar.contains(yorumId);
                final replies = _yanitCache[yorumId] ?? const [];
                final repliesLoading = _replyLoading.contains(yorumId);
                final likeBusy = _likeLoading.contains(yorumId);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: cs.outlineVariant),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage:
                                    (profilUrl != null && profilUrl.isNotEmpty)
                                    ? NetworkImage(profilUrl)
                                    : null,
                                child: (profilUrl == null || profilUrl.isEmpty)
                                    ? Text(
                                        kullaniciAdi.isEmpty
                                            ? '?'
                                            : kullaniciAdi
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      metin,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () =>
                                          _openUserProfile(kullaniciId),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: 16,
                                              color: cs.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              kullaniciAdi,
                                              style: TextStyle(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 6),

                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 16,
                                          color: cs.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Puan: $puan',
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 15,
                                          color: cs.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            tarih,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    Row(
                                      children: [
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          onPressed: likeBusy
                                              ? null
                                              : () => _toggleYorumBegeni(
                                                  yorumId,
                                                  liked,
                                                ),
                                          icon: Icon(
                                            liked
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                          ),
                                        ),
                                        Text(
                                          '$likeCount',
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: () =>
                                              _replyToComment(yorumId),
                                          icon: const Icon(
                                            Icons.reply_rounded,
                                            size: 18,
                                          ),
                                          label: Text('Yanıtla ($replyCount)'),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () =>
                                              _toggleReplies(yorumId),
                                          child: Text(
                                            expanded
                                                ? 'Gizle'
                                                : 'Yanıtları gör',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (expanded)
                            Padding(
                              padding: const EdgeInsets.only(left: 44, top: 6),
                              child: repliesLoading
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: LinearProgressIndicator(
                                        minHeight: 2,
                                      ),
                                    )
                                  : (replies.isEmpty
                                        ? Text(
                                            'Henüz yanıt yok',
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        : Column(
                                            children: replies.map((r) {
                                              final rName =
                                                  (r['kullaniciadi'] ??
                                                          'Kullanıcı')
                                                      .toString();
                                              final rUrl =
                                                  r['profil_fotograf_url']
                                                      as String?;
                                              final rText =
                                                  (r['yanit_metni'] ?? '')
                                                      .toString();
                                              final rUserId =
                                                  (r['kullaniciid'] ?? '')
                                                      .toString();

                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 10,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 14,
                                                      backgroundImage:
                                                          (rUrl != null &&
                                                              rUrl.isNotEmpty)
                                                          ? NetworkImage(rUrl)
                                                          : null,
                                                      child:
                                                          (rUrl == null ||
                                                              rUrl.isEmpty)
                                                          ? Text(
                                                              rName.isEmpty
                                                                  ? '?'
                                                                  : rName
                                                                        .substring(
                                                                          0,
                                                                          1,
                                                                        )
                                                                        .toUpperCase(),
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 12,
                                                              ),
                                                            )
                                                          : null,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          InkWell(
                                                            onTap: () =>
                                                                _openUserProfile(
                                                                  rUserId,
                                                                ),
                                                            child: Text(
                                                              rName,
                                                              style: TextStyle(
                                                                color:
                                                                    cs.primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            rText,
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  height: 1.25,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          )),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withOpacity(0.06),
      ),
      child: Text(text),
    );
  }
}

// =====================================
// ✅ HARİTA SAYFASI (AYNI DOSYA İÇİNDE)
// =====================================
class MapPage extends StatelessWidget {
  final String mekanAdi;
  final double lat;
  final double lng;
  final String? adres;

  const MapPage({
    super.key,
    required this.mekanAdi,
    required this.lat,
    required this.lng,
    this.adres,
  });

  Future<void> _openInOSM() async {
    final url = Uri.parse(
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=18/$lat/$lng',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(lat, lng);

    return Scaffold(
      appBar: AppBar(
        title: Text(mekanAdi),
        actions: [
          IconButton(
            tooltip: 'OpenStreetMap’te aç',
            onPressed: _openInOSM,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 16),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.saklikent',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 54,
                height: 54,
                child: const Icon(Icons.location_pin, size: 54),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: (adres == null || adres!.trim().isEmpty)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  adres!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
    );
  }
}
