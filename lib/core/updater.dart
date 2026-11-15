import 'dart:convert';
import 'package:http/http.dart' as http;

/// رقم النسخة الحالية (بيتمرّر وقت البناء من الـ workflow: --dart-define=APP_VERSION=1.0.N).
const String kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

/// مستودع GitHub اللي بتنزل فيه النسخ (owner/repo) — بيتمرّر وقت البناء: --dart-define=GITHUB_REPO=owner/repo.
const String kGithubRepo = String.fromEnvironment('GITHUB_REPO');

class UpdateInfo {
  final String version, notes, url;
  const UpdateInfo(this.version, this.notes, this.url);
}

/// مقارنة أرقام النسخ (1.0.12 > 1.0.9). دالة نقية لسهولة الاختبار.
bool isNewerVersion(String latest, String current) {
  List<int> parse(String v) => [for (final x in v.replaceFirst(RegExp(r'^[vV]'), '').split(RegExp(r'[.+\-]'))) int.tryParse(x) ?? 0];
  final a = parse(latest), b = parse(current);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// يفحص آخر release على GitHub. يرجّع null لو مفيش تحديث أو حصل أي فشل (بدون إنترنت، حد معدّل... إلخ).
Future<UpdateInfo?> checkForUpdate({http.Client? client}) async {
  if (kGithubRepo.isEmpty) return null;
  final c = client ?? http.Client();
  try {
    final res = await c.get(Uri.parse('https://api.github.com/repos/$kGithubRepo/releases/latest'), headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body);
    if (j is! Map) return null;
    final tag = '${j['tag_name'] ?? ''}';
    if (tag.isEmpty || !isNewerVersion(tag, kAppVersion)) return null;
    String url = '${j['html_url'] ?? ''}';
    final assets = j['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is Map && '${a['name']}'.endsWith('.apk') && '${a['browser_download_url'] ?? ''}'.isNotEmpty) {
          url = '${a['browser_download_url']}';
          break;
        }
      }
    }
    return UpdateInfo(tag, '${j['body'] ?? ''}', url);
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}
