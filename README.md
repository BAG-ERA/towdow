# TowDow_app



## configuring CI

The CI is used to build and release the app.
It uses custom docker images to build configured to build for Linux and Android.
These images will be created / updated automatically when a change is pushed to the default branch.

If you want to manually build the image you can do this:

```shell
docker login registry.gitlab.com/towdow/towdow-flutter
docker build --build-arg FLUTTER_VERSION=3.32.5  --build-arg ANDROID_TOOL_VERSION_X=34 --build-arg ANDROID_TOOL_VERSION=34.0.0 -t registry.gitlab.com/towdow/towdow-flutter/flutter-build-env:3.32.5 .
```
