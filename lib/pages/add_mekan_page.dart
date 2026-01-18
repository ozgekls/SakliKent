import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _loadKategoriler();
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

  @override
  void dispose() {
    _mekanAdiCtrl.dispose();
    _sehirCtrl.dispose();
    _aciklamaCtrl.dispose();
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

  Future<void> _save() async {
    // 1) Form valid mi?
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // 1.1) Kapak foto zorunlu
    if (_kapakFoto == null) {
      setState(() => _kapakHata = 'Kapak fotoğrafı zorunludur');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kapak fotoğrafı seçmelisin.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final service = MekanService(supabase);

      final user = supabase.auth.currentUser;
      if (user == null) {
        throw 'Mekan eklemek için giriş yapmalısın.';
      }

      // 2) Kapak foto storage upload (önce)
      final rand = Random().nextInt(1 << 32);
      final ext = (_kapakFoto!.path.split('.').last).toLowerCase();
      final safeExt =
          (ext == 'png' || ext == 'webp' || ext == 'jpg' || ext == 'jpeg')
          ? ext
          : 'jpg';
      final filePath =
          'mekan/${user.id}/${DateTime.now().microsecondsSinceEpoch}_$rand.$safeExt';

      print("USER: ${supabase.auth.currentUser?.id}");

      await supabase.storage.from('images').upload(filePath, _kapakFoto!);
      final kapakUrl = supabase.storage.from('images').getPublicUrl(filePath);

      // 3) Mekanı ekle -> id dönsün (kapak_fotograf_url NOT NULL olduğu için URL ile ekliyoruz)
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
          })
          .select('id')
          .single();

      final mekanId = inserted['id'] as String;

      // 4) ✅ Seçili kategorileri ilişkilendir
      await service.addMekanKategoriler(
        mekanId: mekanId,
        kategoriIds: _seciliKategoriIds.toList(),
      );

      // 5) Başarılıysa sayfayı kapat
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
    return Scaffold(
      appBar: AppBar(title: const Text('Mekan Ekle')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ✅ Kapak foto (zorunlu)
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

              // ✅ KATEGORİ SEÇİMİ
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
