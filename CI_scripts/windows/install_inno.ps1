# This script installs Inno Setup from a local installer.
$ErrorActionPreference = "Stop"

Write-Host "--- Installing Inno Setup from local file ---"
try {
    # Step 1: Define the path to the local installer.
    $inno_installer = ".\CI_scripts\windows\innosetup-6.4.3.exe"
    Write-Host "Using installer: $inno_installer"

    # Check if the installer exists
    if (-not (Test-Path $inno_installer)) {
        Write-Error "Inno Setup installer not found at $inno_installer"
        exit 1
    }

    # Step 2: Run the installer silently.
    Write-Host "Installing Inno Setup silently..."
    Start-Process -FilePath $inno_installer -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" -Wait

    # Step 3: Add Inno Setup to the PATH for the current session.
    $inno_path = "C:\Program Files (x86)\Inno Setup 6"
    Write-Host "Adding '$inno_path' to the PATH environment variable."
    $env:Path = "$($env:Path);$inno_path"

    Write-Host "Inno Setup has been installed and configured successfully."

} catch {
    Write-Error "An error occurred during Inno Setup installation: $_"
    exit 1
}