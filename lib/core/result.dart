/// Результат операции, которая может не получиться: [Ok] или [Err].
///
/// Вместо исключений «вверх по стеку» функция честно возвращает одно из двух,
/// а вызывающий обязан обработать оба случая (`sealed` + исчерпывающий `switch`).
/// Исключения оставляем для ошибок программиста, [Result] — для ожидаемых
/// сбоев: файл не найден, запрос фильтра не разбирается, папка недоступна.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Object error, [StackTrace? stackTrace]) = Err<T>;

  /// Выполнить [body], превратив брошенное исключение в [Err].
  static Future<Result<T>> guard<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } catch (e, st) {
      return Err(e, st);
    }
  }

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// Свернуть оба случая в одно значение.
  R fold<R>(R Function(T value) onOk, R Function(Object error) onErr) =>
      switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final error) => onErr(error),
      };

  /// Преобразовать значение, не трогая ошибку.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok(transform(value)),
    Err(:final error, :final stackTrace) => Err(error, stackTrace),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;

  @override
  String toString() => 'Err($error)';
}
