class MediaFile
{
    [System.IO.FileSystemInfo] $file
    [String] $fileName

    MediaFile([System.IO.FileSystemInfo] $mediaFile)
    {
        $this.file = $mediaFile
        $this.fileName = $mediaFile.FullName
    }

    MediaFile([String] $fileName)
    {
        $this.filename = $fileName
        $this.file = Get-Item -Path $fileName
    }

    [String] getVideoProperty([String] $property) { return getAttribute("Video", $property) }

    [String] getAttribute([String] $kind, [String] $property)
    {
        $ret = mediainfo --Output="$kind;%$property%" "$($this.fileName)" | Out-String -NoNewLine
        return $ret.Trim()
    }
}

class MKVFile : MediaFile
{
    MKVFile([System.IO.FileSystemInfo] $mkvFile) : base($mkvFile) {}

    [void] setVideoProperty([int] $track, [String] $key, [String] $value)
    {
        mkvpropedit "$($this.file.FullName)" --edit track:v$track --set $key="$value" | Out-Null
    }
}
