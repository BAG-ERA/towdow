
# Use a Windows Server Core base image
FROM mcr.microsoft.com/windows/servercore:ltsc2019

# Set up Chocolatey
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
RUN iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Install GitLab Runner
RUN choco install gitlab-runner -y

# Install Flutter SDK
RUN choco install flutter -y

# Install Visual Studio Build Tools
RUN choco install visualstudio2019buildtools --package-parameters "--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041" -y

# Set up the working directory
WORKDIR C:\Users\ContainerUser\AppData\Local

# Copy the Flutter app source code
COPY . .

# Set the entrypoint to the GitLab Runner executable
ENTRYPOINT ["C:\ProgramData\chocolatey\bin\gitlab-runner.exe"]
