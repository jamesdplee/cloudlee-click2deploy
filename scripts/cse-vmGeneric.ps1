# Download the Azure CLI installer
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindowsx64 -OutFile AzureCLI.msi

# Run the installer silently
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'