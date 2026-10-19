import 'extras.dart';

/// إشعار مخطّط (منطق صِرف بدون أي مكتبة) — قابل للاختبار.
class NotifPlan {
  final int id;
  final String title, body, payload;
  final DateTime at;
  const NotifPlan(this.id, this.title, this.body, this.at, this.payload);
}

const int kRemindHour = 9;
const int kMaxPlans = 60;

DateTime _at(DateTime day, int daysBefore) => DateTime(day.year, day.month, day.day - daysBefore, kRemindHour);

String _amt(double v) {
  final s = v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  return '$s ج.م';
}

/// يحسب إشعارات التذكير القادمة: تجديد الاشتراكات (وانتهاء التجربة)، القسط التالي، وقسط الجمعية الشهري.
List<NotifPlan> planReminders(List<Sub> subs, List<Inst> insts, List<Assoc> assocs, DateTime now) {
  final out = <NotifPlan>[];
  var n = 0;
  int id() => 1000 + n++;

  for (final s in subs) {
    if (s.state != 'active' || s.remind < 0) continue;
    // أقرب تجديدين قادمين
    DateTime? d = s.nextDue;
    for (var k = 0; k < 2 && d != null; k++) {
      final at = _at(d, s.remind);
      if (at.isAfter(now)) {
        final when = s.remind == 0 ? 'النهارده' : (s.remind == 1 ? 'بكرة' : 'بعد ${s.remind} أيام');
        final trial = s.inTrial && k == 0;
        out.add(NotifPlan(id(), trial ? 'التجربة المجانية بتخلص' : 'تجديد اشتراك', trial ? '${s.name}: التجربة بتخلص $when وبعدها هيتسحب ${_amt(s.amt)}' : '${s.name} هيتجدد $when بـ ${_amt(s.amt)}', at, 'sub/${s.id}'));
      }
      if (s.cyc == 'once' || (k == 0 && s.inTrial)) break;
      d = nextCycle(d, s.cyc);
      if (s.until > 0 && d.millisecondsSinceEpoch > s.until) break;
    }
  }

  for (final i in insts) {
    final d = i.nextDue;
    if (i.done || d == null) continue;
    final at = _at(d, 1);
    if (at.isAfter(now)) out.add(NotifPlan(id(), 'قسط قريب', '${i.name}: القسط ${i.pays.length + 1} من ${i.count} بكرة (${_amt(i.each)})', at, 'inst'));
  }

  for (final a in assocs) {
    if (a.monthsDone >= a.members) continue;
    final d = addMonths(a.startDate, a.monthsDone);
    final at = _at(d, 1);
    if (at.isAfter(now)) out.add(NotifPlan(id(), 'قسط جمعية', '${a.name}: قسط الشهر بكرة (${_amt(a.amt)})', at, 'assoc'));
  }

  out.sort((x, y) => x.at.compareTo(y.at));
  return out.length > kMaxPlans ? out.sublist(0, kMaxPlans) : out;
}
