# PreToolUse (Edit|Write): blocks manual edits of generated Dart files.
# Exit code 2 = deny the tool call; stderr text is shown to Claude.
# ASCII only: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $evt = $raw | ConvertFrom-Json } catch { exit 0 }
$path = $evt.tool_input.file_path
if (-not $path) { exit 0 }
if ($path -match '\.(g|freezed|drift|gr|mocks)\.dart$') {
    [Console]::Error.WriteLine("BLOCKED: $path is a generated file. Edit the source file and run: dart run build_runner build -d")
    exit 2
}
exit 0
