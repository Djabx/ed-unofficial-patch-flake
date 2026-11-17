# ED-UP Nix Flake

Nix packaging for **[ED Unofficial Patch](https://github.com/characterecho-sean/ed-unofficial-patch)**
(DLSS / FSR / XeSS for Elite Dangerous: Odyssey). ED-UP is a Windows binary built
with Visual Studio, so this flake packages the upstream release (`ed-up-core-<version>.zip`)
and provides `ed-up-install`, which places the files in the game folder.
A daily CI job bumps the version and hash from the latest upstream release.

## Usage

```sh
nix run github:Djabx/ed-unofficial-patch-flake -- --game-dir /path/to/Products/elite-dangerous-odyssey-64
```

Without `--game-dir`, the game folder is autodetected like ED-Outrider does: every Steam library listed in `libraryfolders.vdf` (native, `~/.steam`, Flatpak, snap; non-standard libraries included), then Heroic/Lutris/Bottles prefixes. Other options:
`--chain-name NAME` (default `d3d11_edca.dll`) and `--uninstall`.
Run it with Elite closed, then set the Steam launch option:

```
WINEDLLOVERRIDES="d3d11,d3dcompiler_47,nvapi64=n,b" %command%
```

VR files (`openvr/`) and the DLSS/XeSS runtimes (separate release archives) are not installed.

## Running alongside 3DMigoto mods (EDCAS, EDHM)

ED-UP and 3DMigoto-based mods (EDCAS, EDHM) both use a `d3d11.dll`. ED-UP chains to
another DLL through `real_dll` in `edvr.ini`. `ed-up-install` handles this chain:
it backs up any existing 3DMigoto `d3d11.dll` to `d3d11_3dmigoto.dll`, installs ED-UP's as
`d3d11.dll`, and sets `real_dll = d3d11_3dmigoto.dll`.

Chain: game → ED-UP (`d3d11.dll`) → 3DMigoto (`d3d11_3dmigoto.dll`) → system DXVK (`d3d11.dll`).

To ensure the chain is always intact before launch (even if EDCAS or EDHM-UI restored
its own files), invoke `ed-up-install -q` in your launch options (Steam or MinEdLauncher):

```sh
sh -c 'ed-up-install -q; MinEdLauncher "$@" /autorun /autoquit' -- %command%
```
