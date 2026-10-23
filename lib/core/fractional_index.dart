/// Fractional index: строковые ключи порядка, между любыми двумя из которых
/// всегда можно вставить третий.
///
/// Ключ — «дробь» в системе счисления с основанием 62 (цифры `0-9A-Za-z`
/// в порядке ASCII, поэтому сравнение строк совпадает с числовым). При
/// перетаскивании меняется ключ одного элемента, а не номера всех соседей —
/// два устройства, переставившие разные элементы офлайн, не конфликтуют.
///
/// Инвариант: ключ не заканчивается на `0` (иначе перед ним нельзя вставить).
library;

const String _alphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
final int _base = _alphabet.length;

int _digit(String ch) {
  final d = _alphabet.indexOf(ch);
  if (d < 0) throw FormatException('Недопустимый символ ключа порядка', ch);
  return d;
}

/// Ключ строго между [a] и [b]. `null` означает «начало» (для [a]) или
/// «конец» (для [b]) списка. `between(null, null)` — первый ключ пустого списка.
String between(String? a, String? b) {
  final lo = a ?? '';
  final hi = b ?? '';
  if (hi.isNotEmpty && lo.compareTo(hi) >= 0) {
    throw ArgumentError('Ожидалось a < b, получено "$lo" >= "$hi"');
  }
  if (lo.endsWith('0') || hi.endsWith('0')) {
    throw ArgumentError('Ключ порядка не может заканчиваться на "0"');
  }
  if (lo.isEmpty && hi.isEmpty) return _alphabet[_base ~/ 2];
  if (hi.isEmpty) return _after(lo);
  if (lo.isEmpty) return _before(hi);
  return _midpoint(lo, hi);
}

/// Ключ сразу после [a] (добавление в конец): увеличиваем последнюю цифру,
/// а если она уже максимальная — дописываем «1». Ключ растёт на символ
/// раз в ~60 добавлений, а не каждые 5, как при делении пополам.
String _after(String a) {
  final last = _digit(a[a.length - 1]);
  if (last < _base - 1) {
    return a.substring(0, a.length - 1) + _alphabet[last + 1];
  }
  return a + _alphabet[1];
}

/// Ключ сразу перед [b] (добавление в начало): уменьшаем последнюю цифру;
/// если она «1», уходим на разряд глубже: `…1` → `…0V`.
String _before(String b) {
  final last = _digit(b[b.length - 1]);
  final prefix = b.substring(0, b.length - 1);
  if (last > 1) return prefix + _alphabet[last - 1];
  return '$prefix${_alphabet[0]}${_alphabet[_base ~/ 2]}';
}

String _midpoint(String a, String b) {
  // Общий префикс отбрасываем и решаем задачу для хвостов.
  if (b.isNotEmpty) {
    var n = 0;
    while (n < b.length && (n < a.length ? a[n] : '0') == b[n]) {
      n++;
    }
    if (n > 0) {
      return b.substring(0, n) +
          _midpoint(a.length > n ? a.substring(n) : '', b.substring(n));
    }
  }
  final da = a.isEmpty ? 0 : _digit(a[0]);
  final db = b.isEmpty ? _base : _digit(b[0]);
  if (db - da > 1) {
    // Есть свободная цифра между — берём середину (никогда не 0).
    return _alphabet[(da + db) ~/ 2];
  }
  // Соседние цифры: уточняем за счёт следующего разряда.
  if (b.length > 1) {
    // b длиннее: его первая цифра сама по себе меньше b и больше a.
    return b[0];
  }
  return _alphabet[da] + _midpoint(a.isEmpty ? '' : a.substring(1), '');
}

/// Ключи для [count] элементов, равномерно после [after] (например, при импорте).
List<String> sequence(int count, {String? after}) {
  final keys = <String>[];
  var prev = after;
  for (var i = 0; i < count; i++) {
    prev = between(prev, null);
    keys.add(prev);
  }
  return keys;
}
