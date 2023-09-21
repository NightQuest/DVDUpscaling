# Stardust Upscaler
# Author: SubtleNinja
# Date: 2023-09-09
# 
# Changelog:
# v3 - 2023-09-21
# - Sort files by episode number
# 
# v2 - 2023-09-19
# - Dynamically get width / height / PAR
# - Use ffprobe for frame count & fps
# - Bug fixes
#
# v1 - 2023-09-09
# - Initial Version, basic functionality
#

# Topaz Video AI model directories - required
$env:TVAI_MODEL_DATA_DIR = "C:/ProgramData/Topaz Labs LLC/Topaz Video AI/models"
$env:TVAI_MODEL_DIR = "C:/ProgramData/Topaz Labs LLC/Topaz Video AI/models"

$config = [PSCustomObject]@{
    encoding_tool = "Stardust Upscaler v3"

    # Input, Output, and temporary folders
    input_folder = "E:/Dragon Ball/Season 1"
    output_folder = "E:/Dragon Ball/Season 1 - AI Upscale"
    temp_folder = "E:/temp"

    # Utility folders
    topaz_video_ai_location = "C:/Program Files/Topaz Labs LLC/Topaz Video AI"
    hybrid_location = "C:/Program Files/Hybrid"

    # Process settings
    clean_temp = $true
    skip_existing = $true

    # De-interlace settings
    auto_crop = $true
    maintain_aspect_ratio = $true # use only if autocrop is enabled
    vs_resample_kernel = 'lanczos'

    # Target dimensions
    upscale_Width = 1440
    upscale_Height = 1080


    topaz = [PSCustomObject]@{
        enhancement_passes = 2

        enhancement_pass_one = [PSCustomObject]@{
            # AI Model
            model       = "prob-3"

            # Has Another Enhancement?
            scale       = 1

            # Anti-Alias/Deblur
            preblur     = 0 

            # Reduce Noise
            noise       = 0.25

            # Improve Detail
            details     = 0

            # De-halo
            halo        = 0.25

            # Sharpen
            blur        = 0.25 

            # Recover Original Detail
            blend       = 0.2 

            # Revert Compression
            compression = 0.6

            # estimate    = 20

            # Grain Amount
            grain       = 0.04

            # Grain Size
            gsize       = 2

            # AI Processing Device
            # -2 Auto
            # -1 CPU
            # 0 First GPU
            # 1 Second GPU
            # 2 All GPUs
            device      = -2

            # Max Memory Usage (50% -> 0.5)
            vram        = 1

            # Max Processes
            # 1 = 1
            # 0 = No Limit(?)
            instances   = 1
        }

        enhancement_pass_two = [PSCustomObject]@{
            model       = "prob-3"
            scale       = 0
            w           = 1440
            h           = 1080
            preblur     = 0.5
            noise       = 0.5
            details     = 0.35
            halo        = 0
            blur        = 0
            compression = 0.5
            # estimate = 20
            blend       = 0.2
            grain       = 0.04
            gsize       = 2
            device      = -2
            vram        = 1
            instances   = 1
        }
    }
}

# Current working directory
$curLoc = (Get-Location).Path
$toolsPath = "$curLoc/bin"

# Tool paths
$vspipe_path = "$($config.hybrid_location)/64bit/Vapoursynth/VSPipe.exe"
$ffmpeg_ai_path = "$($config.topaz_video_ai_location)/ffmpeg.exe"
$ffmpeg_path = "$toolsPath/ffmpeg/bin/ffmpeg.exe"
$ffprobe_path = "$toolsPath/ffmpeg/bin/ffprobe.exe"
$x265_path = "$toolsPath/x265/x265-10b.exe"
$mediainfo_path = "$toolsPath/MediaInfo/MediaInfo.exe"
$mkvmerge_path = "$toolsPath/mkvtoolnix/mkvmerge.exe"
$mkvpropredit_path = "$toolsPath/mkvtoolnix/mkvpropedit.exe"

# Aliases for direct program execution
Set-Alias -Name mediainfo -Value $mediainfo_path
Set-Alias -Name ffmpeg -Value $ffmpeg_path
Set-Alias -Name ffprobe -Value $ffprobe_path
Set-Alias -Name mkvmerge -Value $mkvmerge_path
Set-Alias -Name mkvpropedit -Value $mkvpropredit_path

# Include other files
. "Modules/MediaFile.ps1"

# Get input files
$files = Get-ChildItem -LiteralPath $config.input_folder

# If configured, remove any that already exist
if ($config.skip_existing)
{
    $files = $files | Where-Object { -not (Test-Path -LiteralPath "$($config.output_folder)/$($_.Name)" -PathType 'Leaf') }

    # Sort files in order (Assumes episodes start with a number)
    if ($files[0].BaseName -match "\d+ .*")
    {
        $files = $files | Sort-Object { [int](($_.BaseName -Split ' ')[0]) }
    }
}

# Iterate our files
ForEach ($file in $files)
{
    # Setup our paths
    $deint_path = "$($config.temp_folder)/$($file.BaseName)_deinterlaced.mov"
    $upscale_path = "$($config.temp_folder)/$($file.BaseName)_upscaled.mov"
    $encode_path = "$($config.temp_folder)/$($file.BaseName)_encoded.h265"
    $final_path = "$($config.output_folder)/$($file.BaseName).mkv"

    Write-Output "[INFO]: Analyzing '$($file.Name)'..."

    # Do not rely on MediaInfo for FPS - it is incorrect for VFR
    $info = ffprobe -v 0 -of csv=p=0 -select_streams v:0 -count_frames -show_entries stream=r_frame_rate,nb_read_frames "$($file.FullName)" | Out-String -NoNewLine

    if ($info -notmatch "(?<frameRate_Num>\d+)/(?<frameRate_Den>\d+),(?<frameCount>\d+)")
    {
        Write-Error "[ERROR]: Failed to analyze file!"
        continue
    }

    $frameRate_Num = [int]$Matches.frameRate_Num
    $frameRate_Den = [int]$Matches.frameRate_Den
    $frameRate = [Math]::Round($frameRate_Num / $frameRate_Den, 3)
    $frameCount = [int]$Matches.frameCount

    # Get our Video properties from MediaInfo
    $mediaFile = [MediaFile]::new($file)
    $PAR = [float]$mediaFile.getAttribute("Video", "AspectRatio")
    $Width = [int]$mediaFile.getAttribute("Video", "Width")
    $Height = [int]$mediaFile.getAttribute("Video", "Height")

    Write-Output "[INFO]: FPS: $frameRate -> $($frameRate * 2)"
    Write-Output "[INFO]: Frames: $frameCount -> $($frameCount * 2)"

    # Have we already De-Interlaced?
    if (-not (Test-Path -LiteralPath $deint_path -PathType 'Leaf'))
    {
        # Get Auto-Crop
        $cropValues = [PSCustomObject]@{
            top = 0
            bottom = 0
            left = 0
            right = 0
        }

        if ($config.auto_crop)
        {
            Write-Output "[INFO]: Detecting Auto-Crop..."

            $cropInfo = ffmpeg -hide_banner -ss 00:05:00 -i $file.FullName -an -vframes 10 -vf cropdetect=24:16:00 -f null - 2>&1 | Out-String

            if ($cropInfo -notmatch 'x1:(?<x1>\d{1,6}) x2:(?<x2>\d{1,6}) y1:(?<y1>\d{1,6}) y2:(?<y2>\d{1,6}) w:(?<w>\d{1,6}) h:(?<h>\d{1,6}) x:(?<x>\d{1,6}) y:(?<y>\d{1,6})')
            {
                Write-Error "[ERROR]: Could not detect auto-crop values!"
            }
            else
            {
                $tmpBottom = $Height - $Matches.y2
                $tmpRight = $Width - $Matches.x2

                $cropValues.top = $Matches.y1 - ($Matches.y1 % 2)
                $cropValues.bottom = $tmpBottom - ($tmpBottom % 2)
                $cropValues.left = $Matches.x1 - ($Matches.x1 % 2)
                $cropValues.right = $tmpRight - ($tmpRight % 2)

                $out = ""
                if (
                    $cropValues.left -eq 0 -and
                    $cropValues.top -eq 0 -and
                    $cropValues.right -eq 0 -and
                    $cropValues.bottom -eq 0
                    )
                {
                    $out = "[INFO]: No crop needed."
                }
                else
                {
                    $out = "[INFO]: Cropping with:`n"
                    $out += "Left: $($cropValues.left)`n"
                    $out += "Top: $($cropValues.top)`n"
                    $out += "Right: $($cropValues.right)`n"
                    $out += "Bottom: $($cropValues.bottom)"
                }

                Write-Output $out
            }

            if ($config.maintain_aspect_ratio)
            {
                # PAR 1:1 conversion (Square pixel)
                $out = "[INFO]: Resizing post-crop using '$($config.vs_resample_kernel)', "
                $out += "$($Width - ($cropValues.left + $cropValues.right))x$($Height - ($cropValues.top + $cropValues.bottom))"
                $out += " -> $($Width)x$([Math]::floor($Width / $PAR))"
                Write-Output $out
            }
        }

        Write-Output "[INFO]: De-interlacing with VapourSynth..."

        $arguments = [PSCustomObject]@{

            hybrid_path = "`"$($config.hybrid_location)`""

            input_file = "`"$($file.FullName)`""

            AspectRatio = $PAR
            maintainPAR = $($config.maintain_aspect_ratio)

            width = $Width
            height = $Height

            FrameRate = $frameRate
            FrameRate_Num = $frameRate_Num
            FrameRate_Den = $frameRate_Den

            cropTop = $($cropValues.top)
            cropBottom = $($cropValues.bottom)
            cropLeft = $($cropValues.left)
            cropRight = $($cropValues.right)
        }

        $argNames = $arguments.psobject.properties.name

        $argString = ""

        ForEach ($arg in $argNames)
        {
            if ($argString -ne "")
            {
                $argString += " "
            }

            $argString += "--arg $arg=$($arguments.$arg)"
        }

        # Write our De-Interlaced file
        Start-Process -FilePath "cmd" -ArgumentList "/c `"`"$vspipe_path`" $argString --container y4m `"SynthSkript.vpy`" - | `"$ffmpeg_path`" -y -hide_banner -loglevel error -stats -noautorotate -nostdin -threads 8 -f yuv4mpegpipe -i - -an -sn -vf `"zscale=rangein=tv:range=tv`" -strict -1 -fps_mode passthrough -vcodec prores_ks -profile:v 3 -vtag apch -aspect $PAR -metadata encoding_tool=`"$($config.encoding_tool)`" -f mov `"$deint_path`"`"" -NoNewWindow -Wait
    }
    else
    {
        Write-Information "[INFO]: Detected pre-existing De-interlaced file, skipping De-Interlace stage..."
    }

    if (-not (Test-Path -LiteralPath $upscale_path -PathType 'Leaf'))
    {
        # Verify our file was written, or already exists
        if (-not (Test-Path -LiteralPath $deint_path -PathType 'Leaf'))
        {
            Write-Error "[ERROR]: De-interlaced file not found, cannot run upscale!"
            continue
        }

        Write-Output "[INFO]: Upscaling with Topaz AI..."

        $filter_complex = ""
        $filter_complex_pass_one = ""
        $filter_complex_pass_two = ""
        $metadata = ""

        $names = $config.topaz.enhancement_pass_one.psobject.properties.name
        ForEach ($name in $names)
        {
            if ($filter_complex_pass_one -ne "")
            {
                $filter_complex_pass_one += ":"
            }

            $filter_complex_pass_one += "$name=$($config.topaz.enhancement_pass_one.$name)"
        }

        if ($config.topaz.enhancement_passes -eq 2)
        {
            $names = $config.topaz.enhancement_pass_two.psobject.properties.name
            ForEach ($name in $names)
            {
                if ($filter_complex_pass_two -ne "")
                {
                    $filter_complex_pass_two += ":"
                }

                $filter_complex_pass_two += "$name=$($config.topaz.enhancement_pass_two.$name)"
            }
        }

        if ($filter_complex_pass_one -ne "")
        {
            $filter_complex = "tvai_up=$filter_complex_pass_one"
            if ($filter_complex_pass_two -ne "")
            {
                $filter_complex += ",tvai_up=$filter_complex_pass_two"
            }

            $filter_complex += ",scale=w=$($config.upscale_Width):h=$($config.upscale_Height):flags=lanczos:threads=0"
        }

        # Do the upscale
        Start-Process -FilePath $ffmpeg_ai_path -ArgumentList "-y -hide_banner -loglevel quiet -stats -hwaccel auto -i `"$deint_path`" -sws_flags `"spline+accurate_rnd+full_chroma_int`" -color_trc 2 -colorspace 2 -color_primaries 2 -filter_complex `"$filter_complex`" -c:v prores_ks -profile:v 3 -vendor apl0 -quant_mat hq -bits_per_mb 1350 -pix_fmt yuv422p10le -an -map_metadata 0 -map_metadata:s:v 0:s:v -movflags `"use_metadata_tags+write_colr`" -metadata encoding_tool=`"$($config.encoding_tool)`" -f mov `"$upscale_path`"" -NoNewWindow -Wait

        if (Test-Path -LiteralPath $upscale_path -PathType 'Leaf')
        {
            # Remove De-Interlaced temp
            if ($config.clean_temp)
            {
                if (-not (Test-Path -LiteralPath $deint_path -PathType 'Leaf'))
                {
                    Write-Warning "[WARNING]: De-interlaced file not found, cannot remove..."
                }
                else
                {
                    Remove-Item -Path $deint_path
                }
            }
        }
    }
    else
    {
        Write-Information "[INFO]: Detected pre-existing Upscaled file, skipping upscaling stage..."
    }

    if (-not (Test-Path -LiteralPath $encode_path -PathType 'Leaf'))
    {
        # Verify our file was written, or already exists
        if (-not (Test-Path -LiteralPath $upscale_path -PathType 'Leaf'))
        {
            Write-Error "[ERROR]: Upscaled file not found, cannot run encode!"
            continue
        }

        Write-Output "[INFO]: Encoding upscale with x265..."

        $UpscaledMediaFile = [MediaFile]::new($upscale_path)
        $frameCount = $UpscaledMediaFile.getAttribute("Video", "FrameCount")
        $frameRate = $UpscaledMediaFile.getAttribute("Video", "FrameRate")

        # Encode with x265
        Start-Process -FilePath "cmd" -ArgumentList "/c `"`"$ffmpeg_path`" -y -hide_banner -loglevel error -f mov -i `"$upscale_path`" -strict -1 -f yuv4mpegpipe - | `"$x265_path`" --log-level none --y4m --input - --input-res $($config.upscale_Width)x$($config.upscale_Height) --fps $frameRate --frames $frameCount --input-depth 10 --profile main422-10 --level-idc 5.2 --preset placebo --tune animation --crf 20 --rd 4 --psy-rd 0.75 --psy-rdoq 4.0 --rdoq-level 1 --no-strong-intra-smoothing --aq-mode 1 --rskip 2 --no-rect --output `"$encode_path`"`""  -NoNewWindow -Wait

        if (Test-Path -LiteralPath $encode_path -PathType 'Leaf')
        {
            # Remove Upscale temp
            if ($config.clean_temp)
            {
                if (-not (Test-Path -LiteralPath $upscale_path -PathType 'Leaf'))
                {
                    Write-Warning "[WARNING]: Upscaled file not found, cannot remove..."
                }
                else
                {
                    Remove-Item -Path $upscale_path
                }
            }
        }
    }
    else
    {
        Write-Information "[INFO]: Detected pre-existing encoded file, skipping encode stage..."
    }

    # Merge all tracks into a new file
    if (-not (Test-Path -LiteralPath $final_path -PathType 'Leaf'))
    {
        # Verify our file was written, or already exists
        if (-not (Test-Path -LiteralPath $encode_path -PathType 'Leaf'))
        {
            Write-Error "[ERROR]: Encoded file not found, cannot run merge!"
            continue
        }

        # Verify our original file exists too
        if (-not (Test-Path -LiteralPath $file.FullName -PathType 'Leaf'))
        {
            Write-Error "[ERROR]: Original file not found, cannot run merge!"
            continue
        }

        Write-Output "[INFO]: Merging newly upscaled video with previous tracks..."


        # Get video track language
        $video = [MediaFile]::new($file)
        $lang = $video.getAttribute("Video", "Language")

        # Merge our upscaled video & everything but video from our original
        mkvmerge -o "$final_path" --quiet --no-audio --no-subtitles --no-buttons --language 0:$lang "$encode_path" --no-video "$($file.FullName)"

        # Verify we wrote the file
        if (Test-Path -LiteralPath $final_path -PathType 'Leaf')
        {
            # Remove encoded temp
            if ($config.clean_temp)
            {
                if (-not (Test-Path -LiteralPath $encode_path -PathType 'Leaf'))
                {
                    Write-Warning "[WARNING]: Encoded file not found, cannot remove..."
                }
                else
                {
                    Remove-Item -Path $encode_path
                }
            }
        }
    }
    else
    {
        Write-Error "[ERROR]: Detected pre-existing output file, skipping..."
    }
}
