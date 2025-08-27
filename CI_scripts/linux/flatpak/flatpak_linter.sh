flatpak-builder --force-clean build-dir app.towdow.TowDow.yaml \
--default-branch=stable \
--mirror-screenshots-url=https://dl.flathub.org/media/ || exit $?
flatpak build build-dir appstreamcli validate /app/share/metainfo/app.towdow.TowDow.metainfo.xml  || exit $?
flatpak build-export --update-appstream repo build-dir || exit $?
flatpak build-update-repo --generate-static-deltas repo || exit $?
flatpak run --command=flatpak-builder-lint org.flatpak.Builder repo repo || exit $?
