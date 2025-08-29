rm -rf repo build-dir .flatpak-builder
flatpak-builder \
  --force-clean \
  --repo=repo \
  --default-branch=stable \
  --mirror-screenshots-url=https://dl.flathub.org/media/ \
  build-dir \
  app.towdow.TowDow.yaml || exit $?
# Finalize repo (appstream compose + deltas)
flatpak build-update-repo --generate-static-deltas repo  || exit $?
flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo || exit $?
