# TowDow_app

## local development

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
export FLUTTER_VERSION=3.32.5
export ANDROID_TOOL_VERSION_X=34
export ANDROID_TOOL_VERSION=34.0.0
docker build --build-arg FLUTTER_VERSION=${FLUTTER_VERSION} \
  --build-arg ANDROID_TOOL_VERSION_X=${ANDROID_TOOL_VERSION_X} \
  --build-arg ANDROID_TOOL_VERSION=${ANDROID_TOOL_VERSION} \
  -t registry.gitlab.com/towdow/towdow-flutter/flutter-build-env:${FLUTTER_VERSION} \
  -f CI_scripts/linux/Dockerfile .
docker push registry.gitlab.com/towdow/towdow-flutter/flutter-build-env:${FLUTTER_VERSION}
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
export FLUTTER_VERSION=3.32.5
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
   

