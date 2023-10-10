# Stardust Upscaler
# Author: SubtleNinja
# Date: 2023-09-09
# 
# Changelog:
# v4 - 2023-10-10
# - Use DGIndex
# - Removed maintainPAR, replaced with force_square_pixels
# - QTGMC will now run on 'Draft' for minimal processing
# - Allow overriding input/output FPS
# - Bug fixes
#
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
    encoding_tool = "Stardust Upscaler v4"

    # Input, Output, and temporary folders
    input_folder = "E:/Stargate SG-1/Season 1"
    output_folder = "E:/Stargate SG-1 - AI Upscale/Season 1"
    temp_folder = "E:/temp"

    # Utility folders
    topaz_video_ai_location = "C:/Program Files/Topaz Labs LLC/Topaz Video AI"
    hybrid_location = "C:/Program Files/Hybrid"

    # Process settings
    clean_temp = $true
    skip_existing = $true

    # De-interlace settings
    auto_crop = $false
    force_square_pixels = $true
    vs_resample_kernel = 'spline16'

    force_input_fps = $false
    force_output_fps = $true

    input_frame_rate_num = $null
    input_frame_rate_den = $null

    output_frame_rate_num = 30000
    output_frame_rate_den = 1001

    # Target dimensions
    upscale_Width = 1920
    upscale_Height = 1080

    topaz = [PSCustomObject]@{
        enhancement_passes = 2

        enhancement_pass_one = [PSCustomObject]@{
            # AI Model
            model       = "prob-3"

            # Has Another Enhancement?
            scale       = 2

            # Anti-Alias/Deblur
            preblur     = 0.2

            # Reduce Noise
            noise       = 0.2

            # Improve Detail
            details     = 0.15

            # De-halo
            halo        = 0

            # Sharpen
            blur        = 0

            # Recover Original Detail
            blend       = 0.2 

            # Revert Compression
            compression = 0.35

            # estimate    = 20

            # Grain Amount
            grain       = 0.02

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
            w           = 1920
            h           = 1080
            preblur     = 0.3
            noise       = 0.2
            details     = 0.15
            halo        = 0
            blur        = 0.15
            compression = 0
            # estimate = 20
            blend       = 0.2
            grain       = 0.02
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
$dgindex_path = "$toolsPath/dgmpgdec/DGIndex.exe"
$d2vsource_path = "$toolsPath/vsfilters/d2vsource/win64/d2vsource.dll"

# Aliases for direct program execution
Set-Alias -Name mediainfo -Value $mediainfo_path
Set-Alias -Name ffmpeg -Value $ffmpeg_path
Set-Alias -Name ffprobe -Value $ffprobe_path
Set-Alias -Name mkvmerge -Value $mkvmerge_path
Set-Alias -Name mkvpropedit -Value $mkvpropredit_path
Set-Alias -Name DGIndex -Value $dgindex_path

# Include other files
. "Modules/MediaFile.ps1"

# Get input files
$files = Get-ChildItem -LiteralPath $config.input_folder -File | Where-Object { $_.extension.toLower() -in @(
    ".mpg", ".vob", ".mpeg", ".m2ts"
    ) }

# If configured, remove any that already exist
if ($config.skip_existing)
{
    $files = $files | Where-Object { -not (Test-Path -LiteralPath "$($config.output_folder)/$($_.BaseName).mkv" -PathType 'Leaf') }

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
    $temp_path = "$($config.temp_folder)/$($file.BaseName)"
    $d2v_path = "$($temp_path).d2v"
    $deint_path = "$($temp_path)_deinterlaced.mov"
    $upscale_path = "$($temp_path)_upscaled.mov"
    $encode_path = "$($temp_path)_encoded.h265"
    $final_path = "$($config.output_folder)/$($file.BaseName).mkv"

    # Timing
    $start_time = Get-Date

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
    $PAR = [float]$mediaFile.getAttribute("Video", "PixelAspectRatio")
    $DAR = [float]$mediaFile.getAttribute("Video", "DisplayAspectRatio")
    $Width = [int]$mediaFile.getAttribute("Video", "Width")
    $Height = [int]$mediaFile.getAttribute("Video", "Height")

    if ($config.force_input_fps)
    {
        $frameRate_Num = $config.input_frame_rate_num
        $frameRate_Den = $config.input_frame_rate_den
        $frameRate = [Math]::Round($frameRate_Num / $frameRate_Den, 3)

        Write-Output "[INFO]: Forcing input FPS: $frameRate"
    }
    else
    {
        $frameRate = [float]$mediaFile.getAttribute("Video", "FrameRate", $frameRate)
        $frameRate_Num = [int]$mediaFile.getAttribute("Video", "FrameRate_Num", $frameRate_Num)
        $frameRate_Den = [int]$mediaFile.getAttribute("Video", "FrameRate_Den", $frameRate_Den)
    }

    if ($config.force_output_fps)
    {
        $frameRate_Out_Num = $config.output_frame_rate_num
        $frameRate_Out_Den = $config.output_frame_rate_den
        $frameRateNew = [Math]::Round($frameRate_Out_Num / $frameRate_Out_Den, 3)

        Write-Output "[INFO]: Forcing output FPS: $frameRateNew"
    }
    else
    {
        $frameRate_Out_Num = [int]$mediaFile.getAttribute("Video", "FrameRate_Num", $frameRate_Num)
        $frameRate_Out_Den = [int]$mediaFile.getAttribute("Video", "FrameRate_Den", $frameRate_Den)
        $frameRateNew = [Math]::Round($frameRate_Out_Num / $frameRate_Out_Den, 3)
    }

    Write-Output "[INFO]: FPS: $frameRate -> $frameRateNew"

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

            $cropInfo = ffmpeg -hide_banner -ss 00:07:00 -i $file.FullName -an -vframes 10 -vf cropdetect=24:16:00 -f null - 2>&1 | Out-String

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
        }

        if ($config.force_square_pixels)
        {
            $PARWidth = [Math]::Floor($width * $PAR)
            if ($PARWidth % 2)
            {
                $PARWidth = $PARWidth + ($PARWidth % 2)
            }

            # PAR 1:1 conversion (Square pixel)
            $out = "[INFO]: Resizing using '$($config.vs_resample_kernel)', "
            $out += "$($Width - ($cropValues.left + $cropValues.right))x$($Height - ($cropValues.top + $cropValues.bottom))"
            $out += " -> $($PARWidth)x$($Height)"
            Write-Output $out
        }

        $vs_input_path = $file.FullName
        if (
            $file.extension.toLower() -eq ".vob" -or
            $file.extension.toLower() -eq ".m2ts"
            )
        {
            if (-not (Test-Path -LiteralPath "$d2v_path" -PathType 'Leaf'))
            {
                Write-Output "[INFO]: Generating D2V file with DGIndex..."

                DGIndex -i "`"$($file.FullName)`"" -o "`"$temp_path`"" -fo 0 -om 0 -hide -exit | Out-Null

                Start-Sleep 1

                if (Test-Path -LiteralPath "$d2v_path" -PathType 'Leaf')
                {
                    $vs_input_path = $d2v_path
                }
                else
                {
                    Write-Error "[ERROR]: Failed to write D2V file!"
                }
            }
        }

        Write-Output "[INFO]: De-interlacing with VapourSynth..."

        $start_time = Get-Date

        $arguments = [PSCustomObject]@{

            hybrid_path = "`"$($config.hybrid_location)`""

            d2vsource_path = "`"$($d2vsource_path)`""

            input_file = "`"$($vs_input_path)`""

            PixelAspectRatio = $PAR
            DisplayAspectRatio = $DAR
            force_square_pixels = $($config.force_square_pixels)

            width = $Width
            height = $Height

            FrameRate = $frameRate
            FrameRateNew = $frameRateNew
            FrameRate_Num = $frameRate_Num
            FrameRate_Out_Num = $frameRate_Out_Num
            FrameRate_Den = $frameRate_Den
            FrameRate_Out_Den = $frameRate_Out_Den

            cropTop = $($cropValues.top)
            cropBottom = $($cropValues.bottom)
            cropLeft = $($cropValues.left)
            cropRight = $($cropValues.right)

            resample_kernel = $($config.vs_resample_kernel)
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
        Start-Process -FilePath "cmd" -ArgumentList "/c `"`"$vspipe_path`" $argString --container y4m `"SynthSkript.vpy`" - | `"$ffmpeg_path`" -y -hide_banner -loglevel error -stats -noautorotate -nostdin -threads 8 -f yuv4mpegpipe -i - -an -sn -vf `"zscale=rangein=tv:range=tv`" -strict -1 -fps_mode passthrough -vcodec prores_ks -profile:v 3 -vtag apch -aspect $DAR -metadata encoding_tool=`"$($config.encoding_tool)`" -f mov `"$deint_path`"`"" -NoNewWindow -Wait

        $now = Get-Date
        $time_taken = New-TimeSpan -Start $start_time -End $now

        Write-Output "[INFO] Done. Took: $($time_taken.toString())"
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

        $start_time = Get-Date

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

        $now = Get-Date
        $time_taken = New-TimeSpan -Start $start_time -End $now

        Write-Output "[INFO] Done. Took: $($time_taken.toString())"

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

                if (Test-Path -LiteralPath $d2v_path -PathType 'Leaf')
                {
                    Remove-Item -Path $d2v_path
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

        $start_time = Get-Date

        $UpscaledMediaFile = [MediaFile]::new($upscale_path)
        $frameCount = $UpscaledMediaFile.getAttribute("Video", "FrameCount")
        $frameRate = $UpscaledMediaFile.getAttribute("Video", "FrameRate")

        # Encode with x265
        Start-Process -FilePath "cmd" -ArgumentList "/c `"`"$ffmpeg_path`" -y -hide_banner -loglevel error -f mov -i `"$upscale_path`" -strict -1 -f yuv4mpegpipe - | `"$x265_path`" --log-level none --y4m --input - --input-res $($config.upscale_Width)x$($config.upscale_Height) --fps $frameRate --frames $frameCount --input-depth 10 --profile main422-10 --level-idc 5.2 --preset placebo --tune grain --crf 24 --rd 4 --psy-rd 0.75 --psy-rdoq 4.0 --rdoq-level 1 --no-strong-intra-smoothing --aq-mode 1 --rskip 2 --no-rect --output `"$encode_path`"`""  -NoNewWindow -Wait

        $now = Get-Date
        $time_taken = New-TimeSpan -Start $start_time -End $now

        Write-Output "[INFO] Done. Took: $($time_taken.toString())"

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
        if ($lang.length)
        {
            mkvmerge -o "$final_path" --quiet --no-audio --no-subtitles --no-buttons --language 0:$lang "$encode_path" --no-video "$($file.FullName)"
        }
        else
        {
            mkvmerge -o "$final_path" --quiet --no-audio --no-subtitles --no-buttons "$encode_path" --no-video "$($file.FullName)"
        }

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
