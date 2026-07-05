import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../config/theme.dart';

class MapPinPicker extends StatefulWidget {
  const MapPinPicker({
    super.key,
    required this.initial,
    required this.onChanged,
    this.height = 220,
  });

  final LatLng initial;
  final ValueChanged<LatLng> onChanged;
  final double height;

  @override
  State<MapPinPicker> createState() => _MapPinPickerState();
}

class _MapPinPickerState extends State<MapPinPicker> {
  late LatLng _point;
  final _controller = MapController();

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _point,
                initialZoom: 14,
                onTap: (_, latLng) {
                  setState(() => _point = latLng);
                  widget.onChanged(latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.sacostay',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _point,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_on,
                        color: SacoColors.sacoOrange,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: IconButton(
                  icon: const Icon(Icons.my_location, size: 20),
                  tooltip: 'Về vị trí ban đầu',
                  onPressed: () {
                    setState(() => _point = widget.initial);
                    widget.onChanged(widget.initial);
                    _controller.move(widget.initial, 14);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
