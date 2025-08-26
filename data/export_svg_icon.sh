

# transparent PNGs, square; adjust the source path to your SVG
for s in 64 128 256; do
  mkdir -p "data/icons/hicolor/${s}x${s}/apps/"
  inkscape assets/icons/logo/Flow-it_icon-Default.svg \
    --export-type=png \
    --export-filename="data/icons/hicolor/${s}x${s}/apps/app.towdow.TowDow.png" \
    -w $s -h $s
done
