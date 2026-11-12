import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/features/views/ui/view_options_button.dart';

/// Кружок с числом [count] на кнопке «Отображение» (решение 10Б M4.10a).
Finder badge(String count) => find.descendant(
  of: find.byType(ViewOptionsButton),
  matching: find.descendant(
    of: find.byKey(const ValueKey('viewOptionsBadge')),
    matching: find.text(count),
  ),
);

/// Кружок с любым числом.
Finder anyBadge() => find.byKey(const ValueKey('viewOptionsBadge'));
