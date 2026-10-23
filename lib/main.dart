import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  // ProviderScope — корень Riverpod: хранит состояние всех провайдеров.
  runApp(const ProviderScope(child: PlannerApp()));
}
