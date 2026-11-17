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

## Running alongside EDCAS (or EDHM)

ED-UP and EDCAS both ship a 3DMigoto-style `d3d11.dll`. ED-UP can chain to another
DLL through `advanced.real_dll` in `edvr.ini`. `ed-up-install` does this for you:
it renames the other mod's `d3d11.dll` to `d3d11_edca.dll`, installs ED-UP's as
`d3d11.dll` and sets `real_dll`. Chain: game → ED-UP → 3DMigoto → system d3d11.

So that EDCAS's own installer does not overwrite ED-UP, build it under the chained name
with [edca-flake](https://github.com/Djabx/edca-flake)'s `dllName` parameter:

```nix
environment.systemPackages = [
  (edcas.packages.${system}.default.override { dllName = "d3d11_edca.dll"; })
  ed-up.packages.${system}.default
];
```

Then run `ed-up-install` once.
