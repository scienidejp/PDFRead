# ReadPDF releases

Releases are built by `.github/workflows/release.yml`. Push a version tag such as `v0.8.0` to
build the Linux and Windows installers and publish them as a GitHub Release. Running the workflow
manually builds downloadable CI artifacts without publishing a release.

The workspace version is defined in `[workspace.package]` in the root `Cargo.toml`. Update it and
`Cargo.lock`, commit the change, then push a matching `v<version>` tag.

## Artifacts

| Platform | Files | Install |
|---|---|---|
| Ubuntu/Debian x86_64 | `readpdf-<version>-linux-x86_64.deb` | `sudo apt install ./readpdf-<version>-linux-x86_64.deb` |
| Arch/CachyOS x86_64 | `readpdf-<version>-1-x86_64.pkg.tar.zst` | `sudo pacman -U ./readpdf-<version>-1-x86_64.pkg.tar.zst` |
| Linux x86_64 | `readpdf-<version>-linux-x86_64.AppImage` (optional `.zsync`) | `chmod +x` the file, then run it |
| Windows x64 | `readpdf-<version>-windows-x64-setup.exe` | Run setup and follow the installer |

The Linux packages are built on Ubuntu 22.04 and include OCR models and their licence notices.
The Windows setup is built on a Windows MSVC runner with Inno Setup; it includes the app, OCR
models, and applicable project and asset notices. It is not code-signed, so Windows may show a
SmartScreen warning.

## Build locally

Linux requires Rust, the system development libraries used by egui/winit, `dpkg-deb`, `zstd`,
`curl`, and internet access for the AppImage tool and OCR models:

```sh
packaging/linux/readpdf-package.sh
```

The script writes the `.deb`, Arch package, and AppImage to `dist/release/`.

Windows requires the Rust MSVC toolchain, Inno Setup 6, `cargo`, and internet access for OCR
models:

```powershell
pwsh packaging/windows/readpdf-package.ps1
```

The Windows setup is written to `dist/release/`.

## Licensing and provenance

ReadPDF is based on PdfCraft. Keep the upstream project licences, copyright notices, model
attributions, and asset licences with the source and any distributed packages. The release
packagers stage the notices required by the files they ship.
