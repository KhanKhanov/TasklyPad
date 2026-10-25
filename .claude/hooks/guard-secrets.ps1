# PreToolUse (Bash|PowerShell): blocks shell commands that touch signing keys and secrets.
# Read(...) deny rules in settings.json cover the Read tool and only some shell readers (cat, head...);
# grep, Get-Content, type, copy and scripts are not covered - hence this hook.
# Exit code 2 = deny the tool call; stderr text is shown to Claude.
# ASCII only: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $evt = $raw | ConvertFrom-Json } catch { exit 0 }
$cmd = $evt.tool_input.command
if (-not $cmd) { exit 0 }
$patterns = @(
    'key\.properties',
    'signing\.properties',
    '\.(jks|keystore|pfx|p12|pem)\b',
    '(^|[\s/\\"''=])\.env(\.[\w-]+)?($|[\s"''])',
    'upload-keystore'
)
foreach ($p in $patterns) {
    if ($cmd -match $p) {
        [Console]::Error.WriteLine("BLOCKED: the command references a secret file (pattern: $p). Signing keys and secrets are read only by the user. If the match is a false positive, rephrase the command without the file name.")
        exit 2
    }
}
exit 0
