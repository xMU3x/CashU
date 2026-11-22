import 'package:material_ui/material_ui.dart' hide Text;
import '../core/models.dart';
import '../core/util.dart' show tick;
import 'ios.dart';

/// إجراء داخل قائمة الحساب (الضغطة المطولة أو زر «...»).
class AccMenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger, dividerBefore;
  const AccMenuAction(this.icon, this.label, this.onTap, {this.danger = false, this.dividerBefore = false});
}

/// قائمة الحساب (الضغطة المطولة أو زر «...») — بنفس شكل باقي القوائم المنبثقة: صفوف بدون خلفيات، الأيقونة في البداية
/// والنص جنبها، وفاصل رفيع قبل مجموعة الأرشفة/الحذف.
Future<void> showAccountMenu(BuildContext context, Account a, List<AccMenuAction> actions) {
  tick();
  final items = <PopItem>[];
  for (var i = 0; i < actions.length; i++) {
    final x = actions[i];
    final firstDanger = x.danger && i > 0 && !actions[i - 1].danger;
    items.add(PopItem(x.icon, x.label, x.onTap, danger: x.danger, divider: x.dividerBefore || firstDanger));
  }
  return showCenteredPopMenu(context, items, label: 'account-menu');
}
