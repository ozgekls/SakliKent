import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:saklikent/pages/mekan_detay_page.dart';

final supabase = Supabase.instance.client;

enum KesfetTab { popular, newest }

enum RankMode { ziyaret, begeni, yorum }

class KesfetPage extends StatefulWidget {
  const KesfetPage({super.key});

  @override
  State<KesfetPage> createState() => _KesfetPageState();
}

class _KesfetPageState extends State<KesfetPage> {
  bool _loading = true;
  String? _error;

  // Konum = şehir yaklaşımı
  String currentCity =
      'Amasya'; // TODO: profilden çekmek istersen ayrıca ekleriz

  // UI state
  KesfetTab tab = KesfetTab.popular;
  RankMode rankMode = RankMode.ziyaret;

  String row2Selected = 'Tümü';

  // Arama/filtre state
  String? searchText;
  int? butce; // 1..5

  // ✅ Yeni filtre state (db’den gelecek)
  List<Map<String, dynamic>> kategoriOptions = [];
  List<Map<String, dynamic>> etiketOptions = [];

  // seçilenler (uuid listeleri)
  final Set<String> selectedKategoriIds = {};
  final Set<String> selectedEtiketIds = {};

  // mekan tablosundaki boolean filtreler
  bool yoreselOnly = false;
  bool parkOnly = false;
  bool aileOnly = false;

  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _fetchFilterOptions(); // ✅ kategori + etiket
      await _fetch();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _fetchFilterOptions() async {
    final cats = await supabase
        .from('kategori')
        .select('kategoriid,kategoriadi')
        .order('kategoriadi');

    final tags = await supabase
        .from('etiket')
        .select('etiketid,etiketadi')
        .order('etiketadi');

    setState(() {
      kategoriOptions = List<Map<String, dynamic>>.from(cats);
      etiketOptions = List<Map<String, dynamic>>.from(tags);
    });
  }

  /// Base query: v_kesfetpuanli
  dynamic _baseQuery() {
    return supabase.from('v_kesfetpuanli').select('''
      id, mekanadi, sehir, butceseviyesi,
      kapak_fotograf_url, olusturmatarihi,
      begeni_sayisi, yorum_sayisi, ziyaret_sayisi,
      genel_ortalama,
      lezzet_ort, hizmet_ort, estetik_ort, internet_ort,
      sessizlik_ort, calismalik_ort, manzara_ort,
      yoreselyemekvar, parkyerivar, ailemekani,
      adres, latitude, longitude
    ''');
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ✅ Kategori/etiket seçildiyse en temiz yöntem RPC
      // RPC yoksa fallback: normal query (kategori/etiket filtre uygulanamaz)
      final hasRelFilters =
          selectedKategoriIds.isNotEmpty || selectedEtiketIds.isNotEmpty;

      if (hasRelFilters || yoreselOnly || parkOnly || aileOnly) {
        // RPC dene
        final data = await _fetchViaRpcOrFallback();
        setState(() => items = data);
        return;
      }

      // ✅ Kategori/etiket yoksa normal query devam
      dynamic q = _baseQuery();

      // şehir
      q = q.eq('sehir', currentCity);

      final st = searchText;
      final b = butce;

      if (st != null && st.trim().isNotEmpty) {
        q = q.ilike('mekanadi', '%${st.trim()}%');
      }
      if (b != null) {
        q = q.eq('butceseviyesi', b);
      }

      // boolean (normal query ile de çalışır)
      if (yoreselOnly) q = q.eq('yoreselyemekvar', true);
      if (parkOnly) q = q.eq('parkyerivar', true);
      if (aileOnly) q = q.eq('ailemekani', true);

      // sıralama
      q = _applySorting(q);

      final data = await q.limit(50);
      setState(() => items = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  dynamic _applySorting(dynamic q) {
    if (tab == KesfetTab.newest) {
      return q.order('olusturmatarihi', ascending: false);
    }

    // popular
    if (row2Selected == 'Lezzet') {
      return q.order('lezzet_ort', ascending: false);
    } else if (row2Selected == 'Hizmet') {
      return q.order('hizmet_ort', ascending: false);
    } else if (row2Selected == 'Estetik') {
      return q.order('estetik_ort', ascending: false);
    } else if (row2Selected == 'İnternet') {
      return q.order('internet_ort', ascending: false);
    } else if (row2Selected == 'Sessizlik') {
      return q.order('sessizlik_ort', ascending: false);
    } else if (row2Selected == 'Çalışmalık') {
      return q.order('calismalik_ort', ascending: false);
    } else if (row2Selected == 'Manzara') {
      return q.order('manzara_ort', ascending: false);
    } else if (row2Selected == 'Bütçe') {
      return q.order('butceseviyesi', ascending: true);
    }

    // trend
    switch (rankMode) {
      case RankMode.ziyaret:
        return q.order('ziyaret_sayisi', ascending: false);
      case RankMode.begeni:
        return q.order('begeni_sayisi', ascending: false);
      case RankMode.yorum:
        return q.order('yorum_sayisi', ascending: false);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchViaRpcOrFallback() async {
    // ✅ RPC önerilen isim: f_kesfet_filtreli_mekanlar
    // Eğer sende farklıysa burada değiştir.
    try {
      final params = <String, dynamic>{
        'p_sehir': currentCity,
        'p_butce_min': butce,
        'p_butce_max': butce,
        'p_kategori_ids': selectedKategoriIds.isEmpty
            ? null
            : selectedKategoriIds.toList(),
        'p_etiket_ids': selectedEtiketIds.isEmpty
            ? null
            : selectedEtiketIds.toList(),
        'p_yoresel': yoreselOnly ? true : null,
        'p_park': parkOnly ? true : null,
        'p_aile': aileOnly ? true : null,
      };

      final result = await supabase.rpc(
        'f_kesfet_filtreli_mekanlar',
        params: params,
      );
      final list = List<Map<String, dynamic>>.from(result as List);
      // RPC sonucu sıralı değilse yine burada sıralamak istersen ayrıca yapılır.
      return list;
    } catch (_) {
      // ❗ RPC yoksa fallback: şehir+arama+bütçe+boolean+sort
      dynamic q = _baseQuery();
      q = q.eq('sehir', currentCity);

      final st = searchText;
      final b = butce;

      if (st != null && st.trim().isNotEmpty) {
        q = q.ilike('mekanadi', '%${st.trim()}%');
      }
      if (b != null) {
        q = q.eq('butceseviyesi', b);
      }

      if (yoreselOnly) q = q.eq('yoreselyemekvar', true);
      if (parkOnly) q = q.eq('parkyerivar', true);
      if (aileOnly) q = q.eq('ailemekani', true);

      q = _applySorting(q);

      final data = await q.limit(50);
      return List<Map<String, dynamic>>.from(data);
    }
  }

  void _applyRow2Selection(String value) {
    setState(() {
      row2Selected = value;

      if (value == 'En Çok Beğeni') rankMode = RankMode.begeni;
      if (value == 'En Çok Yorum') rankMode = RankMode.yorum;
      if (value == 'Tümü') rankMode = RankMode.ziyaret;

      // bu seçimler "popular" mantığında çalışsın
      tab = KesfetTab.popular;
    });

    _fetch();
  }

  Future<void> _openSearchSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SearchFilterSheet(
        initialText: searchText ?? '',
        initialCity: currentCity,
        initialButce: butce,
        kategoriOptions: kategoriOptions,
        etiketOptions: etiketOptions,
        initialKategoriIds: selectedKategoriIds,
        initialEtiketIds: selectedEtiketIds,
        initialYoreselOnly: yoreselOnly,
        initialParkOnly: parkOnly,
        initialAileOnly: aileOnly,
      ),
    );

    if (result == null) return;

    setState(() {
      searchText = (result['text'] as String?)?.trim();
      currentCity = (result['city'] as String?)?.trim().isNotEmpty == true
          ? (result['city'] as String).trim()
          : currentCity;
      butce = result['butce'] as int?;

      selectedKategoriIds
        ..clear()
        ..addAll(List<String>.from(result['kategoriIds'] as List));
      selectedEtiketIds
        ..clear()
        ..addAll(List<String>.from(result['etiketIds'] as List));

      yoreselOnly = result['yoreselOnly'] as bool? ?? false;
      parkOnly = result['parkOnly'] as bool? ?? false;
      aileOnly = result['aileOnly'] as bool? ?? false;
    });

    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keşfet'),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: _openSearchSheet,
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Filtreler',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst açıklama
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '📍 $currentCity • Şehrin gizli kalmış incilerini keşfedin',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Segmented tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<KesfetTab>(
              segments: const [
                ButtonSegment(
                  value: KesfetTab.popular,
                  label: Text('🔥 En Popüler'),
                ),
                ButtonSegment(
                  value: KesfetTab.newest,
                  label: Text('🆕 Yeni Eklenenler'),
                ),
              ],
              selected: {tab},
              onSelectionChanged: (s) {
                setState(() => tab = s.first);
                _fetch();
              },
            ),
          ),

          const SizedBox(height: 10),

          // ✅ Kategori chipleri (tümü)
          if (kategoriOptions.isNotEmpty) ...[
            _DynamicIdChipsRow(
              title: 'Kategoriler',
              options: kategoriOptions,
              idKey: 'kategoriid',
              labelKey: 'kategoriadi',
              selectedIds: selectedKategoriIds,
              onToggle: (id) {
                setState(() {
                  if (selectedKategoriIds.contains(id)) {
                    selectedKategoriIds.remove(id);
                  } else {
                    selectedKategoriIds.add(id);
                  }
                });
                _fetch();
              },
            ),
            const SizedBox(height: 8),
          ],

          // ✅ Etiket chipleri (tümü)
          if (etiketOptions.isNotEmpty) ...[
            _DynamicIdChipsRow(
              title: 'Etiketler',
              options: etiketOptions,
              idKey: 'etiketid',
              labelKey: 'etiketadi',
              selectedIds: selectedEtiketIds,
              onToggle: (id) {
                setState(() {
                  if (selectedEtiketIds.contains(id)) {
                    selectedEtiketIds.remove(id);
                  } else {
                    selectedEtiketIds.add(id);
                  }
                });
                _fetch();
              },
            ),
            const SizedBox(height: 8),
          ],

          // Trend / Sıralama chipleri (senin row2)
          FilterChipsRow(
            items: const [
              'Tümü',
              'En Çok Beğeni',
              'En Çok Yorum',
              'Lezzet',
              'Hizmet',
              'Estetik',
              'İnternet',
              'Sessizlik',
              'Çalışmalık',
              'Manzara',
              'Bütçe',
            ],
            selected: row2Selected,
            onSelected: _applyRow2Selection,
          ),

          const SizedBox(height: 10),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!, style: TextStyle(color: cs.error)),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final id = item['id'] as String;

                        return _MekanCard(
                          item: item,
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
                  ),
          ),
        ],
      ),
    );
  }
}

class _DynamicIdChipsRow extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> options;
  final String idKey;
  final String labelKey;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _DynamicIdChipsRow({
    required this.title,
    required this.options,
    required this.idKey,
    required this.labelKey,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            title,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (_, i) {
              final opt = options[i];
              final id = opt[idKey].toString();
              final label = (opt[labelKey] ?? '').toString();
              final isOn = selectedIds.contains(id);

              return FilterChip(
                label: Text(label),
                selected: isOn,
                onSelected: (_) => onToggle(id),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isOn ? cs.onPrimary : null,
                ),
                selectedColor: cs.primary,
                backgroundColor: cs.surface,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: isOn ? cs.primary : cs.outlineVariant,
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: options.length,
          ),
        ),
      ],
    );
  }
}

class FilterChipsRow extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterChipsRow({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (_, i) {
          final t = items[i];
          final isOn = t == selected;
          return ChoiceChip(
            label: Text(t),
            selected: isOn,
            onSelected: (_) => onSelected(t),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: isOn ? Theme.of(context).colorScheme.onPrimary : null,
            ),
            selectedColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: StadiumBorder(
              side: BorderSide(
                color: isOn
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: items.length,
      ),
    );
  }
}

class _MekanCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _MekanCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final name = (item['mekanadi'] ?? '') as String;
    final city = (item['sehir'] ?? '') as String;
    final butce = (item['butceseviyesi'] ?? 0) as int;

    final ziyaret = (item['ziyaret_sayisi'] ?? 0) as int;
    final begeni = (item['begeni_sayisi'] ?? 0) as int;
    final yorum = (item['yorum_sayisi'] ?? 0) as int;

    final ortRaw = item['genel_ortalama'];
    final ort = (ortRaw is num)
        ? ortRaw.toStringAsFixed(1)
        : (ortRaw?.toString() ?? '0.0');

    final cover = item['kapak_fotograf_url'] as String?;

    return Material(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(coverUrl: cover),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$city • Bütçe: $butce/5 • Puan: $ort',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _MiniStat(
                          icon: Icons.location_on_outlined,
                          label: 'Ziyaret',
                          value: ziyaret,
                        ),
                        _MiniStat(
                          icon: Icons.favorite_border_rounded,
                          label: 'Beğeni',
                          value: begeni,
                        ),
                        _MiniStat(
                          icon: Icons.mode_comment_outlined,
                          label: 'Yorum',
                          value: yorum,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final String? coverUrl;
  const _Cover({this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 68,
        height: 68,
        color: cs.surfaceContainerHighest,
        child: (coverUrl != null && coverUrl!.isNotEmpty)
            ? Image.network(
                coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
              )
            : Icon(Icons.image_outlined, color: cs.onSurfaceVariant),
      ),
    );
  }
}

class _SearchFilterSheet extends StatefulWidget {
  final String initialText;
  final String initialCity;
  final int? initialButce;

  final List<Map<String, dynamic>> kategoriOptions;
  final List<Map<String, dynamic>> etiketOptions;

  final Set<String> initialKategoriIds;
  final Set<String> initialEtiketIds;

  final bool initialYoreselOnly;
  final bool initialParkOnly;
  final bool initialAileOnly;

  const _SearchFilterSheet({
    required this.initialText,
    required this.initialCity,
    required this.initialButce,
    required this.kategoriOptions,
    required this.etiketOptions,
    required this.initialKategoriIds,
    required this.initialEtiketIds,
    required this.initialYoreselOnly,
    required this.initialParkOnly,
    required this.initialAileOnly,
  });

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late final TextEditingController _text;
  late final TextEditingController _city;
  int? _butce;

  late final Set<String> _kategoriIds;
  late final Set<String> _etiketIds;

  late bool _yoreselOnly;
  late bool _parkOnly;
  late bool _aileOnly;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialText);
    _city = TextEditingController(text: widget.initialCity);
    _butce = widget.initialButce;

    _kategoriIds = {...widget.initialKategoriIds};
    _etiketIds = {...widget.initialEtiketIds};

    _yoreselOnly = widget.initialYoreselOnly;
    _parkOnly = widget.initialParkOnly;
    _aileOnly = widget.initialAileOnly;
  }

  @override
  void dispose() {
    _text.dispose();
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ara / Filtrele',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _text,
              decoration: const InputDecoration(
                labelText: 'Mekan adı',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _city,
              decoration: const InputDecoration(
                labelText: 'Şehir',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
            ),
            const SizedBox(height: 12),

            const Text('Bütçe'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: List.generate(5, (i) {
                final v = i + 1;
                final isOn = _butce == v;
                return ChoiceChip(
                  label: Text('$v'),
                  selected: isOn,
                  onSelected: (_) => setState(() => _butce = isOn ? null : v),
                );
              }),
            ),

            const SizedBox(height: 14),
            const Text('Özellikler'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: [
                FilterChip(
                  label: const Text('Yöresel'),
                  selected: _yoreselOnly,
                  onSelected: (v) => setState(() => _yoreselOnly = v),
                ),
                FilterChip(
                  label: const Text('Park'),
                  selected: _parkOnly,
                  onSelected: (v) => setState(() => _parkOnly = v),
                ),
                FilterChip(
                  label: const Text('Aile'),
                  selected: _aileOnly,
                  onSelected: (v) => setState(() => _aileOnly = v),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Text('Kategoriler'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: widget.kategoriOptions.map((c) {
                final id = c['kategoriid'].toString();
                final ad = (c['kategoriadi'] ?? '').toString();
                final isOn = _kategoriIds.contains(id);
                return FilterChip(
                  label: Text(ad),
                  selected: isOn,
                  onSelected: (_) {
                    setState(() {
                      if (isOn) {
                        _kategoriIds.remove(id);
                      } else {
                        _kategoriIds.add(id);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 14),
            const Text('Etiketler'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: widget.etiketOptions.map((t) {
                final id = t['etiketid'].toString();
                final ad = (t['etiketadi'] ?? '').toString();
                final isOn = _etiketIds.contains(id);
                return FilterChip(
                  label: Text(ad),
                  selected: isOn,
                  onSelected: (_) {
                    setState(() {
                      if (isOn) {
                        _etiketIds.remove(id);
                      } else {
                        _etiketIds.add(id);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _text.clear();
                        _city.text = widget.initialCity;
                        _butce = null;
                        _kategoriIds.clear();
                        _etiketIds.clear();
                        _yoreselOnly = false;
                        _parkOnly = false;
                        _aileOnly = false;
                      });
                    },
                    child: const Text('Sıfırla'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop<Map<String, dynamic>>(context, {
                        'text': _text.text,
                        'city': _city.text,
                        'butce': _butce,
                        'kategoriIds': _kategoriIds.toList(),
                        'etiketIds': _etiketIds.toList(),
                        'yoreselOnly': _yoreselOnly,
                        'parkOnly': _parkOnly,
                        'aileOnly': _aileOnly,
                      });
                    },
                    child: const Text('Uygula'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
