# PostToolUse (Edit|Write): runs dart format on the edited .dart file. Never fails.
# ASCII only: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $evt = $raw | ConvertFrom-Json } catch { exit 0 }
$path = $evt.tool_input.file_path
if (-not $path) { exit 0 }
if ($path -notlike '*.dart') { exit 0 }
if (-not (Test-Path -LiteralPath $path)) { exit 0 }
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) { exit 0 }
try { & dart format $path | Out-Null } catch { }
exit 0
