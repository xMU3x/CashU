import 'package:flutter/material.dart';
import 'repo.dart';
import 'settings.dart';
import 'store.dart';

/// المجموعات الافتراضية (تظل موجودة ويمكن تعديلها أو إضافة مجموعات مخصّصة بجانبها).
const kGroupNames = ['Cash', 'Bank Accounts', 'Credit', 'eWallets', 'Debit Cards'];

/// ألوان اختيار المجموعة (مطابقة لشريط الألوان في صورة Edit Group).
const kGroupPalette = <Color>[
  Color(0xFFFF3B5C),
  Color(0xFFFF6A00),
  Color(0xFFFFB800),
  Color(0xFF28A745),
  Color(0xFF1EA7FD),
  Color(0xFFC561E0),
  Color(0xFFA68A64),
  Color(0xFF5C6770),
  Color(0xFFFFFFFF),
];

/// بيانات المجموعة الإضافية (لون/عملة) محفوظة داخل الإعدادات tyr_set تحت المفتاح grpMeta.
Map<String, dynamic> _meta() {
  final m = store.peekMap('tyr_set')['grpMeta'];
  return m is Map ? Map<String, dynamic>.from(m) : <String, dynamic>{};
}

Color? groupColorOf(String name) {
  final m = _meta()[name];
  if (m is Map && m['c'] is num) return Color((m['c'] as num).toInt());
  return null;
}

String groupCurOf(String name) {
  final m = _meta()[name];
  return (m is Map && m['cur'] is String) ? m['cur'] as String : S.cur;
}

/// كل أسماء المجموعات: الافتراضية + المخصّصة + أي مجموعة مستخدمة فعلًا في حساب.
List<String> allGroupNames() {
  final out = <String>[...kGroupNames];
  for (final n in S.list('customGroups')) {
    if (!out.contains(n)) out.add(n);
  }
  for (final a in repo.accList) {
    if (!out.contains(a.group)) out.add(a.group);
  }
  return out;
}

/// ينشئ مجموعة جديدة ([old] == null) أو يعدّل مجموعة موجودة (اسم/لون/عملة/الحسابات الأعضاء).
/// يرجع false لو الاسم فاضي أو مكرر.
bool saveGroup({String? old, required String name, required Color color, required String cur, required Set<String> members}) {
  name = name.trim();
  if (name.isEmpty) return false;
  if (name != old && allGroupNames().any((g) => g.toLowerCase() == name.toLowerCase())) { return false; }

  final custom = S.list('customGroups')..remove(old);
  if (!kGroupNames.contains(name) && !custom.contains(name)) custom.add(name);
  S.put('customGroups', custom);

  final meta = _meta();
  if (old != null) meta.remove(old);
  meta[name] = {'c': color.toARGB32(), 'cur': cur};
  S.put('grpMeta', meta);

  if (old != null && old != name) {
    final folded = S.list('foldedGroups');
    if (folded.remove(old)) {
      folded.add(name);
      S.put('foldedGroups', folded);
    }
  }

  for (final a in repo.accList) {
    if (members.contains(a.id)) {
      if (a.grp != name) {
        a.grp = name;
        repo.saveAccount(a);
      }
    } else if (old != null && a.group == old) {
      // اتشال من المجموعة: يرجع للمجموعة الافتراضية حسب نوعه.
      a.grp = '';
      repo.saveAccount(a);
    }
  }
  return true;
}
