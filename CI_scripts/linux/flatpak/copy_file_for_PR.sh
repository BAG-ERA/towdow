flathub_repo_dir=${1-/home/maxime/work/external_repos/flathub}
VERSION=${2-"1.0.0"}
echo copying files to $flathub_repo_dir for version $VERSION
cp app.towdow.TowDow.yaml "${flathub_repo_dir}/"
cp app.towdow.TowDow.yaml "${flathub_repo_dir}/"
mkdir -p "${flathub_repo_dir}/build/linux/x64/release"
cp "build/linux/x64/release/towdow_app-$VERSION.AppImage" "${flathub_repo_dir}/build/linux/x64/release/"
mkdir -p "${flathub_repo_dir}/CI_scripts/linux/flatpak/data/"
cp -r CI_scripts/linux/flatpak/data/icons "${flathub_repo_dir}/CI_scripts/linux/flatpak/data/"
cp -r CI_scripts/linux/flatpak/data/app.towdow.TowDow.desktop "${flathub_repo_dir}/CI_scripts/linux/flatpak/data/"
cp -r CI_scripts/linux/flatpak/data/app.towdow.TowDow.metainfo.xml "${flathub_repo_dir}/CI_scripts/linux/flatpak/data/"

# update version in files
echo "update version number"
sed -i "s/0\.0\.0/${VERSION}/g" "${flathub_repo_dir}/app.towdow.TowDow.yaml"
sed -i "s/0\.0\.0/${VERSION}/g" "${flathub_repo_dir}/CI_scripts/linux/flatpak/data/app.towdow.TowDow.metainfo.xml"

echo "done"