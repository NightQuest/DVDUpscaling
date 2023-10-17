
# Topaz Video AI model directories - required
$regEntry = Get-Item 'HKLM:\SOFTWARE\Topaz Labs LLC\Topaz Video AI'
if (-not $regEntry)
{
    Write-Error "[ERROR]: Cannot Find Topaz Video AI Registry Entry! Are you sure it's installed?"
    exit
}

$modelDir = $regEntry.GetValue('ModelDir').Trim('\\')
if (-not $modelDir.length)
{
    Write-Error "[ERROR]: Cannot Find Topaz Video AI's modelDir Registry Entry!"
    exit
}

if (-not (Test-Path -LiteralPath $modelDir -PathType 'Container'))
{
    Write-Error "[ERROR]: Not a valid directory: `"$($modelDir)`""
    exit
}

$topazVAIDir = $regEntry.GetValue('InstallDir').Trim('\\')
if (-not $topazVAIDir.length)
{
    Write-Error "[ERROR]: Cannot Find Topaz Video AI's modelDir Registry Entry!"
    exit
}

if (-not (Test-Path -LiteralPath $topazVAIDir -PathType 'Container'))
{
    Write-Error "[ERROR]: Not a valid directory: `"$($topazVAIDir)`""
    exit
}

$env:TVAI_MODEL_DATA_DIR = $modelDir
$env:TVAI_MODEL_DIR = $modelDir


# Current working directory
$curLoc = (Get-Location).Path
$toolsPath = "$curLoc/bin"

# Tool paths
$vspipe_path = "$($config.hybrid_location)/64bit/Vapoursynth/VSPipe.exe"
$ffmpeg_ai_path = "$topazVAIDir/ffmpeg.exe"
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
