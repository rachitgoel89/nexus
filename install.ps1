# =============================================================================
# nexus — one-shot installer for Windows (PowerShell 7+)
# https://github.com/rachitgoel89/nexus
# =============================================================================

#Requires -Version 7.0

$ErrorActionPreference = 'Stop'

$RepoRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginCache = "$env:APPDATA\Claude\plugins\cache\raygoel\nexus\1.0.0"
$Settings    = "$env:APPDATA\Claude\settings.json"

Write-Host ""
Write-Host "  nexus -- Claude Code Status Bar"
Write-Host "  ================================"
Write-Host ""

# -- Dependency check ---------------------------------------------------------
$missing = @()
foreach ($dep in @('jq', 'python3', 'git')) {
    if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
        $missing += $dep
    }
}

if ($missing.Count -gt 0) {
    Write-Host "  ERROR: Missing dependencies: $($missing -join ', ')"
    Write-Host ""
    Write-Host "  Install with winget:"
    foreach ($dep in $missing) {
        switch ($dep) {
            'jq'      { Write-Host "    winget install jqlang.jq" }
            'python3' { Write-Host "    winget install Python.Python.3" }
            'git'     { Write-Host "    winget install Git.Git" }
        }
    }
    Write-Host ""
    exit 1
}

Write-Host "  [OK] Dependencies: jq, python3, git"

# -- Validate Claude settings -------------------------------------------------
if (-not (Test-Path $Settings)) {
    Write-Host ""
    Write-Host "  ERROR: Claude settings not found at: $Settings"
    Write-Host "         Run Claude Code at least once before installing nexus."
    exit 1
}

# -- Copy plugin to Claude cache ----------------------------------------------
New-Item -ItemType Directory -Force -Path $PluginCache | Out-Null
Get-ChildItem -Path $RepoRoot -Exclude '.git','install.sh','install.ps1' |
    Copy-Item -Destination $PluginCache -Recurse -Force

Write-Host "  [OK] Plugin copied to: $PluginCache"

# -- Update settings.json via python3 (avoids PowerShell JSON depth issues) ---
$scriptPath = "$PluginCache\scripts\statusline.ps1"

python3 - $Settings $scriptPath @'
import json, sys

settings_path, script_path = sys.argv[1], sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

settings['statusLine'] = {
    'type': 'command',
    'command': f'powershell -File "{script_path}"'
}

plugins = settings.get('enabledPlugins', {})
plugins.pop('docket@raygoel', None)
plugins['nexus@raygoel'] = True
settings['enabledPlugins'] = plugins

marketplaces = settings.get('extraKnownMarketplaces', {})
marketplaces['raygoel'] = {
    'source': {
        'source': 'github',
        'repo': 'rachitgoel89/nexus',
        'ref': 'main'
    }
}
settings['extraKnownMarketplaces'] = marketplaces

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('  [OK] statusLine configured')
print('  [OK] Plugin enabled: nexus@raygoel')
print('  [OK] Marketplace registered: rachitgoel89/nexus')
'@

Write-Host ""
Write-Host "  DONE! Restart Claude Code to activate nexus."
Write-Host ""
Write-Host "  Then run:  /nexus:setup"
Write-Host "  To update: claude plugin update nexus"
Write-Host ""
