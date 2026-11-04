/// Размеры раскладки, общие для экранов.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Ширина, начиная с которой сайдбар стоит рядом с контентом, а не
/// выезжает поверх (телефон, узкое окно): макет desktop — от 900 px.
const double wideLayoutWidth = 900;

/// Ширина колонки контента, как у Todoist на широком экране.
const double contentMaxWidth = 800;

/// Касаний больше, чем мыши: узкий экран или мыши нет (планшет, сенсорный
/// экран). Наведения тогда не бывает, а клика с `Ctrl` и `Shift` — тоже:
/// «⋯» строки виден всегда (решение 1А «Ход M4.7»), выделение — через
/// «Выбрать задачи» (решение 9 плана M4). Подключение мыши не перестраивает
/// экран само: кому это важно, слушает `RendererBinding.mouseTracker`.
bool touchLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < wideLayoutWidth ||
    !RendererBinding.instance.mouseTracker.mouseIsConnected;
