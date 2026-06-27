import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Regenerates `image/app_icon.png` and Android/iOS/Web launcher icons.
///
/// Usage (from project root):
///   dart run tools/zoom_icon.dart          # default fillRatio 0.75
///   dart run tools/zoom_icon.dart 0.80     # custom zoom (0.5–0.95)
///
/// After running, uninstall the app on the emulator/device then reinstall —
/// launcher icons are not updated by hot reload or flutter run alone.
Future<void> main(List<String> args) async {
  final fillRatio = _parseFillRatio(args);
  final source = _findSourceLogo();
  final bytes = await source.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Could not decode ${source.path}');
  }

  final bounds = _contentBounds(decoded);
  final pad = (bounds.width > bounds.height ? bounds.width : bounds.height) *
      0.04;
  final cropX = (bounds.minX - pad).floor().clamp(0, decoded.width - 1);
  final cropY = (bounds.minY - pad).floor().clamp(0, decoded.height - 1);
  final cropW =
      (bounds.width + 2 * pad).ceil().clamp(1, decoded.width - cropX);
  final cropH =
      (bounds.height + 2 * pad).ceil().clamp(1, decoded.height - cropY);

  final cropped = img.copyCrop(
    decoded,
    x: cropX,
    y: cropY,
    width: cropW,
    height: cropH,
  );

  final logoOnly = _removeBlackBackground(cropped);

  await _saveZoomed(
    logoOnly,
    File('image/app_icon.png'),
    fillRatio: fillRatio,
    background: img.ColorRgba8(255, 255, 255, 255),
  );

  stdout.writeln(
    'Saved image/app_icon.png from ${source.path} (fillRatio: $fillRatio)',
  );
  await _runLauncherIcons();
}

double _parseFillRatio(List<String> args) {
  const defaultFillRatio = 0.6;
  if (args.isEmpty) return defaultFillRatio;
  final value = double.tryParse(args.first);
  if (value == null || value < 0.5 || value > 0.95) {
    throw ArgumentError(
      'fillRatio must be between 0.5 and 0.95, got "${args.first}"',
    );
  }
  return value;
}

Future<void> _runLauncherIcons() async {
  stdout.writeln('Running flutter_launcher_icons...');
  final result = await Process.run(
    'dart',
    ['run', 'flutter_launcher_icons'],
    runInShell: true,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw StateError(
      'flutter_launcher_icons failed (exit ${result.exitCode})',
    );
  }
  stdout.writeln(
    '\nDone. Uninstall SacoStay on your device/emulator, then run: flutter run',
  );
}

File _findSourceLogo() {
  final imageDir = Directory('image');
  for (final entity in imageDir.listSync()) {
    if (entity is! File) continue;
    final name = entity.path.toLowerCase();
    if (!name.endsWith('.png')) continue;
    if (name.contains('logosacostay')) {
      return entity;
    }
  }
  return File('image/app_icon.png');
}

class _Bounds {
  _Bounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  int get width => maxX - minX + 1;
  int get height => maxY - minY + 1;
}

_Bounds _contentBounds(img.Image image) {
  var minX = image.width;
  var minY = image.height;
  var maxX = 0;
  var maxY = 0;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      if (_isLogoPixel(pixel)) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
  }

  return _Bounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

bool _isLogoPixel(img.Pixel pixel) {
  final a = pixel.a;
  final r = pixel.r;
  final g = pixel.g;
  final b = pixel.b;
  if (a <= 10) return false;
  return r > 20 || g > 20 || b > 20;
}

img.Image _removeBlackBackground(img.Image image, {int threshold = 32}) {
  final out = img.Image.from(image);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r;
      final g = pixel.g;
      final b = pixel.b;
      if (r <= threshold && g <= threshold && b <= threshold) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
  return out;
}

Future<void> _saveZoomed(
  img.Image logo,
  File outFile, {
  required double fillRatio,
  required img.Color background,
}) async {
  const size = 1024;
  final maxDim = size * fillRatio;
  final scale = maxDim /
      (logo.width > logo.height ? logo.width : logo.height);
  final newW = (logo.width * scale).round();
  final newH = (logo.height * scale).round();
  final destX = ((size - newW) / 2).round();
  final destY = ((size - newH) / 2).round();

  final out = img.Image(width: size, height: size);
  img.fill(out, color: background);
  img.compositeImage(
    out,
    img.copyResize(logo, width: newW, height: newH),
    dstX: destX,
    dstY: destY,
  );

  await outFile.writeAsBytes(Uint8List.fromList(img.encodePng(out)));
}
