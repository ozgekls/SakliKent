import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Harita için
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

      // ✅ 1.1) Mekan tablosundan kapak + konum çek
      final mekanRow = await supabase
          .from('mekan')
          .select('kapak_fotograf_url, adres, latitude, longitude')
          .eq('id', widget.mekanId)
          .maybeSingle();

      _kapakUrl = (mekanRow?['kapak_fotograf_url'] as String?);
      _adres = (mekanRow?['adres'] as String?)?.toString();
      _lat = (mekanRow?['latitude'] as num?)?.toDouble();
      _lng = (mekanRow?['longitude'] as num?)?.toDouble();

      // 2) Yorumlar + kullanıcı bilgisi
      final yorumRows = await supabase
          .from('yorum')
          .select('''
            yorumid,
            yorummetni,
            puan,
            yorumtarihi,
            kullanici:kullaniciid (
              kullaniciadi,
              email
            )
          ''')
          .eq('mekanid', widget.mekanId)
          .order('yorumtarihi', ascending: false);

      _yorumlar = (yorumRows as List).cast<Map<String, dynamic>>();

      // 3) ✅ Bu kullanıcı visited/liked mi?
      await _loadUserActions();
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

      // ✅ özet beğeni sayısı güncellensin
      await _loadAll();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
    } finally {
      if (mounted) setState(() => _actionsLoading = false);
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
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Hata: $_error'))
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ✅ Kapak foto (üstte banner)
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

                  // ✅ Visited + Like butonları
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

                  // ✅ Harita butonu (lat/lng varsa)
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
                          'Bu mekanda harita için koordinat yok. (Manuel adres girilmiş olabilir)\n'
                          'Adres: ${(_adres ?? '—')}',
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
    final ort = (_ozet?['ortalama_puan'] ?? 0).toString();

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
              const Text('Henüz yorum yok')
            else
              ..._yorumlar.map((y) {
                final metin = (y['yorummetni'] ?? '').toString();
                final puan = (y['puan'] ?? 0).toString();
                final tarih = (y['yorumtarihi'] ?? '').toString();

                final kullanici = y['kullanici'] as Map<String, dynamic>?;
                final kullaniciAdi =
                    (kullanici?['kullaniciadi'] ?? 'Bilinmeyen kullanıcı')
                        .toString();
                final email = kullanici?['email'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text(
                        kullaniciAdi.isEmpty
                            ? '?'
                            : kullaniciAdi.substring(0, 1).toUpperCase(),
                      ),
                    ),
                    title: Text(metin),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('👤 $kullaniciAdi'),
                        if (email != null) Text(email.toString()),
                        Text('⭐ Puan: $puan'),
                        Text('🕒 $tarih'),
                      ],
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
