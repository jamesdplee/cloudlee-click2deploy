$tempDir = [System.IO.Path]::GetTempPath()
$dotnetHostBundleExe = "dotnet-hosting-7.0.3-win.exe"
$dotnetHostBundleUri = "https://download.visualstudio.microsoft.com/download/pr/ff197e9e-44ac-40af-8ba7-267d92e9e4fa/d24439192bc549b42f9fcb71ecb005c0/$dotnetHostBundleExe"
$dotnetHostBundleExePath = "$tempDir\$dotnetHostBundleExe"
$dotnetHostBundleExeArgs = New-Object -TypeName System.Collections.Generic.List[System.String]
$dotnetHostBundleExeArgs.Add("/quiet")
$dotnetHostBundleExeArgs.Add("/norestart")

# Download/prep files
wget $dotnetHostBundleUri -o $dotnetHostBundleExePath

# Install IIS and dotnet hosting bundle
Install-WindowsFeature -name Web-Server -IncludeManagementTools
Start-Process -FilePath $dotnetHostBundleExePath -ArgumentList $dotnetHostBundleExeArgs -NoNewWindow -Wait -PassThru -WorkingDirectory $tempDir