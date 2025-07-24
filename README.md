# StreamCheck

DISCLAIMER: THIS PROJECT WAS CREATED 100% USING AI. I DO NOT KNOW HOW TO CODE :)

PowerShell script to analyze video streams from an m3u_plus playlist by measuring bitrate, resolution, and FPS using `ffmpeg` and `ffprobe`.

## Requirements

- Windows PowerShell 5.1  
- `ffmpeg.exe` and `ffprobe.exe` placed in the `.\bin` folder relative to the script  
- Execution policy that allows running unsigned scripts (e.g., `RemoteSigned` or `Bypass`)

## Usage

- Give the unsigned script permission to run
```powershell
Unblock-File -Path ".\streamcheck.ps1"
```

```powershell
.\streamcheck.ps1 -m3u <path_to_playlist.m3u> [-DurationSeconds <seconds>]
```
- m3u (required): Path to the m3u_plus playlist file  
- DurationSeconds (optional): Number of seconds to test each stream (default 6 seconds)

## Output 

For each channel, the script displays: 

- Channel Name  
- Channel Group (from group-title attribute)  
- Bitrate in kbps with captured file size  
- Video Resolution (width×height)  
- Video FPS
     
Errors for unavailable streams are clearly indicated. 

Contributions and issue reports are welcome!

## Sample Output

```
Channel Name: World News Channel
Channel Group: News
Channel Bitrate: 2345 kbps (17.18 MB in 12s)
Resolution: 1280x720
FPS: 29.97

Channel Name: SPORT CHANNEL HD
Channel Group: Sports
Channel Bitrate: 4523 kbps (32.96 MB in 12s)
Resolution: 1920x1080
FPS: 59.94

Downloading Stream.
Channel Name: Ghost Channel
Channel Group: Classic
Error: Stream Unavailable

###########################################
SUMMARY:
Total Number of Streams Tested: 75
Total Number of Working Streams: 68
Total Number of Streams with Errors: 7

Stream Count by Resolution and FPS:
1280x720 @ 60FPS = 21 (Average Bitrate: 3750 kbps)
1920x1080 @ 60FPS = 16 (Average Bitrate: 4850 kbps)
1280x720 @ 30FPS = 12 (Average Bitrate: 2140 kbps)
1920x1080 @ 30FPS = 8 (Average Bitrate: 3080 kbps)
640x360 @ 30FPS = 5 (Average Bitrate: 850 kbps)
1920x1080 @ 59.94FPS = 4 (Average Bitrate: 5020 kbps)
960x540 @ 30FPS = 2 (Average Bitrate: 1150 kbps)

###########################################
```
