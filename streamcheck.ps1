<#
StreamCheck v0.1 by Jay
DISCLAIMER: This was created 100% with AI and I have no coding experience
Usage:
.\YourScript.ps1 -m3u <path> [-DurationSeconds <seconds>]
Example:
.\YourScript.ps1 -m3u "C:\channels.m3u" -DurationSeconds 12
Requires ffmpeg.exe and ffprobe.exe in .\bin folder.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$m3u,
    [int]$DurationSeconds = 12
)

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$binFolder = Join-Path $scriptFolder 'bin'
$Defaults = @{
    DurationSeconds = $DurationSeconds
    TempFolder = "$env:TEMP\StreamBitrateTest"
    BinFolder   = $binFolder
    ffmpegPath  = Join-Path $binFolder 'ffmpeg.exe'
    ffprobePath = Join-Path $binFolder 'ffprobe.exe'
}

function Remove-NonStandardChars {
    param ([string]$Input)
    # Keep only ASCII printable characters (space to ~)
    $filtered = ($Input.ToCharArray() | Where-Object {
        ($_ -match '[\x20-\x7E]')
    }) -join ''
    return $filtered.Trim()
}

function Parse-M3UPlaylist {
    param ([string]$PlaylistPath)
    if (-not (Test-Path $PlaylistPath)) {
        Write-Error "Playlist file not found: $PlaylistPath"
        return @()
    }
    $lines = Get-Content -Path $PlaylistPath
    $entries = @()
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i].StartsWith('#EXTINF')) {
            $extinfLine = $lines[$i]
            $urlLine = if ($i + 1 -lt $lines.Length) { $lines[$i + 1] } else { '' }
            # Extract group-title attribute
            $groupTitle = ''
            if ($extinfLine -match 'group-title="([^"]*)"') {
                $groupTitle = $matches[1]
            }
            # Extract channel name (text after last comma)
            $lastCommaIndex = $extinfLine.LastIndexOf(',')
            $channelName = ''
            if ($lastCommaIndex -ge 0 -and $lastCommaIndex + 1 -lt $extinfLine.Length) {
                $channelName = $extinfLine.Substring($lastCommaIndex + 1).Trim()
            }
            # Clean non-standard characters (optional)
            $cleanGroupTitle = ($groupTitle.ToCharArray() | Where-Object { ($_ -ge ' ') -and ($_ -le '~') }) -join ''
            $cleanChannelName = ($channelName.ToCharArray() | Where-Object { ($_ -ge ' ') -and ($_ -le '~') }) -join ''
            if ($urlLine) {
                $entries += [PSCustomObject]@{
                    GroupTitle = $cleanGroupTitle
                    ChannelName = $cleanChannelName
                    Url = $urlLine.Trim()
                }
            }
            $i++ # Skip URL line
        }
    }
    return $entries
}

function Get-StreamBitrate {
    param (
        [string]$Url,
        [string]$GroupTitle,
        [string]$ChannelName,
        [int]$DurationSeconds = $Defaults.DurationSeconds
    )
    $ffmpegPath = $Defaults.ffmpegPath
    $ffprobePath = $Defaults.ffprobePath

    if (-not (Test-Path $ffmpegPath)) {
        return @{
            GroupTitle = $GroupTitle
            ChannelName = $ChannelName
            Bitrate = ''
            Resolution = ''
            FPS = ''
            Error = 'ffmpeg.exe Not Found'
            Success = $false
        }
    }
    if (-not (Test-Path $ffprobePath)) {
        return @{
            GroupTitle = $GroupTitle
            ChannelName = $ChannelName
            Bitrate = ''
            Resolution = ''
            FPS = ''
            Error = 'ffprobe.exe Not Found'
            Success = $false
        }
    }
    if (-not (Test-Path $Defaults.TempFolder)) { New-Item -ItemType Directory -Path $Defaults.TempFolder | Out-Null }
    $tempFile = Join-Path $Defaults.TempFolder "$([guid]::NewGuid().ToString()).ts"
    $errorLog = Join-Path $Defaults.TempFolder "$([guid]::NewGuid().ToString())_ffmpeg_error.log"
    $args = @(
        '-y'
        '-loglevel', 'error'
        '-i', $Url
        '-t', $DurationSeconds
        '-c', 'copy'
        '-f', 'mpegts'
        $tempFile
    )

    # --- Begin Progress Display with growing dots per second ---
    Write-Host "" # for clean separation
    $proc = Start-Process -FilePath $ffmpegPath -ArgumentList $args -WindowStyle Hidden -RedirectStandardError $errorLog -PassThru
    $elapsed = 0
    while (-not $proc.HasExited) {
        $dotString = '.' * ($elapsed + 1)
        Write-Host -NoNewline "`rDownloading Stream$dotString"
        Start-Sleep -Seconds 1
        $elapsed++
    }
    # Clear the progress line from the console, assuming max line length < 60
    Write-Host ("`r" + (" " * 60) + "`r") -NoNewline
    # --- End Progress Display ---

    if (-not (Test-Path $tempFile)) {
        Remove-Item -Path $errorLog -ErrorAction SilentlyContinue
        return @{
            GroupTitle = $GroupTitle
            ChannelName = $ChannelName
            Bitrate = ''
            Resolution = ''
            FPS = ''
            Error = 'Stream Unavailable'
            Success = $false
        }
    }
    $fileSizeBytes = (Get-Item $tempFile).Length
    if ($fileSizeBytes -lt 1000) {
        Remove-Item $tempFile -Force
        Remove-Item -Path $errorLog -ErrorAction SilentlyContinue
        return @{
            GroupTitle = $GroupTitle
            ChannelName = $ChannelName
            Bitrate = ''
            Resolution = ''
            FPS = ''
            Error = 'Stream Unavailable or Too Small'
            Success = $false
        }
    }

    # ffprobe logic
    $videoInfo = @{
        Resolution = ''
        FPS        = ''
    }
    $ffArgs = @("-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,avg_frame_rate", "-of", "default=noprint_wrappers=1", $tempFile)
    $output = & $ffprobePath $ffArgs 2>&1
    if ($LASTEXITCODE -eq 0 -and $output) {
        $width = ''
        $height = ''
        $fps = ''
        foreach ($line in $output) {
            if ($line -match '^width=(\d+)$')   { $width = $matches[1] }
            elseif ($line -match '^height=(\d+)$') { $height = $matches[1] }
            elseif ($line -match '^avg_frame_rate=([\d/\.]+)') {
                $fpsStr = $matches[1]
                if ($fpsStr -match '^(\d+)/(\d+)$') {
                    $fps = [math]::Round([double]$matches[1] / [double]$matches[2], 3)
                } elseif ($fpsStr -match '^\d+(\.\d+)?$') {
                    $fps = [math]::Round([double]$fpsStr, 3)
                }
            }
        }
        if ($width -and $height) { $videoInfo.Resolution = "${width}x${height}" }
        if ($fps) { $videoInfo.FPS = $fps }
    }
    Remove-Item $tempFile -Force
    Remove-Item -Path $errorLog -ErrorAction SilentlyContinue

    $bitrateKbps = [math]::Round(($fileSizeBytes * 8) / ($DurationSeconds * 1000))
    $fileSizeMB = [math]::Round(($fileSizeBytes / 1MB), 1)
    $bitrateStr = "$bitrateKbps kbps ($fileSizeMB MB in ${DurationSeconds}s)"

    return @{
        GroupTitle = $GroupTitle
        ChannelName = $ChannelName
        Bitrate = $bitrateStr
        Resolution = $videoInfo.Resolution
        FPS = $videoInfo.FPS
        Error = ''
        Success = $true
    }
}

$channels = Parse-M3UPlaylist -PlaylistPath $m3u
if ($channels.Count -eq 0) {
    Write-Error "No entries found in playlist."
    exit 1
}

# Store results for summary
$results = @()

foreach ($channel in $channels) {
    $result = Get-StreamBitrate -Url $channel.Url -GroupTitle $channel.GroupTitle -ChannelName $channel.ChannelName -DurationSeconds $Defaults.DurationSeconds
    $results += $result
    if ($result.ChannelName -ne '') {
        Write-Output "Channel Name: $($result.ChannelName)"
    }
    else {
        Write-Output "Channel Name: (none)"
    }
    if ($result.GroupTitle -ne '') {
        Write-Output "Channel Group: $($result.GroupTitle)"
    }
    else {
        Write-Output "Channel Group: (none)"
    }
    if ($result.Success) {
        Write-Output "Channel Bitrate: $($result.Bitrate)"
        if ($result.Resolution) { Write-Output "Resolution: $($result.Resolution)" }
        if ($result.FPS) { Write-Output "FPS: $($result.FPS)" }
    }
    else {
        Write-Output "Error: $($result.Error)"
    }
    Write-Output ""
}

# ---- SUMMARY SECTION ----
$totalTested  = $results.Count
$working      = ($results | Where-Object { $_.Success -eq $true }).Count
$errorCount   = $totalTested - $working

Write-Host "###########################################"
Write-Host "SUMMARY:"
Write-Host "Total Number of Streams Tested: $totalTested"
Write-Host "Total Number of Working Streams: $working"
Write-Host "Total Number of Streams with Errors: $errorCount"

# Prepare/Show grouped stats for resolution + FPS (+ average bitrate)
$goodResults = $results | Where-Object { $_.Success -and $_.Resolution -and $_.FPS }

$grouped = $goodResults | ForEach-Object {
    # Extract the raw bitrate number (may be: "2345 kbps (X MB...)", want just the 2345)
    $bitrateKbps = $null
    if ($_.Bitrate -match '^(\d+)\s*kbps') {
        $bitrateKbps = [int]$matches[1]
    }
    # FPS string
    $fpsStr = $_.FPS
    # Group label
    $label = "$($_.Resolution) @ $fpsStr" + "FPS"
    [PSCustomObject]@{
        ResFpsLabel = $label
        BitrateKbps = $bitrateKbps
    }
} | Group-Object ResFpsLabel

# Now sort by count descending
$grouped = $grouped | Sort-Object Count -Descending

if ($grouped.Count -gt 0) {
    Write-Host ""
    Write-Host "Stream Count by Resolution and FPS:"
    foreach ($g in $grouped) {
        # Get non-null, positive bitrates only
        $bitrates = $g.Group | Where-Object { $_.BitrateKbps -gt 0 } | Select-Object -ExpandProperty BitrateKbps
        $avg = $null
        if ($bitrates.Count -gt 0) {
            $avg = [math]::Round(($bitrates | Measure-Object -Average).Average)
            Write-Host ("{0} = {1} (Average Bitrate: {2} kbps)" -f $g.Name, $g.Count, $avg)
        }
        else {
            Write-Host ("{0} = {1} (Average Bitrate: N/A)" -f $g.Name, $g.Count)
        }
    }
} else {
    Write-Host ""
    Write-Host "No valid Resolution/FPS data for any working stream."
}
Write-Host "###########################################"
