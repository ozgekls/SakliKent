import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mekan_detay_page.dart';

final supabase = Supabase.instance.client;

class MyPlacesPage extends StatefulWidget {
  final String userId;
  const MyPlacesPage({super.key, required this.userId});

  @override
  State<MyPlacesPage> createState() => _MyPlacesPageState();
}

class _MyPlacesPageState extends State<MyPlacesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

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
      final data = await supabase
          .from('mekan')
          .select('id, mekanadi, sehir')
          .eq('ekleyenkullaniciid', widget.userId)
          .order('olusturmatarihi', ascending: false);

      _rows = (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eklediğim Mekanlar')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Hata: $_error'))
          : ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final m = _rows[i];
                final id = m['id'].toString();
                final ad = (m['mekanadi'] ?? '').toString();
                final sehir = (m['sehir'] ?? '').toString();

                return ListTile(
                  title: Text(ad),
                  subtitle: Text(sehir),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MekanDetayPage(mekanId: id),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
