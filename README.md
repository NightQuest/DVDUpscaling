# DVDUpscaling
PowerShell script for automating the Upscale of an entire folder using Topaz AI, ffmpeg, mkvtoolnix, mediaInfo, VapourSynth, and Hybrid

# Requirements
Currently, this is Windows-only, though I may make it work for macOS later.

You will need an active license to [Topaz Video AI](https://www.topazlabs.com/topaz-video-ai).

You will also need Windows binaries for [ffmpeg](https://www.gyan.dev/ffmpeg/builds/#release-builds), [MediaInfo CLI](https://mediaarea.net/en/MediaInfo/Download/Windows), [x265](http://msystem.waw.pl/x265/), and [MKVToolNix](https://mkvtoolnix.download/downloads.html#windows).


# Folder Layout
This script assumes a folder structure like this:
| Relative Path |
| ------------- |
| bin/ffmpeg/bin/ffmpeg.exe |
| bin/ffmpeg/bin/ffprobe.exe |
| bin/MediaInfo/MediaInfo.exe |
| bin/x265/x265-10b.exe |
| bin/mkvtoolnix/mkvmerge.exe |
