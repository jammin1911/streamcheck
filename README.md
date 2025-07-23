StreamCheck 

PowerShell script to analyze video streams from an m3u_plus playlist by measuring bitrate, resolution, and FPS using ffmpeg and ffprobe. 
Requirements 

    Windows PowerShell 5.1
    ffmpeg.exe and ffprobe.exe placed in the .\bin folder relative to the script
    Execution policy that allows running unsigned scripts (e.g., RemoteSigned or Bypass)
     

Usage 
powershell
 
 
 
1
.\streamcheck.ps1 -m3u <path_to_playlist.m3u> [-DurationSeconds <seconds>]
 
 

    -m3u (required): Path to the m3u_plus playlist file
    -DurationSeconds (optional): Number of seconds to test each stream (default 6 seconds)
     

Example: 
powershell
 
 
 
1
.\streamcheck.ps1 -m3u "C:\Playlists\channels.m3u" -DurationSeconds 6
 
 
Output 

For each channel, outputs: 

    Channel Name
    Channel Group (from group-title attribute)
    Bitrate in kbps with captured file size
    Video Resolution (width×height)
    Video FPS
     

Errors for unavailable streams are clearly indicated. 

Feel free to contribute or raise issues. 
