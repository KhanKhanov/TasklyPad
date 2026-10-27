#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <optional>
#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Профиль данных из `--profile <имя>` или `--profile=<имя>`; `nullopt` —
// основной. `--profile` без имени даёт пустую строку — неверное имя. Те же
// правила разбора — в lib/app/profile.dart: там же выбирается папка данных
// профиля и показывается ошибка неверного имени.
std::optional<std::string> ProfileFromArguments(
    const std::vector<std::string>& args) {
  const std::string flag = "--profile";
  for (size_t i = 0; i < args.size(); ++i) {
    if (args[i] == flag) {
      return i + 1 < args.size() ? args[i + 1] : std::string();
    }
    if (args[i].rfind(flag + "=", 0) == 0) {
      return args[i].substr(flag.size() + 1);
    }
  }
  return std::nullopt;
}

// Имя профиля: латинские строчные буквы, цифры и дефис, до 32 символов, и не
// имя устройства Windows (`con`, `nul`, `com1`…): имя — часть пути.
bool IsValidProfile(const std::string& name) {
  if (name.empty() || name.size() > 32) return false;
  for (char c : name) {
    if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-')) {
      return false;
    }
  }
  for (const char* device : {"con", "prn", "aux", "nul"}) {
    if (name == device) return false;
  }
  const bool numbered = name.size() == 4 && name[3] >= '1' && name[3] <= '9';
  if (numbered && (name.rfind("com", 0) == 0 || name.rfind("lpt", 0) == 0)) {
    return false;
  }
  return true;
}

// Заголовок окна: по нему второй запуск находит окно первого. У профиля —
// своё имя, чтобы окна двух профилей не путались.
std::wstring WindowTitle(const std::string& profile) {
  std::wstring title = L"planner";
  if (!profile.empty()) {
    // Тире — escape-последовательностью: MSVC читает исходник в кодировке
    // системы, и символ UTF-8 в строке превратился бы в «вЂ”».
    title += L" \u2014 " + std::wstring(profile.begin(), profile.end());
  }
  return title;
}

// Показать окно уже запущенного экземпляра. Оно может ещё создаваться
// (два запуска подряд) — ждём его до 5 секунд. `false` — окна нет.
// ShowWindowAsync, а не ShowWindow: окно чужого процесса, и если тот завис,
// синхронный вызов повис бы и в этом процессе.
bool ShowRunningInstance(const std::wstring& title) {
  for (int attempt = 0; attempt < 50; ++attempt) {
    HWND window = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", title.c_str());
    if (window != nullptr) {
      ::ShowWindowAsync(window, ::IsIconic(window) ? SW_RESTORE : SW_SHOW);
      ::SetForegroundWindow(window);
      return true;
    }
    ::Sleep(100);
  }
  return false;
}

// Имя mutex: у основного профиля — без суффикса, у профиля — с префиксом
// `p.`, чтобы `--profile default` не делил замок с основным.
std::wstring MutexName(const std::string& profile) {
  std::wstring name = L"Local\\planner.instance";
  if (!profile.empty()) {
    name += L".p." + std::wstring(profile.begin(), profile.end());
  }
  return name;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const std::optional<std::string> requested =
      ProfileFromArguments(command_line_arguments);
  const std::string profile = requested.value_or(std::string());
  const bool valid = !requested.has_value() || IsValidProfile(profile);
  // У неверного имени — свой ASCII-заголовок: окно экрана ошибки не
  // совпадёт с окном рабочего экземпляра, а байты не-ASCII имени не попадут
  // в заголовок.
  const std::wstring title = WindowTitle(valid ? profile : "invalid-profile");

  // Один экземпляр на профиль, как в Todoist: два процесса с одной базой
  // писали бы журнал с разными часами (SYNC_DESIGN «Узел и запуск»).
  // Неверное имя профиля mutex не берёт — ошибку покажет само приложение.
  HANDLE instance_mutex = nullptr;
  if (valid) {
    instance_mutex = ::CreateMutexW(nullptr, TRUE, MutexName(profile).c_str());
    const DWORD error = ::GetLastError();
    if (instance_mutex == nullptr && error == ERROR_ACCESS_DENIED) {
      // Замок создал процесс с другими правами (запуск от администратора):
      // приложение уже работает.
      ShowRunningInstance(title);
      return EXIT_SUCCESS;
    }
    if (instance_mutex == nullptr) {
      // Проверить второй экземпляр нельзя — не запускаемся: сохранность
      // данных важнее. Текст до Dart, без l10n — по-английски, ASCII.
      ::MessageBoxW(nullptr,
                    L"planner could not check whether it is already running, "
                    L"so it did not start. Your data was not changed.",
                    L"planner", MB_OK | MB_ICONERROR);
      return EXIT_FAILURE;
    }
    if (error == ERROR_ALREADY_EXISTS) {
      if (ShowRunningInstance(title)) {
        ::CloseHandle(instance_mutex);
        return EXIT_SUCCESS;
      }
      // Окна нет: прежний экземпляр как раз закрывается (окно уже
      // уничтожено, процесс ещё освобождает базу). Ждём его замок и, если
      // дождались — в том числе брошенный упавшим процессом, — работаем как
      // первый экземпляр.
      const DWORD wait = ::WaitForSingleObject(instance_mutex, 10000);
      if (wait != WAIT_OBJECT_0 && wait != WAIT_ABANDONED) {
        ::CloseHandle(instance_mutex);
        return EXIT_SUCCESS;
      }
    }
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(title, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (instance_mutex != nullptr) ::CloseHandle(instance_mutex);
  return EXIT_SUCCESS;
}
