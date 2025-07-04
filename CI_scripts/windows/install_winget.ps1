
# Find the latest winget release URL from the GitHub API
$wingetReleaseUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
$releaseInfo = Invoke-RestMethod -Uri $wingetReleaseUrl
$msixBundleAsset = $releaseInfo.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1

if ($msixBundleAsset) {
    $downloadUrl = $msixBundleAsset.browser_download_url
    $outputFile = Join-Path $env:TEMP "winget.msixbundle"

    # Download the msixbundle
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outputFile

    # Install the package
    Add-AppxPackage -Path $outputFile
} else {
    Write-Error "Could not find the winget msixbundle in the latest release."
    exit 1
}
