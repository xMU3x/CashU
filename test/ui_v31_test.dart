import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:cashu/ui/shell_scope.dart' show RouteCover;
import 'package:cashu/ui/sort_btn.dart' show kSortOptions, kSortIcons;

String src(String path) => File(path).readAsStringSync();

void main() {
  testWidgets('RouteCover reports covered while another route is on top and uncovered after pop', (t) async {
    final nav = GlobalKey<NavigatorState>();
    bool? seen;
    await t.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: RouteCover(builder: (c, covered) {
        seen = covered;
        return const SizedBox();
      }),
    ));
    expect(seen, false);
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const SizedBox()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(seen, true); // أثناء الانتقال = covered (نوقف الـ blur)
    await t.pumpAndSettle();
    expect(seen, true);
    nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(seen, false);
  });

  test('every sort option has an icon', () {
    for (final o in kSortOptions) {
      expect(kSortIcons.containsKey(o.$1), true, reason: o.$1);
    }
  });

  test('add-transaction button lives next to the bottom bar, not in the top bars', () {
    expect(src('lib/app.dart').contains('_addBtn(p)'), true);
    expect(src('lib/app.dart').contains('sheetRoute(const AddTxPage())'), true);
    expect(src('lib/pages/accounts_home.dart').contains('_addTxBtn'), false);
    expect(src('lib/pages/acc_tx.dart').contains('!widget.pick && !bulk && !widget.embedded'), true);
  });

  test('dues: no "undo last payment" buttons, per-payment undo exists', () {
    final s = src('lib/pages/loans_page.dart');
    expect(s.contains('تراجع عن آخر سداد'), false);
    expect(s.contains('undoLoanPay(context, l, i)'), true);
    expect(s.contains("Text('تراجع عن السداد'"), true);
  });

  test('long-press menus share the pop panel style', () {
    expect(src('lib/ui/acc_menu.dart').contains('showCenteredPopMenu'), true);
    final ios = src('lib/ui/ios.dart');
    expect(ios.contains('class PopMenuPanel'), true);
    expect('PopMenuPanel('.allMatches(ios).length, greaterThanOrEqualTo(3)); // الصنف + showPopMenu + showCenteredPopMenu
  });

  test('transitions: tab taps in add-transaction switch content instantly; account edit has no extra switcher animation', () {
    expect(src('lib/pages/add_tx.dart').contains('pc.jumpToPage(v)'), true);
    expect(src('lib/pages/add_tx.dart').contains('animateToPage'), false);
    expect(src('lib/pages/acc_edit.dart').contains('SegSwitcher'), false);
  });
}
