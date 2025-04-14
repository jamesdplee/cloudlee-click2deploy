$tempDir = [System.IO.Path]::GetTempPath()

# Set up the environment
$dotnetHostBundleExe = "dotnet-hosting-6.0.36-win.exe"
$dotnetHostBundleUri = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/6.0.36/$dotnetHostBundleExe"
$dotnetHostBundleExePath = "$tempDir\$dotnetHostBundleExe"
$dotnetHostBundleExeArgs = New-Object -TypeName System.Collections.Generic.List[System.String]
$dotnetHostBundleExeArgs.Add("/quiet")
$dotnetHostBundleExeArgs.Add("/norestart")

# WebApp config
$webappUri = "https://github.com/jamesdplee/ausemartweb.git"
$webappSrcPath = "$tempDir\src"
$iisPath = "C:\inetpub\wwwroot"

# Download/prep files
Invoke-WebRequest -Uri $dotnetHostBundleUri -OutFile $dotnetHostBundleExePath
if (-Not (Test-Path $webappSrcPath)) {
    New-Item -Path $webappSrcPath -ItemType "directory"
}
git clone $webappUri $webappSrcPath

# Install IIS and dotnet hosting bundle
Install-WindowsFeature -name Web-Server -IncludeManagementTools
Start-Process -FilePath $dotnetHostBundleExePath -ArgumentList $dotnetHostBundleExeArgs -NoNewWindow -Wait -PassThru -WorkingDirectory $tempDir

# Build and publish the webapp
Set-Location $webappSrcPath
dotnet build
dotnet publish --output $iisPath