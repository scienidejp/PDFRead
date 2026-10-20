param()

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$VersionMatch = [regex]::Match((Get-Content (Join-Path $Root 'Cargo.toml') -Raw),
  '(?ms)^\[workspace\.package\].*?^version\s*=\s*"([^"]+)"')
if (-not $VersionMatch.Success) { throw 'could not read workspace version from Cargo.toml' }
$Version = $VersionMatch.Groups[1].Value
if ($env:GITHUB_REF_TYPE -eq 'tag' -and $env:GITHUB_REF_NAME -ne "v$Version") {
  throw "release tag $env:GITHUB_REF_NAME does not match workspace version $Version"
}
$Target = 'x86_64-pc-windows-msvc'
$TargetDir = if ($env:CARGO_TARGET_DIR) { $env:CARGO_TARGET_DIR } else { Join-Path $Root 'target' }
$Dist = if ($env:DIST) { $env:DIST } else { Join-Path $Root 'dist\release' }
$Stage = Join-Path $TargetDir 'readpdf-windows-package'
$Bin = Join-Path $TargetDir "$Target\release\pdfcraft.exe"
$Compiler = Get-Command iscc.exe -ErrorAction SilentlyContinue
if (-not $Compiler) {
  $CompilerPath = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
  if (-not (Test-Path $CompilerPath)) { throw 'Inno Setup 6 is required to build the ReadPDF setup installer' }
  $CompilerPath
} else {
  $CompilerPath = $Compiler.Source
}

New-Item -ItemType Directory -Force -Path $Dist | Out-Null
$env:PDFCRAFT_REQUIRE_WINRES = '1'
$env:CARGO_TARGET_X86_64_PC_WINDOWS_MSVC_RUSTFLAGS = '-C target-feature=+crt-static'
cargo build --release --locked -p pdfcraft --target $Target
if ($LASTEXITCODE -ne 0) { throw "cargo build failed with exit code $LASTEXITCODE" }

Remove-Item -Recurse -Force $Stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $Stage | Out-Null
Copy-Item $Bin (Join-Path $Stage 'readpdf.exe')
$Models = Join-Path $Stage 'models'
New-Item -ItemType Directory -Force -Path $Models | Out-Null
cargo xtask models $Models
if ($LASTEXITCODE -ne 0) { throw "cargo xtask models failed with exit code $LASTEXITCODE" }
if (-not (Test-Path (Join-Path $Models 'ATTRIBUTION.txt')) -or
    -not (Get-ChildItem (Join-Path $Models '*.LICENCE.txt'))) {
  throw "no OCR models in $Models after cargo xtask models"
}
foreach ($File in 'LICENSE-MIT', 'LICENSE-APACHE', 'NOTICE') {
  Copy-Item (Join-Path $Root $File) $Stage
}
Copy-Item (Join-Path $Root 'assets\app-icon\LICENSE-document.txt') $Stage

$OutputDir = [IO.Path]::GetFullPath($Dist)
$IconPath = Join-Path $Root 'assets\app-icon\readpdf.ico'
& $CompilerPath "/DAppVersion=$Version" "/DStageDir=$Stage" "/DOutputDir=$OutputDir" "/DIconPath=$IconPath" `
  (Join-Path $PSScriptRoot 'readpdf.iss')
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE" }

$Setup = Join-Path $Dist "readpdf-$Version-windows-x64-setup.exe"
if (-not (Test-Path $Setup)) { throw "Inno Setup did not create $Setup" }
$Bytes = [IO.File]::ReadAllBytes($Setup)
if ($Bytes.Length -lt 2 -or $Bytes[0] -ne 0x4D -or $Bytes[1] -ne 0x5A) {
  throw "$Setup is not a Windows executable"
}
$SmokeInstall = Join-Path $TargetDir 'readpdf-installer-smoke'
Remove-Item -Recurse -Force $SmokeInstall -ErrorAction SilentlyContinue
$InstallerLog = Join-Path $TargetDir 'readpdf-installer-smoke.log'
$InstallerArgs = @('/VERYSILENT', "/DIR=`"$SmokeInstall`"", '/NOICONS', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=`"$InstallerLog`"")
$InstallProcess = Start-Process -FilePath $Setup -ArgumentList $InstallerArgs -Wait -PassThru
if ($InstallProcess.ExitCode -ne 0) { throw "silent installer smoke test failed with exit code $($InstallProcess.ExitCode)" }
$InstalledApp = Join-Path $SmokeInstall 'readpdf.exe'
$ModelAttribution = Join-Path $SmokeInstall 'models\ATTRIBUTION.txt'
if (-not (Test-Path $InstalledApp) -or -not (Test-Path $ModelAttribution)) {
  $InstalledFiles = if (Test-Path $SmokeInstall) {
    (Get-ChildItem $SmokeInstall -Recurse -File | ForEach-Object FullName) -join "`n"
  } else {
    '<install directory not created>'
  }
  $InstallerLogContent = if (Test-Path $InstallerLog) { Get-Content $InstallerLog -Raw } else { '<installer log not created>' }
  throw "silent installer smoke test failed: app=$(Test-Path $InstalledApp), model attribution=$(Test-Path $ModelAttribution)`n$InstalledFiles`n$InstallerLogContent"
}
& $InstalledApp --version
if ($LASTEXITCODE -ne 0) { throw "installed ReadPDF version check failed with exit code $LASTEXITCODE" }
& (Join-Path $SmokeInstall 'unins000.exe') /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
if ($LASTEXITCODE -ne 0) { throw "silent uninstall smoke test failed with exit code $LASTEXITCODE" }
Get-Item $Setup | Format-Table Name, Length
