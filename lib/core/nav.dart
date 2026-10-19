import 'package:flutter/material.dart';

/// مفتاح الـ Navigator العام (للتنقّل من الإشعارات/الروابط بدون BuildContext).
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

/// التبويب الحالي في الشريط السفلي: 0 الحسابات · 1 المعاملات · 2 الاشتراكات · 3 المزيد.
final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);
