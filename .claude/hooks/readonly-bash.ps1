# PreToolUse (Bash) for read-only reviewer agents: allows only whitelisted read/check commands.
# The command line is split into segments by ; && || | and newlines outside quotes; every segment must
# start with a whitelisted command. Redirection to files, command substitution and process
# substitution are blocked. When in doubt - block (exit code 2, stderr text is shown to the agent).
# ASCII only: Windows PowerShell 5.1 reads BOM-less scripts as ANSI.
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $evt = $raw | ConvertFrom-Json } catch { exit 0 }
$cmd = [string]$evt.tool_input.command
if (-not $cmd) { exit 0 }

function Deny([string]$why) {
    [Console]::Error.WriteLine("BLOCKED (read-only agent): $why. Allowed: flutter analyze/test, dart analyze/test/format --output=none, git status/diff/log/show/blame/ls-files/grep, grep, rg, cat, head, tail, ls, wc, find (no -exec/-delete), sort, uniq, cut, tr, sed -n, echo, pwd, cd. Describe the needed change in your report instead.")
    exit 2
}

# Split outside quotes; reject dangerous syntax outside single quotes.
$segments = New-Object System.Collections.Generic.List[string]
$cur = New-Object System.Text.StringBuilder
$quote = [char]0
for ($i = 0; $i -lt $cmd.Length; $i++) {
    $c = $cmd[$i]
    $next = if ($i + 1 -lt $cmd.Length) { $cmd[$i + 1] } else { [char]0 }
    if ($quote -ne [char]0) {
        if ($c -eq $quote) { $quote = [char]0 }
        elseif ($quote -eq '"' -and ($c -eq '`' -or ($c -eq '$' -and $next -eq '('))) { Deny 'command substitution' }
        [void]$cur.Append($c); continue
    }
    if ($c -eq "'" -or $c -eq '"') { $quote = $c; [void]$cur.Append($c); continue }
    if ($c -eq '`' -or ($c -eq '$' -and $next -eq '(')) { Deny 'command substitution' }
    if (($c -eq '<' -or $c -eq '>') -and $next -eq '(') { Deny 'process substitution' }
    if ($c -eq '>') {
        # Allow only 2>&1 and redirects to /dev/null.
        $rest = $cmd.Substring($i)
        if ($rest -match '^>&\d') { [void]$cur.Append($rest.Substring(0, 3)); $i += 2; continue }
        if ($rest -match '^>>?\s*/dev/null') { [void]$cur.Append($c); continue }
        Deny 'redirection to a file'
    }
    if ($c -eq ';' -or $c -eq "`n" -or $c -eq '|' -or ($c -eq '&' -and $next -eq '&')) {
        $segments.Add($cur.ToString()); [void]$cur.Clear()
        if (($c -eq '|' -and $next -eq '|') -or ($c -eq '&' -and $next -eq '&')) { $i++ }
        continue
    }
    if ($c -eq '&') { Deny 'background execution' }
    [void]$cur.Append($c)
}
if ($quote -ne [char]0) { Deny 'unbalanced quotes' }
$segments.Add($cur.ToString())

$simple = '^(grep|rg|cat|head|tail|ls|wc|sort|uniq|cut|tr|echo|printf|pwd|cd|true|test|diff)$'
foreach ($seg in $segments) {
    $s = $seg.Trim()
    if (-not $s) { continue }
    $words = $s -split '\s+'
    $w0 = ($words[0] -replace '^.*[\\/]', '') -replace '\.(bat|exe)$', ''
    $w1 = if ($words.Count -gt 1) { $words[1] } else { '' }
    $ok = $false
    if ($w0 -match $simple) { $ok = $true }
    elseif ($w0 -eq 'flutter') { $ok = $w1 -match '^(analyze|test|--version|doctor)$' -or $s -match '^\S+\s+pub\s+(outdated|deps)\b' }
    elseif ($w0 -eq 'dart') {
        $ok = $w1 -match '^(analyze|test|--version)$' -or ($w1 -eq 'format' -and $s -match '--output=none')
    }
    elseif ($w0 -eq 'git') { $ok = $w1 -match '^(status|diff|log|show|blame|ls-files|grep|rev-parse)$' }
    elseif ($w0 -eq 'find') { $ok = $s -notmatch '\s-(exec|execdir|delete|ok|okdir|fprint\w*|fls)\b' }
    elseif ($w0 -eq 'sed') { $ok = $s -match '\s-n\b' -and $s -notmatch '\s-i' -and $s -notmatch '[/\s]w\s' }
    if (-not $ok) { Deny "'$($words[0])' is not in the read-only whitelist" }
}
exit 0
