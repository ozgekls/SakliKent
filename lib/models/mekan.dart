class Mekan {
  final String id;
  final String mekanAdi;
  final String? sehir;
  final String? aciklama;
  final int? butceSeviyesi;

  Mekan({
    required this.id,
    required this.mekanAdi,
    this.sehir,
    this.aciklama,
    this.butceSeviyesi,
  });

  factory Mekan.fromMap(Map<String, dynamic> map) {
    // id genelde vardır ama yine de güvenli alalım
    final id = (map['id'] ?? map['ID'] ?? '').toString();

    // Mekan adı key’i bazen MekanAdi, bazen mekanadi olabilir
    final mekanAdiRaw = map['MekanAdi'] ?? map['mekanadi'] ?? map['mekan_adi'];

    return Mekan(
      id: id,
      mekanAdi: (mekanAdiRaw ?? '')
          .toString(), // null gelirse '' yapar, crash olmaz
      sehir: (map['Sehir'] ?? map['sehir'])?.toString(),
      aciklama: (map['Aciklama'] ?? map['aciklama'])?.toString(),
      butceSeviyesi:
          (map['ButceSeviyesi'] ??
                  map['butceseviyesi'] ??
                  map['butce_seviyesi'])
              as int?,
    );
  }
}
