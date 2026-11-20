# Builds a clean release zip of the addon, ready to share or upload.
#
# Only the files the game needs go in: the .toc, every file the .toc loads,
# and Media\. Dev folders (tools, research, docs) are never included,
# because the zip is built from that whitelist, not by deleting things.
#
# Output: <ClaudeCodez>\FCE-releases\FishingCookingEncyclopedia-<version>.zip
# The zip holds one top-level FishingCookingEncyclopedia\ folder, so it can be
# extracted straight into Interface\AddOns.
#
# Usage (from anywhere):  powershell -File tools\package.ps1
#   -SkipBuild   don't regenerate Data\*.lua from the research files first

param([switch]$SkipBuild)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$addonName = Split-Path -Leaf $root
$tocPath = Join-Path $root "$addonName.toc"
if (-not (Test-Path $tocPath)) { throw "TOC not found: $tocPath" }

# 1. Regenerate the data files so the zip never ships stale data.
if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot "build-data.ps1")
}

# 2. Read the version and the load list from the TOC.
$tocLines = Get-Content $tocPath -Encoding UTF8
$version = "dev"
$loadList = @()
foreach ($line in $tocLines) {
    $t = $line.Trim()
    if ($t -match '^##\s*Version:\s*(.+)$') { $version = $Matches[1].Trim() }
    elseif ($t -eq "" -or $t.StartsWith("#")) { continue }
    else { $loadList += $t }
}

# 3. Whitelist: the TOC, everything it loads, and all of Media\.
$files = @("$addonName.toc") + $loadList
$mediaDir = Join-Path $root "Media"
if (Test-Path $mediaDir) {
    Get-ChildItem $mediaDir -Recurse -File | ForEach-Object {
        $files += $_.FullName.Substring($root.Length + 1)
    }
}

$missing = $files | Where-Object { -not (Test-Path (Join-Path $root $_)) }
if ($missing) { throw "Files listed in the TOC are missing:`n  " + ($missing -join "`n  ") }

# Warn about shipped-folder .lua files the TOC doesn't load (likely a forgotten TOC entry).
$shippedDirs = @("", "Data")
foreach ($d in $shippedDirs) {
    Get-ChildItem (Join-Path $root $d) -Filter *.lua -File | ForEach-Object {
        $rel = $_.FullName.Substring($root.Length + 1)
        if ($loadList -notcontains $rel) { Write-Warning "$rel is not in the TOC and will not be packaged." }
    }
}

# 4. Write the zip. Entries use forward slashes so every unzip tool
#    (and the CurseForge app) recreates the folders correctly.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$outDir = Join-Path (Split-Path -Parent $root) "FCE-releases"
New-Item -ItemType Directory -Force $outDir | Out-Null
$zipPath = Join-Path $outDir "$addonName-$version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($rel in $files) {
        $entryName = "$addonName/" + ($rel -replace '\\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, (Join-Path $root $rel), $entryName, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $zip.Dispose()
}

$size = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
Write-Output ""
Write-Output "Packaged $($files.Count) files ($size KB):"
$files | ForEach-Object { Write-Output "  $addonName\$_" }
Write-Output ""
Write-Output "Wrote $zipPath"
