import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Map<String, dynamic>? _ozet; // view’den gelecek
  List<Map<String, dynamic>> _yorumlar = [];
  List<String> _kategoriler = []; // birden fazla olabilir

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
      // 1) ÖZET + kategori (view: V_MekanFiltreli)
      // V_MekanFiltreli satır satır kategori döndürüyor olabilir (aynı mekan için birden fazla satır)
      final rows = await supabase
          .from('v_mekanfiltreli')
          .select()
          .eq('id', widget.mekanId);

      if (rows.isEmpty) {
        throw Exception('Mekan bulunamadı');
      }

      // ortak özet alanları ilk satırdan alınır
      final first = rows.first as Map<String, dynamic>;
      _ozet = first;

      // kategorileri topla (null olmayanları al)
      _kategoriler = rows
          .map((r) => (r as Map<String, dynamic>)['kategoriadi'])
          .where((x) => x != null)
          .map((x) => x.toString())
          .toSet()
          .toList();

      // 2) YORUMLAR (yorum tablosu)
      final yorumRows = await supabase
          .from('yorum')
          .select('yorumid, yorummetni, puan, yorumtarihi, kullaniciid')
          .eq('mekanid', widget.mekanId)
          .order('yorumtarihi', ascending: false);

      _yorumlar = (yorumRows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (_ozet?['mekanadi'] ?? 'Mekan Detay').toString();

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
                  _buildOzetCard(),
                  const SizedBox(height: 12),
                  _buildKategoriCard(),
                  const SizedBox(height: 12),
                  _buildYorumlarCard(),
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
                final puan = (y['puan'] ?? '').toString();
                final tarih = (y['yorumtarihi'] ?? '').toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(metin),
                    subtitle: Text('Puan: $puan • $tarih'),
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
