import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MapPage extends StatelessWidget {
  final String mekanAdi;
  final double lat;
  final double lng;
  final String? adres;

  const MapPage({
    super.key,
    required this.mekanAdi,
    required this.lat,
    required this.lng,
    this.adres,
  });

  Future<void> _openInOSM() async {
    final url = Uri.parse(
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=18/$lat/$lng',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'OSM açılamadı';
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = LatLng(lat, lng);

    return Scaffold(
      appBar: AppBar(
        title: Text(mekanAdi),
        actions: [
          IconButton(
            tooltip: 'OpenStreetMap’te aç',
            onPressed: _openInOSM,
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 16),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.saklikent',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: center,
                width: 50,
                height: 50,
                child: const Icon(Icons.location_pin, size: 50),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: (adres == null || adres!.trim().isEmpty)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  adres!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
    );
  }
}
