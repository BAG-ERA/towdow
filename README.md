# TowDow_app

## manual releases

So far only the web is deployed by the CI. The rest has to be done manually.

### Windows

Upload the MSI generated in the release (https://gitlab.com/towdow/towdow-flutter/-/releases/permalink/latest) to the Microsoft Store.

### Flatpak

https://github.com/TheAppgineer/flatpak-flutter

### Snapcraft

1. login ```snapcraft login``` (use login from vault _TowDow ubuntu / snapcraft_) 
2. get the .snap file from release (https://gitlab.com/towdow/towdow-flutter/-/releases/permalink/latest)
3. upload the snap file to the snapcraft store ```snapcraft upload --release=stable TowDow_app_X.Y.Y_amd64.snap```
4. publish the snap ```snapcraft publish TowDow_app_X.Y.Y_amd64.snap --release=stable```

### Android

upload aab to the play store console to create a new release.

## CI and runners

The CI is responsible for building and create a release of the app available here: https://gitlab.com/towdow/towdow-flutter/-/releases/latest.

The CI is configured to run on gitlab runners.

### runners

Some specific configuration is needed for the runners. See the CI_scripts folder for more information.

Some jobs require specific hardware or configuration to run. Such runners have been configured on the default runners VM. Some on different PCs.

When a specific runner is needed for a job, a tag is used to run the job by a runner capable of running the job.

The current status is:

* **build for windows**: needs either a Windows pro computer to run Windows docker or a Windows PC to have a runner with a power shell. 
   The later option is currently used. To run the job the PC MUST be on and gitlab runner service MUST be active
   To check the status of the pawer shell gitlab runner:
   ```powershell
   cd C:\GitLab-Runner
   .\gitlab-runner.exe --debug run
   ```
* **Android**: no specific needed, apart from a more powerful computer than the VM hosting the default runners so a TAG is used and the PC MUST be up.
* **Flatpak**: needs a privileged docker (one is configured on the default VM)
* **Snapcraft**: needs lxd to runner, it was simpler to use a PC than to configure a gitlab runner to work with lxd.
* **Linux app image**: 


## local development

### cursor configuration

Configuration for Cursor are found in [mvvm.mdc](.cursor/rules/mvvm.mdc)

### Junie configuration

Junie (the autonomous assistant used in this repo) looks for its configuration files in the following location within this project:

- Directory: .junie/rules/
- Active example: .junie/rules/guidelines.md

Guidelines files are plain Markdown with a YAML front matter block at the top. This repo uses:

- globs: a list of file patterns the rule applies to (e.g., "**/*.dart", "**/*.md")
- alwaysApply: when true, Junie applies the rule automatically without needing explicit selection

Note: .junie/guidelines.md is only a pointer indicating that guidelines have been relocated to .junie/rules/guidelines.md.

### Web

When running flutter in your browser for local test (ex. ```flutter run -d chrome```) you MUST authorise the origin in KeyCloak to prevent CORS errors.
For TowDow Cloud we allow the following origins for test:
* http://localhost:36123
* http://127.0.0.1:8080
* http://127.0.0.1:8000

to run the application locally use this command:
```shell
flutter run -d chrome --web-port=36123
```

## configuring CI

The CI is used to build and release the app.
It uses custom docker images to build configured to build for Linux and Android.
These images will be created / updated automatically when a change is pushed to the default branch.

If you want to manually build the image you can do this:

### Android

```shell
docker login registry.gitlab.com/towdow/towdow-flutter
export FLUTTER_VERSION=3.35.2
export ANDROID_TOOL_VERSION_X=34
export ANDROID_TOOL_VERSION=34.0.0
docker build --build-arg FLUTTER_VERSION=${FLUTTER_VERSION} \
  --build-arg ANDROID_TOOL_VERSION_X=${ANDROID_TOOL_VERSION_X} \
  --build-arg ANDROID_TOOL_VERSION=${ANDROID_TOOL_VERSION} \
  -t registry.gitlab.com/towdow/towdow-flutter/flutter-build-env:${FLUTTER_VERSION} \
  -f CI_scripts/linux/Dockerfile .
docker push registry.gitlab.com/towdow/towdow-flutter/flutter-build-env:${FLUTTER_VERSION}
```

CI variables are encoded in base4 to allow to mask them in the CI logs. To encode theme here are the commands:
1. ```KEY_PROPERTIES_PASSWORD```: CI variable containing upload password
    ```shell
    echo __PASS__ | base64
    ```
2. ```JKS_BASE_64```: CI variable containing the jks file
    ```shell
    echo $(openssl base64 -A -in upload-keystore.jks)
    ```

### Linux

#### flatpak image builder

```shell
export FLATPAK_RUNTIME_VERSION=48
docker login registry.gitlab.com/towdow/towdow-flutter
docker build --build-arg FLATPAK_RUNTIME_VERSION=${FLATPAK_RUNTIME_VERSION} \
-t registry.gitlab.com/towdow/towdow-flutter/build-flatpak:${FLATPAK_RUNTIME_VERSION} \
-f CI_scripts/linux/flatpak/Dockerfile .
docker push registry.gitlab.com/towdow/towdow-flutter/build-flatpak:${FLATPAK_RUNTIME_VERSION}
```

### Windows

So far we are not using docker on Windows because we need Windows pro to use docker windows, but if one is available 
we could do the same as for Linux and build a Windows docker to build with the CI.   

```shell
docker login registry.gitlab.com/towdow/towdow-flutter
export FLUTTER_VERSION=3.35.2
docker build --build-arg FLUTTER_VERSION=${FLUTTER_VERSION} \
  -t registry.gitlab.com/towdow/towdow-flutter/flutter-windows-build-env:${FLUTTER_VERSION} \
  -f CI_scripts/windows/Dockerfile .
```

The other option is to use shell runners on our PC. For this do the following:

1. Configure flutter development environment https://docs.flutter.dev/get-started/install/windows/desktop
    * Flutter **MUST** be installed in ```C:\flutter``` for the CI to work  
2. install gitlab runner in ```C:\GitLab-Runner``` https://docs.gitlab.com/runner/install/windows/
3. configure a new project runner  
4. set shell executor to powershell in ```C:\GitLab-Runner\config.toml``` (https://docs.gitlab.com/runner/executors/shell/#selecting-your-shell)
   

