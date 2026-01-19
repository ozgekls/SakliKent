import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../services/mekan_service.dart';

final supabase = Supabase.instance.client;

class AddMekanPage extends StatefulWidget {
  const AddMekanPage({super.key});

  @override
  State<AddMekanPage> createState() => _AddMekanPageState();
}

class _AddMekanPageState extends State<AddMekanPage> {
  final _formKey = GlobalKey<FormState>();

  final _mekanAdiCtrl = TextEditingController();
  final _sehirCtrl = TextEditingController();
  final _aciklamaCtrl = TextEditingController();

  // ✅ Konum (kullanıcı sadece adres metnini görür)
  final _adresCtrl = TextEditingController();
  double? _lat;
  double? _lng;
  bool _konumLoading = false;

  int? _butce; // 1..5
  bool _saving = false;

  // ✅ Kapak foto (zorunlu)
  File? _kapakFoto;
  String? _kapakHata;

  // ✅ Kategori state
  List<Map<String, dynamic>> _kategoriler = [];
  final Set<String> _seciliKategoriIds = {};
  bool _katLoading = true;
  String? _katError;

  // ✅ Etiket state (YENİ)
  List<Map<String, dynamic>> _etiketler = [];
  final Set<String> _seciliEtiketIds = {};
  bool _etiketLoading = true;
  String? _etiketError;

  @override
  void initState() {
    super.initState();
    _loadKategoriler();
    _loadEtiketler(); // ✅ YENİ
  }

  Future<void> _loadKategoriler() async {
    setState(() {
      _katLoading = true;
      _katError = null;
    });

    try {
      final service = MekanService(supabase);
      final cats = await service.getKategoriler();
      setState(() {
        _kategoriler = cats;
      });
    } catch (e) {
      setState(() => _katError = e.toString());
    } finally {
      setState(() => _katLoading = false);
    }
  }

  // ✅ Etiketleri DB'den çek
  Future<void> _loadEtiketler() async {
    setState(() {
      _etiketLoading = true;
      _etiketError = null;
    });

    try {
      final tags = await supabase
          .from('etiket')
          .select('etiketid,etiketadi')
          .order('etiketadi');

      setState(() {
        _etiketler = List<Map<String, dynamic>>.from(tags);
      });
    } catch (e) {
      setState(() => _etiketError = e.toString());
    } finally {
      setState(() => _etiketLoading = false);
    }
  }

  @override
  void dispose() {
    _mekanAdiCtrl.dispose();
    _sehirCtrl.dispose();
    _aciklamaCtrl.dispose();
    _adresCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickKapakFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (picked == null) return;
    setState(() {
      _kapakFoto = File(picked.path);
      _kapakHata = null;
    });
  }

  // =========================
  // ✅ KONUM: seçenek seçtir
  // =========================
  Future<void> _openKonumSecenekleri() async {
    if (_saving) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Konum Ekle',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.my_location),
                  title: const Text('Otomatik (GPS)'),
                  subtitle: const Text(
                    'Konum izni ver → adres otomatik gelsin',
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _setKonumFromGps();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_location_alt),
                  title: const Text('Manuel'),
                  subtitle: const Text('Sadece adresi yaz (koordinat yok)'),
                  onTap: () {
                    Navigator.pop(context);
                    _setKonumManual();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setKonumFromGps() async {
    setState(() => _konumLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Konum servisi kapalı. Ayarlardan aç.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw 'Konum izni verilmedi.';
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Konum izni kalıcı reddedilmiş. Ayarlardan izin ver.';
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _lat = pos.latitude;
      _lng = pos.longitude;

      await Future.delayed(const Duration(milliseconds: 250));

      final addr = await _reverseGeocodeNominatim(_lat!, _lng!);
      setState(() {
        _adresCtrl.text = addr;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum eklendi ✅ (adres bulundu)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Konum alınamadı: $e')));
    } finally {
      if (mounted) setState(() => _konumLoading = false);
    }
  }

  Future<String> _reverseGeocodeNominatim(double lat, double lon) async {
    final nominatim = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
    );

    try {
      final res = await http.get(
        nominatim,
        headers: const {
          'User-Agent': 'SakliKent/1.0 (ozge.tcz4@gmail.com)',
          'Accept': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final displayName = (data['display_name'] ?? '').toString().trim();
        if (displayName.isNotEmpty) return displayName;
      }
    } catch (_) {}

    final bdc = Uri.parse(
      'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=tr',
    );

    final res2 = await http.get(bdc);
    if (res2.statusCode != 200) {
      throw 'Adres servisi hata verdi (${res2.statusCode})';
    }

    final data2 = jsonDecode(res2.body) as Map<String, dynamic>;

    final city = (data2['city'] ?? data2['principalSubdivision'] ?? '')
        .toString()
        .trim();
    final district = (data2['locality'] ?? '').toString().trim();
    final subLocality = (data2['principalSubdivision'] ?? '').toString().trim();

    final parts = <String>[
      if (district.isNotEmpty) district,
      if (subLocality.isNotEmpty && subLocality != city) subLocality,
      if (city.isNotEmpty) city,
    ];

    final addr = parts.join(', ').trim();
    return addr.isEmpty ? 'Adres bulunamadı' : addr;
  }

  void _setKonumManual() {
    setState(() {
      _lat = null;
      _lng = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adres alanına manuel yazabilirsin.')),
    );
  }

  void _clearKonum() {
    setState(() {
      _adresCtrl.clear();
      _lat = null;
      _lng = null;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_kapakFoto == null) {
      setState(() => _kapakHata = 'Kapak fotoğrafı zorunludur');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kapak fotoğrafı seçmelisin.')),
      );
      return;
    }

    if (_adresCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen konum ekleyin (adres).')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final service = MekanService(supabase);
      final user = supabase.auth.currentUser;
      if (user == null) throw 'Mekan eklemek için giriş yapmalısın.';

      final rand = Random().nextInt(1 << 32);
      final ext = (_kapakFoto!.path.split('.').last).toLowerCase();
      final safeExt =
          (ext == 'png' || ext == 'webp' || ext == 'jpg' || ext == 'jpeg')
          ? ext
          : 'jpg';
      final filePath =
          'mekan/${user.id}/${DateTime.now().microsecondsSinceEpoch}_$rand.$safeExt';

      await supabase.storage.from('images').upload(filePath, _kapakFoto!);
      final kapakUrl = supabase.storage.from('images').getPublicUrl(filePath);

      final inserted = await supabase
          .from('mekan')
          .insert({
            'mekanadi': _mekanAdiCtrl.text.trim(),
            'sehir': _sehirCtrl.text.trim().isEmpty
                ? null
                : _sehirCtrl.text.trim(),
            'aciklama': _aciklamaCtrl.text.trim().isEmpty
                ? null
                : _aciklamaCtrl.text.trim(),
            'butceseviyesi': _butce,
            'ekleyenkullaniciid': user.id,
            'kapak_fotograf_url': kapakUrl,
            'adres': _adresCtrl.text.trim().isEmpty
                ? null
                : _adresCtrl.text.trim(),
            'latitude': _lat,
            'longitude': _lng,
          })
          .select('id')
          .single();

      final mekanId = inserted['id'] as String;

      // ✅ Kategoriler
      await service.addMekanKategoriler(
        mekanId: mekanId,
        kategoriIds: _seciliKategoriIds.toList(),
      );

      // ✅ Etiketler (YENİ)
      if (_seciliEtiketIds.isNotEmpty) {
        await supabase
            .from('mekanetiket')
            .insert(
              _seciliEtiketIds
                  .map((eid) => {'mekanid': mekanId, 'etiketid': eid})
                  .toList(),
            );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kayıt başarısız: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAdres = _adresCtrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Mekan Ekle')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Kapak
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kapak Fotoğrafı *',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _saving ? null : _pickKapakFoto,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _kapakFoto == null
                              ? Colors.redAccent
                              : Colors.green,
                          width: 1.5,
                        ),
                      ),
                      child: _kapakFoto == null
                          ? const Center(
                              child: Text('Fotoğraf seçmek için dokun'),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(_kapakFoto!, fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  if (_kapakHata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _kapakHata!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _mekanAdiCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mekan Adı *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Mekan adı zorunlu';
                  if (v.trim().length < 2) return 'En az 2 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _sehirCtrl,
                decoration: const InputDecoration(
                  labelText: 'Şehir',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _aciklamaCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _konumLoading || _saving
                          ? null
                          : _openKonumSecenekleri,
                      icon: _konumLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.location_on_outlined),
                      label: Text(
                        _konumLoading ? 'Konum alınıyor...' : 'Konum Ekle',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: 'Konumu temizle',
                    onPressed: (!hasAdres || _konumLoading || _saving)
                        ? null
                        : _clearKonum,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: _adresCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Adres (kullanıcı sadece bunu görür)',
                  border: OutlineInputBorder(),
                  hintText: 'Konum ekleyin veya manuel adres yazın',
                ),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<int>(
                initialValue: _butce,
                decoration: const InputDecoration(
                  labelText: 'Bütçe Seviyesi (1-5)',
                  border: OutlineInputBorder(),
                ),
                items: const [1, 2, 3, 4, 5]
                    .map((x) => DropdownMenuItem(value: x, child: Text('$x')))
                    .toList(),
                onChanged: (v) => setState(() => _butce = v),
              ),

              const SizedBox(height: 16),

              // ✅ KATEGORİLER
              const Text(
                'Kategoriler',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_katLoading)
                const LinearProgressIndicator()
              else if (_katError != null)
                Text('Kategoriler yüklenemedi: $_katError')
              else if (_kategoriler.isEmpty)
                const Text('Kategori bulunamadı')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kategoriler.map((k) {
                    final id = k['kategoriid'].toString();
                    final ad = k['kategoriadi'].toString();
                    final selected = _seciliKategoriIds.contains(id);

                    return FilterChip(
                      label: Text(ad),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _seciliKategoriIds.add(id);
                          } else {
                            _seciliKategoriIds.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // ✅ ETİKETLER (YENİ)
              const Text(
                'Etiketler',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_etiketLoading)
                const LinearProgressIndicator()
              else if (_etiketError != null)
                Text('Etiketler yüklenemedi: $_etiketError')
              else if (_etiketler.isEmpty)
                const Text('Etiket bulunamadı')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _etiketler.map((t) {
                    final id = t['etiketid'].toString();
                    final ad = t['etiketadi'].toString();
                    final selected = _seciliEtiketIds.contains(id);

                    return FilterChip(
                      label: Text(ad),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _seciliEtiketIds.add(id);
                          } else {
                            _seciliEtiketIds.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: 18),

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (_saving || _kapakFoto == null) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Kaydediliyor...' : 'Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
