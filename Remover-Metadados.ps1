#requires -Version 5.1
<#
.SYNOPSIS
Remove metadados editaveis de imagens sem reexportar ou recomprimir.
.EXAMPLE
.\Remover-Metadados.ps1 -Caminho 'C:\Fotos\foto.jpg'
.EXAMPLE
.\Remover-Metadados.ps1 -Caminho 'C:\Fotos\a.png','C:\Fotos\b.webp' -PreservarAparencia
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$Caminho,
    [string]$PastaSaida,
    [string]$ExifToolPath,
    [switch]$PreservarAparencia
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($ExifToolPath) {
    $tool = (Get-Item -LiteralPath $ExifToolPath -ErrorAction Stop).FullName
} else {
    $tool = $null
    foreach ($candidate in @((Join-Path $PSScriptRoot 'exiftool.exe'), (Join-Path $PSScriptRoot 'exiftool\exiftool.exe'))) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $tool = $candidate; break }
    }
    if (-not $tool) {
        $command = Get-Command exiftool -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $tool = $command.Source }
    }
    if (-not $tool) {
        throw 'ExifTool nao encontrado. Baixe a versao Windows em https://exiftool.org/, extraia o pacote inteiro e renomeie exiftool(-k).exe para exiftool.exe. Coloque o executavel e exiftool_files junto deste script ou use -ExifToolPath.'
    }
}

function Invoke-MetadataTool {
    param([string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = & $tool @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    $message = ($lines | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($code -ne 0) { throw "ExifTool retornou erro ${code}: $message" }
    return $message
}

function Get-ImageInfo {
    param([string]$File)
    $json = Invoke-MetadataTool -Arguments @('-q', '-q', '-json', '-n', '-api', 'ImageHashType=SHA256', '-FileType', '-FileTypeExtension', '-MIMEType', '-ImageWidth', '-ImageHeight', '-ImageDataHash', $File)
    return @($json | ConvertFrom-Json)[0]
}

function Get-InfoValue {
    param($Info, [string]$Name)
    $property = $Info.PSObject.Properties[$Name]
    if ($null -ne $property) { return $property.Value }
    return $null
}

# Formatos fotograficos comuns; RAWs e documentos nao sao alterados.
$supported = @('JPG', 'JPEG', 'PNG', 'WEBP', 'TIF', 'TIFF', 'GIF', 'HEIC', 'HEIF', 'AVIF', 'JXL', 'JP2', 'PSD', 'JNG', 'MNG')
$failures = 0
foreach ($inputPath in $Caminho) {
    $temporary = $null
    try {
        $file = Get-Item -LiteralPath $inputPath -ErrorAction Stop
        if ($file.PSIsContainer) { throw 'Informe um arquivo de imagem, em vez de uma pasta.' }
        $before = Get-ImageInfo -File $file.FullName
        $type = Get-InfoValue -Info $before -Name 'FileTypeExtension'
        if ($type -notin $supported) { throw "Formato '$type' nao atendido por este script. Converta/exporte uma copia para PNG ou JPG primeiro." }

        if ($PastaSaida) {
            $directory = [System.IO.Path]::GetFullPath($PastaSaida)
            [System.IO.Directory]::CreateDirectory($directory) | Out-Null
        } else { $directory = $file.DirectoryName }

        # A ferramenta altera somente a copia temporaria; o original permanece intacto.
        $temporary = Join-Path $directory ('.metadata-' + [guid]::NewGuid().ToString('N') + $file.Extension)
        [System.IO.File]::Copy($file.FullName, $temporary, $false)
        $arguments = @('-overwrite_original', '-all=')
        if ($PreservarAparencia) {
            # Mantem apenas os metadados de cor e orientacao necessarios a exibicao.
            $arguments += @('-tagsFromFile', '@', '-ColorSpaceTags', '-Orientation')
        }
        $arguments += $temporary
        $toolOutput = Invoke-MetadataTool -Arguments $arguments
        $after = Get-ImageInfo -File $temporary

        foreach ($dimension in @('ImageWidth', 'ImageHeight')) {
            $old = Get-InfoValue -Info $before -Name $dimension
            $new = Get-InfoValue -Info $after -Name $dimension
            if ($null -ne $old -and $old -ne $new) { throw "Verificacao falhou: $dimension mudou." }
        }
        $hashBefore = Get-InfoValue -Info $before -Name 'ImageDataHash'
        $hashAfter = Get-InfoValue -Info $after -Name 'ImageDataHash'
        $verification = 'Dimensoes verificadas; hash de imagem indisponivel neste formato.'
        if ($hashBefore) {
            if (-not $hashAfter -or $hashBefore -ne $hashAfter) { throw 'Verificacao falhou: os dados comprimidos da imagem mudaram.' }
            $verification = 'Hash dos dados da imagem identico.'
        }

        $stem = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) + '-sem-metadados'
        $destination = Join-Path $directory ($stem + $file.Extension)
        $number = 1
        while (Test-Path -LiteralPath $destination) {
            $destination = Join-Path $directory ($stem + '-' + $number + $file.Extension)
            $number++
        }
        # Move sem substituir um arquivo preexistente.
        [System.IO.File]::Move($temporary, $destination)
        $temporary = $null
        [pscustomobject]@{
            Original = $file.FullName
            ArquivoLimpo = $destination
            Verificacao = $verification
            PreservouCorEOrientacao = [bool]$PreservarAparencia
        }
    } catch {
        $failures++
        Write-Error -Message ("Falha em '{0}': {1}" -f $inputPath, $_.Exception.Message) -ErrorAction Continue
    } finally {
        if ($temporary -and [System.IO.File]::Exists($temporary)) { [System.IO.File]::Delete($temporary) }
    }
}
if ($failures -gt 0) { throw "$failures arquivo(s) nao foram processados. Os originais foram preservados." }
