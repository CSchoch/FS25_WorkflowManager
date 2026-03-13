param(
    [string]$Src,
    [string]$Dst
)

$include = @('modDesc.xml', 'modIcon.png', 'src', 'textures', 'translations', 'xml')
$exclude = @('src/DevConfig.lua')
$srcLen  = $Src.Length

Add-Type -Assembly 'System.IO.Compression.FileSystem'
$zip = [System.IO.Compression.ZipFile]::Open($Dst, 'Create')

foreach ($name in $include) {
    $item = Join-Path $Src $name
    if (-not (Test-Path $item)) { continue }

    if (Test-Path $item -PathType Leaf) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $item, $name) | Out-Null
    } else {
        Get-ChildItem $item -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($srcLen + 1).Replace('\', '/')
            if ($exclude -contains $rel) { return }
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel) | Out-Null
        }
    }
}

$zip.Dispose()
Write-Host "Done."
