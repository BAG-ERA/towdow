# Flatpak deployment

## initial setup

Build the  [app.towdow.TowDow.yml](app.towdow.TowDow/app.towdow.TowDow.yml) file from https://github.com/TheAppgineer/flatpak-flutter

```shell
cd CI_scripts/linux/flatpak/
cd app.towdow.TowDow/
docker run --rm -v "$PWD":/usr/src/flatpak -u `id -u`:`id -g` theappgineer/flatpak-flutter:latest flatpak-flutter.yml
```

This  will generate the flatpak file [app.towdow.TowDow.yml](app.towdow.TowDow/app.towdow.TowDow.yml) with the commit id in [flatpak-flutter.yml](app.towdow.TowDow/flatpak-flutter.yml).

It will also generate other files required to build flutter app for flatpack
* [flutter-sdk-3.35.3.json](app.towdow.TowDow/flutter-sdk-3.35.3.json)
* [package_config.json](app.towdow.TowDow/package_config.json)
* [pubspec-sources.json](app.towdow.TowDow/pubspec-sources.json)

You need to update the commit id if you want to regenerate these files.

## Building the app

1. set CI_COMMIT_TAG and CI_COMMIT_SHA variables
2. run CI script to build repo
   ```shell
   bash CI_scripts/linux/flatpak/build_flatpak_ci.sh $CI_COMMIT_TAG $CI_COMMIT_SHA
   ```
3. create flatpak file
   ```
   flatpak build-bundle repo towdow.$CI_COMMIT_TAG.flatpak app.towdow.TowDow master
   ```
## deploying to flatpak 

1. build the flatpak repo (see above)
2. run the linter
   ```shell
   flatpak install flathub org.flatpak.Builder -y
   flatpak run --command=flatpak-builder-lint org.flatpak.Builder manifest "${SCRIPT_DIR}/app.towdow.TowDow/app.towdow.TowDow.yml"  || exit $?
   ```
3. run script to update flathub repo 
   ```
   bash CI_scripts/linux/flatpak/copy_file_for_PR.sh --flathub-repo __PATH_TO_FLATHUB_REPO__ --version $CI_COMMIT_TAG --commit-id $CI_COMMIT_SHA
   # ex for maxime PC:
   bash CI_scripts/linux/flatpak/copy_file_for_PR.sh --flathub-repo ~/work/external_repos/flathub/ --version $CI_COMMIT_TAG --commit-id $CI_COMMIT_SHA
   ```
4. create a new Pull Request or push to existing PR


## Troubleshooting

### Missing Dependencies
Install required Flatpak tools:
```bash
# Ubuntu/Debian
sudo apt install flatpak flatpak-builder

# Fedora
sudo dnf install flatpak flatpak-builder
```

### Repository Issues
If repository becomes corrupted:
```bash
rm -rf repo flatpak-repo
# Scripts will recreate with proper structure
```
