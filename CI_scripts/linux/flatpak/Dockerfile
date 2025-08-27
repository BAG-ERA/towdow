FROM ubuntu:latest

ARG FLATPAK_RUNTIME_VERSION
ENV FLATPAK_RUNTIME_VERSION=$FLATPAK_RUNTIME_VERSION

RUN apt-get update
RUN apt-get install -y flatpak flatpak-builder ostree ca-certificates xz-utils
RUN mkdir -p .flatpak .flatpak-builder build-dir repo export build-logs
RUN flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
RUN flatpak install -y flathub org.gnome.Platform//$FLATPAK_RUNTIME_VERSION org.gnome.Sdk//$FLATPAK_RUNTIME_VERSION


CMD ["top", "-b"]