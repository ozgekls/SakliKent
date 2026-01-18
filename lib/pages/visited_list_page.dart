import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mekan_detay_page.dart';

final supabase = Supabase.instance.client;

class VisitedListPage extends StatefulWidget {
  final String userId;
  const VisitedListPage({super.key, required this.userId});

  @override
  State<VisitedListPage> createState() => _VisitedListPageState();
}

class _VisitedListPageState extends State<VisitedListPage> {
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
          .from('ziyaretler')
          .select('''
            id,
            ziyarettarihi,
            mekan:mekanid (
              id,
              mekanadi,
              sehir
            )
          ''')
          .eq('kullaniciid', widget.userId)
          .order('ziyarettarihi', ascending: false);

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
      appBar: AppBar(title: const Text('Ziyaret Ettiklerim')),
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
