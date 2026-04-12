# =============================================================================
# nexus — Claude Code Status Bar (Windows / PowerShell)
# https://github.com/rachitgoel89/nexus
#
# Shows: Time | Model | Context Usage | Cost | Git Branch | Stash Count
# Color Palette: Tokyo Night (256-color ANSI)
# =============================================================================

$input_json = $input | Out-String
$data = $input_json | ConvertFrom-Json

# -- ANSI helpers (256-color) -------------------------------------------------
function ansi($n)  { "`e[38;5;${n}m" }
function reset()   { "`e[0m" }
function bold()    { "`e[1m" }
function dim()     { "`e[2m" }

$TN_COMMENT  = ansi 60
$TN_SLATE    = ansi 59
$TN_LAVENDER = ansi 141
$TN_BLUE     = ansi 111
$TN_GOLD     = ansi 179
$TN_ROSE     = ansi 204
$TN_GREEN    = ansi 149
$TN_TEAL     = ansi 115
$TN_FG       = ansi 146
$RESET       = reset
$BOLD        = bold
$DIM         = dim

$SEP = "${TN_SLATE}${DIM} | ${RESET}"

# -- Adaptive token formatter --------------------------------------------------
function Format-Tokens($n) {
    if ($n -lt 1000) { return "$n" }
    if ($n -lt 100000) { return "$([math]::Round($n / 1000, 1))k" }
    return "$([math]::Round($n / 1000))k"
}

# -- Exact token formatter with comma separators (for hook-sourced data) ------
function Format-Exact($n) {
    return $n.ToString("N0")
}

# -- Model name ---------------------------------------------------------------
$raw_model = $data.model.model_id
if (-not $raw_model) { $raw_model = $data.model.display_name }
if (-not $raw_model) { $raw_model = "Unknown" }

$model = $raw_model `
    -replace '^[^/]*/', '' `
    -replace '^[Cc]laude[ -]', '' `
    -replace ' \(.*$', '' `
    -replace '-\d{8}$', '' `
    -replace '-(\d)', ' $1' `
    -replace '(\d) (\d)', '$1.$2'
$model = $model.Substring(0,1).ToUpper() + $model.Substring(1)

# -- Git branch (5-second cache) ----------------------------------------------
$cwd = $data.workspace.current_dir
if (-not $cwd) { $cwd = (Get-Location).Path }

$git_branch = "no-git"
$cache_file = "$env:TEMP\nexus-git-cache.txt"
$cache_max_age = 5

$cache_stale = $true
if (Test-Path $cache_file) {
    $age = (Get-Date) - (Get-Item $cache_file).LastWriteTime
    if ($age.TotalSeconds -le $cache_max_age) { $cache_stale = $false }
}

Push-Location $cwd -ErrorAction SilentlyContinue
if ($cache_stale) {
    $branch = git --no-optional-locks rev-parse --abbrev-ref HEAD 2>$null
    if ($branch) {
        $git_branch = $branch.Trim()
        Set-Content $cache_file $git_branch
    }
} else {
    $git_branch = (Get-Content $cache_file -ErrorAction SilentlyContinue) ?? "no-git"
}
Pop-Location -ErrorAction SilentlyContinue

$branch_display = "${TN_TEAL}⎇ ${TN_GREEN}${BOLD}${git_branch}${RESET}"

# -- Session cost -------------------------------------------------------------
$cost_usd = $data.cost.total_cost_usd
$cost_display = ""
if ($cost_usd -and $cost_usd -gt 0) {
    $cost_int = [math]::Round($cost_usd)
    $cost_color = if ($cost_int -ge 250) { $TN_ROSE } elseif ($cost_int -ge 100) { $TN_GOLD } else { $TN_GREEN }
    $cost_display = "${cost_color}💰 `$$([math]::Round($cost_usd,2).ToString('F2'))${RESET}"
}

# -- Stash count --------------------------------------------------------------
$stash_display = ""
if ($git_branch -ne "no-git") {
    Push-Location $cwd -ErrorAction SilentlyContinue
    $stash_count = (git --no-optional-locks stash list 2>$null | Measure-Object -Line).Lines
    Pop-Location -ErrorAction SilentlyContinue
    if ($stash_count -gt 0) {
        $stash_display = "${TN_GOLD}⎇ ${stash_count} stashed${RESET}"
    }
}

# -- Context window with visual bar -------------------------------------------
$used_pct        = $data.context_window.used_percentage
$ctx_window_size = if ($data.context_window.context_window_size) { $data.context_window.context_window_size } else { 200000 }

$ctx_display = "${TN_COMMENT}n/a${RESET}"

if ($null -ne $used_pct) {
    # Look up session_id via per-cwd pointer
    $TOKEN_CACHE = $null
    $cwd_ps = $data.workspace.current_dir
    if ($cwd_ps) {
        $cwd_bytes = [System.Text.Encoding]::UTF8.GetBytes($cwd_ps)
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $hash_bytes = $md5.ComputeHash($cwd_bytes)
        $cwd_hash_ps = ([BitConverter]::ToString($hash_bytes) -replace '-','').Substring(0,8).ToLower()
        $sid_file = "$env:TEMP\nexus-sid-$cwd_hash_ps"
        if (Test-Path $sid_file) {
            $sid_ps = (Get-Content $sid_file -Raw -ErrorAction SilentlyContinue).Trim()
            if ($sid_ps) {
                $TOKEN_CACHE = "$env:TEMP\nexus-token-$sid_ps.json"
            }
        }
    }
    $hook_tokens = $null
    if ($TOKEN_CACHE -and (Test-Path $TOKEN_CACHE)) {
        $cache_age = (Get-Date) - (Get-Item $TOKEN_CACHE).LastWriteTime
        if ($cache_age.TotalSeconds -lt 60) {
            try {
                $tc = Get-Content $TOKEN_CACHE -Raw | ConvertFrom-Json
                $hook_tokens = $tc.total_input
            } catch {}
        }
    }

    $using_hook = $false
    if ($hook_tokens -and $hook_tokens -gt 0) {
        $display_tokens = $hook_tokens
        $used_int = [math]::Round($hook_tokens * 100 / $ctx_window_size)
        $using_hook = $true
    } else {
        $used_int = [math]::Round($used_pct)
        $display_tokens = [math]::Round($used_pct * $ctx_window_size / 100)
    }

    $used_int = [math]::Max(0, [math]::Min(100, $used_int))
    $ctx_color = if ($used_int -ge 75) { $TN_ROSE } elseif ($used_int -ge 50) { $TN_GOLD } else { $TN_BLUE }

    $bar_filled = [math]::Floor($used_int / 10)
    $bar_empty  = 10 - $bar_filled
    $bar = ("▓" * $bar_filled)
    if ($bar_filled -lt 10) {
        $bar += "▶"
        $bar_empty -= 1
    }
    $bar += ("░" * [math]::Max(0, $bar_empty))

    if ($display_tokens -gt 0) {
        $used_fmt  = if ($using_hook) { Format-Exact $display_tokens } else { Format-Tokens $display_tokens }
        $limit_fmt = Format-Tokens $ctx_window_size
        $ctx_display = "${ctx_color}[${bar}] ${TN_FG}${used_fmt}${TN_SLATE}/${TN_FG}${limit_fmt} ${ctx_color}(${used_int}%)${RESET}"
    } else {
        $ctx_display = "${ctx_color}[${bar}] (${used_int}%)${RESET}"
    }
}

# -- Wall clock time ----------------------------------------------------------
$current_time = (Get-Date).ToString("HH:mm")

# -- Session duration -----------------------------------------------------------
$session_duration = ""
$session_start_file = $null
if ($cwd_hash_ps -and (Test-Path "$env:TEMP\nexus-sid-$cwd_hash_ps")) {
    $sid_ps2 = (Get-Content "$env:TEMP\nexus-sid-$cwd_hash_ps" -Raw -ErrorAction SilentlyContinue).Trim()
    if ($sid_ps2) { $session_start_file = "$env:TEMP\nexus-session-start-$sid_ps2" }
}
if ($session_start_file -and (Test-Path $session_start_file)) {
    try {
        $session_start = [int64](Get-Content $session_start_file -Raw).Trim()
        $now = [int64](Get-Date -UFormat %s)
        $elapsed = $now - $session_start
        if ($elapsed -ge 3600) {
            $hours = [math]::Floor($elapsed / 3600)
            $mins  = [math]::Floor(($elapsed % 3600) / 60)
            $session_duration = "${TN_COMMENT}⏱ ${hours}h$($mins.ToString('D2'))m${RESET}"
        } elseif ($elapsed -ge 60) {
            $mins = [math]::Floor($elapsed / 60)
            $session_duration = "${TN_COMMENT}⏱ ${mins}m${RESET}"
        } else {
            $session_duration = "${TN_COMMENT}⏱ <1m${RESET}"
        }
    } catch {}
}

# -- Assemble output ----------------------------------------------------------
$segments = @("${TN_COMMENT}${current_time}${RESET}")
if ($session_duration) { $segments += $session_duration }
$segments += @("${TN_LAVENDER}${BOLD}${model}${RESET}", $ctx_display)
if ($cost_display)  { $segments += $cost_display }
$segments += $branch_display
if ($stash_display) { $segments += $stash_display }

Write-Output ($segments -join $SEP)
