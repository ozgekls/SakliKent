class FilterState {
  final String? sehir;
  final int? minButce;
  final int? maxButce;

  final num? minLezzet;
  final num? minHizmet;
  final num? minEstetik;
  final num? minInternet;

  final String
  siralama; // 'onerilen', 'en_cok_begeni', 'en_cok_yorum', 'en_yuksek_puan'

  const FilterState({
    this.sehir,
    this.minButce,
    this.maxButce,
    this.minLezzet,
    this.minHizmet,
    this.minEstetik,
    this.minInternet,
    this.siralama = 'onerilen',
  });

  Map<String, dynamic> toRpcParams() {
    return {
      'p_sehir': sehir,
      'p_min_butce': minButce,
      'p_max_butce': maxButce,
      'p_min_lezzet': minLezzet,
      'p_min_hizmet': minHizmet,
      'p_min_estetik': minEstetik,
      'p_min_internet': minInternet,
      'p_siralama': siralama,
    };
  }

  List<String> toChips() {
    final chips = <String>[];
    if (sehir != null && sehir!.trim().isNotEmpty) chips.add('Şehir: $sehir');
    if (minButce != null) chips.add('Min bütçe: $minButce');
    if (maxButce != null) chips.add('Max bütçe: $maxButce');
    if (minLezzet != null) chips.add('Lezzet ≥ $minLezzet');
    if (minHizmet != null) chips.add('Hizmet ≥ $minHizmet');
    if (minEstetik != null) chips.add('Estetik ≥ $minEstetik');
    if (minInternet != null) chips.add('İnternet ≥ $minInternet');
    chips.add('Sıralama: $siralama');
    return chips;
  }

  FilterState copyWith({
    String? sehir,
    int? minButce,
    int? maxButce,
    num? minLezzet,
    num? minHizmet,
    num? minEstetik,
    num? minInternet,
    String? siralama,
  }) {
    return FilterState(
      sehir: sehir ?? this.sehir,
      minButce: minButce ?? this.minButce,
      maxButce: maxButce ?? this.maxButce,
      minLezzet: minLezzet ?? this.minLezzet,
      minHizmet: minHizmet ?? this.minHizmet,
      minEstetik: minEstetik ?? this.minEstetik,
      minInternet: minInternet ?? this.minInternet,
      siralama: siralama ?? this.siralama,
    );
  }
}
