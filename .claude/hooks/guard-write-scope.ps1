# PreToolUse (Edit|Write) for scoped subagents: allows writes only to paths matching -Allow.
# -Allow is a regex over the path RELATIVE to the project root, with forward slashes.
# Exit code 2 = deny the tool call; stderr text is shown to the agent.
# ASCII only: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.
param([Parameter(Mandatory = $true)][string]$Allow)
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $evt = $raw | ConvertFrom-Json } catch { exit 0 }
$path = $evt.tool_input.file_path
if (-not $path) { exit 0 }
$root = $env:CLAUDE_PROJECT_DIR
if (-not $root) { $root = $evt.cwd }
if (-not $root) { exit 0 }
$norm = ($path -replace '\\', '/')
$rootNorm = ($root -replace '\\', '/').TrimEnd('/')
if (-not $norm.StartsWith($rootNorm + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
    [Console]::Error.WriteLine("BLOCKED: $path is outside the project. This agent may write only paths matching: $Allow")
    exit 2
}
$rel = $norm.Substring($rootNorm.Length + 1)
if ($rel -match $Allow) { exit 0 }
[Console]::Error.WriteLine("BLOCKED: $rel is outside this agent's write scope ($Allow). Describe the needed change in your report instead of editing.")
exit 2
