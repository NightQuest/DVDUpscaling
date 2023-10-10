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
        return $this.getAttribute($kind, $property, "")
    }

    [String] getAttribute([String] $kind, [String] $property, [String] $defaultValue)
    {
        $ret = mediainfo --Output="$kind;%$property%" "$($this.fileName)" | Out-String -NoNewLine
        $ret = $ret.Trim()

        if (-not $ret)
        {
            return $defaultValue
        }

        return $ret
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
