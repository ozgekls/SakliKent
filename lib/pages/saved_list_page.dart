import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mekan_detay_page.dart';

final supabase = Supabase.instance.client;

class SavedListPage extends StatefulWidget {
  final String userId;
  const SavedListPage({super.key, required this.userId});

  @override
  State<SavedListPage> createState() => _SavedListPageState();
}

class _SavedListPageState extends State<SavedListPage> {
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
          .from('kaydedilenler')
          .select('''
            kayittarihi,
            mekan:mekanid (
              id,
              mekanadi,
              sehir
            )
          ''')
          .eq('kullaniciid', widget.userId)
          .order('kayittarihi', ascending: false);

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
      appBar: AppBar(title: const Text('Gitmek İstediklerim')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Hata: $_error'))
          : ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final mekan = _rows[i]['mekan'] as Map<String, dynamic>?;
                if (mekan == null) return const SizedBox.shrink();

                final id = mekan['id'].toString();
                final ad = (mekan['mekanadi'] ?? '').toString();
                final sehir = (mekan['sehir'] ?? '').toString();

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
