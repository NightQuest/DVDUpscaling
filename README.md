# DVDUpscaling
PowerShell script for automating the Upscale of an entire folder using Topaz AI, ffmpeg, mkvtoolnix, mediaInfo, VapourSynth, and Hybrid

# Requirements
Currently, this is Windows-only, though I may make it work for macOS later.

You will need an active license to [Topaz Video AI](https://www.topazlabs.com/topaz-video-ai).

You will also need these Windows binaries:
- [ffmpeg](https://www.gyan.dev/ffmpeg/builds/#release-builds)
- [MediaInfo CLI](https://mediaarea.net/en/MediaInfo/Download/Windows)
- [DGIndex](https://www.rationalqm.us/dgmpgdec/dgmpgdec.html)
- [D2VSource](https://github.com/dwbuiten/d2vsource/)
- [x265](http://msystem.waw.pl/x265/)
- [MKVToolNix](https://mkvtoolnix.download/downloads.html#windows)
- [Hybrid](https://www.selur.de/downloads)

# Folder Layout
This script assumes a folder structure like this:
| Relative Path |
| ------------- |
| bin/ffmpeg/bin/ffmpeg.exe |
| bin/ffmpeg/bin/ffprobe.exe |
| bin/MediaInfo/MediaInfo.exe |
| bin/dgmpgdec/DGIndex.exe |
| bin/x265/x265-10b.exe |
| bin/mkvtoolnix/mkvmerge.exe |
| bin/vsfilters/d2vsource/win64/d2vsource.dll |
