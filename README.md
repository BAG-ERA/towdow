# TowDow_app



## configuring CI

The CI is used to build and release the app.
It uses custom docker images to build configured to build for Linux and Android.
These images will be created / updated automatically when a change is pushed to the default branch.

If you want to manually build the image you can do this:

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
