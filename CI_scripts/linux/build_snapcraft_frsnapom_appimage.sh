echo "building $CI_COMMIT_TAG version for snapcraft"
sed -i "s/0\.0\.0/${CI_COMMIT_TAG}/g" snapcraft.yaml
ls
cp build/linux/x64/release/towdow_app-$CI_COMMIT_TAG.AppImage towdow_app-$CI_COMMIT_TAG.AppImage
echo "copied AppImage at root level:"
ls
snapcraft pack