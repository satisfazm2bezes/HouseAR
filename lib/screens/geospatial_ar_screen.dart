import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tela AR com Geospatial API nativo
///
/// A PlatformView nativa gerencia TUDO: ARCore Session, câmera, VPS, model placement
/// NÃO chamamos GeospatialARService aqui para evitar conflito de sessões
class GeospatialARScreen extends ConsumerStatefulWidget {
  const GeospatialARScreen({super.key});

  @override
  ConsumerState<GeospatialARScreen> createState() => _GeospatialARScreenState();
}

class _GeospatialARScreenState extends ConsumerState<GeospatialARScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ARCore Geospatial - VPS Nativo'),
        backgroundColor: Colors.black87,
      ),
      body: Platform.isAndroid
          ? const AndroidView(viewType: 'ar_geospatial_view')
          : const Center(
              child: Text(
                'ARCore Geospatial apenas disponível em Android',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
    );
  }
}
