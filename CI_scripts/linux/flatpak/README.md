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

```shell

```


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
