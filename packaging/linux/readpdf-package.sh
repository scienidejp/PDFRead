#!/usr/bin/env bash
set -euo pipefail
umask 022
. "$(dirname "${BASH_SOURCE[0]}")/../env.sh"

if [[ "$(uname -m)" != x86_64 && "$(uname -m)" != aarch64 ]]; then
  echo "Unsupported host architecture: $(uname -m)" >&2
  exit 2
fi
if ! command -v dpkg-deb >/dev/null || ! command -v zstd >/dev/null; then
  echo "Required tools: dpkg-deb and zstd." >&2
  exit 1
fi

ARCH="$(uname -m)"
DEB_ARCH=amd64
[[ "$ARCH" == aarch64 ]] && DEB_ARCH=arm64
mkdir -p "$CARGO_TARGET_DIR"
WORK="$(mktemp -d "$CARGO_TARGET_DIR/readpdf-package.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
ROOTDIR="$WORK/root"
mkdir -p "$ROOTDIR/usr/bin" "$ROOTDIR/usr/share/applications" "$ROOTDIR/usr/share/icons/hicolor/256x256/apps" \
  "$ROOTDIR/usr/share/icons/hicolor/scalable/apps" \
  "$ROOTDIR/usr/share/metainfo" "$ROOTDIR/usr/share/readpdf/models" \
  "$ROOTDIR/usr/share/doc/readpdf"

(cd "$ROOT" && cargo build --release --locked -j 2 -p pdfcraft)
install -m 0755 "$CARGO_TARGET_DIR/release/pdfcraft" "$ROOTDIR/usr/bin/readpdf"
install -m 0644 "$ROOT/packaging/linux/readpdf.desktop" "$ROOTDIR/usr/share/applications/org.readpdf.ReadPDF.desktop"
install -m 0644 "$ROOT/assets/app-icon/readpdf.png" "$ROOTDIR/usr/share/icons/hicolor/256x256/apps/org.readpdf.ReadPDF.png"
install -m 0644 "$ROOT/assets/app-icon/readpdf.svg" "$ROOTDIR/usr/share/icons/hicolor/scalable/apps/org.readpdf.ReadPDF.svg"
cat >"$ROOTDIR/usr/share/metainfo/org.readpdf.ReadPDF.metainfo.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>org.readpdf.ReadPDF</id>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>MIT OR Apache-2.0</project_license>
  <name>ReadPDF</name>
  <summary>Read, annotate, organize and edit PDF documents</summary>
  <developer id="org.readpdf"><name>ReadPDF contributors</name></developer>
  <description><p>ReadPDF is a personal PDF reader and editor derived from PdfCraft, with local-first tools for reading, annotating, organizing, and editing documents.</p></description>
  <launchable type="desktop-id">org.readpdf.ReadPDF.desktop</launchable>
  <icon type="stock">org.readpdf.ReadPDF</icon>
  <categories><category>Office</category><category>Viewer</category></categories>
  <provides><binary>readpdf</binary><mediatype>application/pdf</mediatype></provides>
  <releases><release version="$VERSION" date="$PDFCRAFT_BUILD_DATE"/></releases>
</component>
EOF
if command -v desktop-file-validate >/dev/null; then
  desktop-file-validate "$ROOTDIR/usr/share/applications/org.readpdf.ReadPDF.desktop"
fi
if command -v appstreamcli >/dev/null; then
  appstreamcli validate --no-net --explain --override url-homepage-missing=info \
    "$ROOTDIR/usr/share/metainfo/org.readpdf.ReadPDF.metainfo.xml"
fi

for f in LICENSE-MIT LICENSE-APACHE NOTICE ATTRIBUTION.toml; do
  [[ ! -f "$ROOT/$f" ]] || install -m 0644 "$ROOT/$f" "$ROOTDIR/usr/share/doc/readpdf/$f"
done
stage_models "$ROOTDIR/usr/share/readpdf/models"
install -m 0755 "$ROOT/packaging/linux/postinst.sh" "$WORK/postinst"
DEB_OUT="$DIST/readpdf-$VERSION-linux-$ARCH.deb"
PACMAN_OUT="$DIST/readpdf-$VERSION-1-$ARCH.pkg.tar.zst"
rm -f "$DEB_OUT" "$PACMAN_OUT"

DEB="$WORK/deb"
mkdir -p "$DEB/DEBIAN"
cat >"$DEB/DEBIAN/control" <<EOF
Package: readpdf
Version: $VERSION
Section: graphics
Priority: optional
Architecture: $DEB_ARCH
Maintainer: ReadPDF contributors
Depends: libc6 (>= 2.35), libgcc-s1, libxkbcommon0, libvulkan1 | libegl1
Recommends: cups-client, libwayland-client0, libx11-6, libx11-xcb1, libxcursor1, libxi6, libxrandr2, mesa-vulkan-drivers, xdg-desktop-portal
Description: Personal PDF reader and editor
 Read, annotate, organize and edit PDF documents.
EOF
install -m 0755 "$WORK/postinst" "$DEB/DEBIAN/postinst"
install -m 0755 "$WORK/postinst" "$DEB/DEBIAN/postrm"
cp -a "$ROOTDIR/." "$DEB/"
dpkg-deb --build --root-owner-group "$DEB" "$DEB_OUT"

PKGROOT="$WORK/pkg"
cp -a "$ROOTDIR/." "$PKGROOT/"
INSTALLED_SIZE="$(du -sb "$PKGROOT" | cut -f1)"
cat >"$PKGROOT/.INSTALL" <<'EOF'
post_install() {
  command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q /usr/share/applications || :
  command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || :
}
post_upgrade() { post_install; }
post_remove() { post_install; }
EOF
cat >"$PKGROOT/.PKGINFO" <<EOF
pkgname = readpdf
pkgbase = readpdf
pkgver = $VERSION-1
pkgdesc = Personal PDF reader and editor
builddate = $(date +%s)
packager = ReadPDF contributors
size = $INSTALLED_SIZE
arch = $ARCH
license = MIT
license = Apache
depend = glibc
depend = gcc-libs
depend = libxkbcommon
depend = vulkan-icd-loader
optdepend = cups: printing support
optdepend = xdg-desktop-portal: desktop integration
EOF
tar --sort=name --mtime="@${SOURCE_DATE_EPOCH:-0}" --owner=0 --group=0 --numeric-owner -C "$PKGROOT" -cf - . \
  | zstd -19 -T0 -o "$PACMAN_OUT"

APPDIR="$WORK/ReadPDF.AppDir"
mkdir -p "$APPDIR"
cp -a "$ROOTDIR/." "$APPDIR/"
cp "$ROOT/packaging/linux/readpdf.desktop" "$APPDIR/org.readpdf.ReadPDF.desktop"
cp "$ROOT/assets/app-icon/readpdf.png" "$APPDIR/org.readpdf.ReadPDF.png"
ln -s org.readpdf.ReadPDF.png "$APPDIR/.DirIcon"
cat >"$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/bin/readpdf" "$@"
EOF
chmod 0755 "$APPDIR/AppRun"

APPIMAGETOOL="${APPIMAGETOOL:-$(command -v appimagetool || true)}"
if [[ -z "$APPIMAGETOOL" ]]; then
  APPIMAGETOOL="$CARGO_TARGET_DIR/appimagetool-$ARCH.AppImage"
  if [[ ! -x "$APPIMAGETOOL" ]]; then
    curl -fsSL -o "$APPIMAGETOOL" \
      "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
    chmod 0755 "$APPIMAGETOOL"
  fi
fi
APPIMAGE_OUT="$DIST/readpdf-$VERSION-linux-$ARCH.AppImage"
UPDATE_INFO=()
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
  UPDATE_INFO=(-u "gh-releases-zsync|${GITHUB_REPOSITORY%%/*}|${GITHUB_REPOSITORY#*/}|latest|readpdf-*-linux-$ARCH.AppImage.zsync")
fi
APPDIR="$(cd "$APPDIR" && pwd)"
APPIMAGETOOL="$(cd "$(dirname "$APPIMAGETOOL")" && pwd)/$(basename "$APPIMAGETOOL")"
(cd "$DIST" && ARCH="$ARCH" APPIMAGE_EXTRACT_AND_RUN=1 \
  "$APPIMAGETOOL" --no-appstream "${UPDATE_INFO[@]}" "$APPDIR" "$APPIMAGE_OUT")

echo "Created:"
ls -lh "$DEB_OUT" "$PACMAN_OUT" "$APPIMAGE_OUT"
