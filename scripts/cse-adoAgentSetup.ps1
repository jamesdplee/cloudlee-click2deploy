param ($devOpsUri, $devOpsPAT)

# Download Azure DevOps Pool Agent & extract
wget https://vstsagentpackage.azureedge.net/agent/2.214.1/vsts-agent-win-x64-2.214.1.zip -o vsts-agent.zip
New-Item -Path "C:\" -Name "agent" -ItemType "directory"
Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\vsts-agent.zip", "C:\agent")

# Setup Azure DevOps Pool Agent
Set-Location C:\agent
.\config --unattended --url $devOpsUri --auth pat --token $devOpsPAT --runAsService
