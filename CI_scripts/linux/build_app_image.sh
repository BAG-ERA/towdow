
APP_DIR=appdir_towdow
APP_NAME=towdow_app
ARCH=x86_64
APP_IMAGE_TOOL=appimagetool-${ARCH}.AppImage
APPIMAGE_OUTPUT=${3-build/linux/x64/release/${APP_NAME}.AppImage}

rm -rf ${APP_DIR}
mkdir -p ${APP_DIR}

echo "getting appimagetool"

#curl -L -o ${APP_IMAGE_TOOL} "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${ARCH}.AppImage"
#chmod +x ${APP_IMAGE_TOOL}

echo "building app"
flutter pub get
flutter build linux --release --build-name="$1" --build-number="$2"

echo "preparing AppDir ${APP_DIR}"
cp -r build/linux/x64/release/bundle/* ${APP_DIR}/
mv ${APP_DIR}/${APP_NAME} ${APP_DIR}/AppRun

echo "[Desktop Entry]
Type=Application
Name=${APP_NAME}
Comment=The next big thing
Icon=icon
Categories=Utility
" > ${APP_DIR}/towdow_app.desktop

cp assets/icons/logo/Flow-it_Default.png ${APP_DIR}/icon.png

echo "create app image"
./"$(dirname "$0")"/"${APP_IMAGE_TOOL}" "${APP_DIR}" "${APPIMAGE_OUTPUT}"

ls -l "${APPIMAGE_OUTPUT}"

echo "done"