import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/mekan_service.dart';

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

  @override
  void dispose() {
    _mekanAdiCtrl.dispose();
    _sehirCtrl.dispose();
    _aciklamaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 1) Form valid mi?
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      // 2) DB insert
      final service = MekanService(supabase);
      await service.addMekan(
        mekanAdi: _mekanAdiCtrl.text.trim(),
        sehir: _sehirCtrl.text.trim().isEmpty ? null : _sehirCtrl.text.trim(),
        aciklama: _aciklamaCtrl.text.trim().isEmpty
            ? null
            : _aciklamaCtrl.text.trim(),
        butceSeviyesi: _butce,
      );

      // 3) Başarılıysa sayfayı kapat
      if (mounted) Navigator.pop(context);
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

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
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
