---
name: release
description: Собирает релиз планера — проверки, bump версии, Windows MSIX и Android APK в папку dist/, тег в git.
disable-model-invocation: true
argument-hint: [версия, например 0.3.0]
---
Собери релиз версии **$ARGUMENTS**.

1. Рабочее дерево чистое (`git status`); иначе остановись.
2. `dart test` в packages/oplog_sync, `flutter analyze`, `dart format --set-exit-if-changed .`,
   `flutter test` — всё зелёное, покажи итог.
3. Обнови `version:` в pubspec.yaml (semver + build number +1) и раздел в CHANGELOG.md из коммитов
   с прошлого тега (`git log <tag>..HEAD --oneline`).
4. Windows: `flutter build windows --release`, затем `dart run msix:create` (конфиг msix в pubspec;
   self-signed сертификат из `windows/cert/` — если нет, объясни, как создать, и остановись).
5. Android: `flutter build apk --release` (подпись из android/key.properties; если нет — debug-подпись
   и предупреждение в отчёте).
6. Скопируй артефакты в `dist/<версия>/` с именами planner-<версия>-windows.msix и planner-<версия>-android.apk.
7. Коммит `chore(release): v<версия>`, тег `v<версия>`. Пуш — только если пользователь попросил.

Отчёт: версия, пути артефактов, размер файлов, что подписано и чем.
