import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart' show FilterQuality;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// يحوّل أي صورة إلى مربع 128×128 PNG داخل data-URI (خفيف ويعمل أوفلاين ويتزامن مع الحساب).
Future<String?> squareDataUri(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
    final img = (await codec.getNextFrame()).image;
    const out = 128;
    final s = math.min(img.width, img.height).toDouble();
    final rec = ui.PictureRecorder();
    final cv = ui.Canvas(rec);
    cv.drawImageRect(
      img,
      ui.Rect.fromLTWH((img.width - s) / 2, (img.height - s) / 2, s, s),
      ui.Rect.fromLTWH(0, 0, out.toDouble(), out.toDouble()),
      ui.Paint()..filterQuality = FilterQuality.high,
    );
    final res = await rec.endRecording().toImage(out, out);
    final bd = await res.toByteData(format: ui.ImageByteFormat.png);
    if (bd == null) return null;
    return 'data:image/png;base64,${base64Encode(bd.buffer.asUint8List())}';
  } catch (_) {
    return null;
  }
}

/// رفع صورة من المعرض.
Future<String?> pickIconFromGallery() async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
  if (f == null) return null;
  return squareDataUri(await f.readAsBytes());
}

/// سحب صورة من رابط ثم حفظها محليًا (حد أقصى 5MB، رابط https/http فقط).
Future<String?> iconFromUrl(String url) async {
  final u = Uri.tryParse(url.trim());
  if (u == null || !(u.scheme == 'https' || u.scheme == 'http')) return null;
  try {
    final r = await http.get(u).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200 || r.bodyBytes.length > 5 * 1024 * 1024) { return null; }
    return await squareDataUri(r.bodyBytes);
  } catch (_) {
    return null;
  }
}
