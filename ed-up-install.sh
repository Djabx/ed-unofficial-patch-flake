#!/usr/bin/env bash
# Installs ED-UP's d3d11.dll in front of any other d3d11 mod (EDCAS, EDHM, ...).
# The other mod's d3d11.dll is backed up to d3d11_3dmigoto.dll and ED-UP chains to it via advanced.real_dll.
set -euo pipefail

share=@share@
chain=d3d11_3dmigoto.dll
game_dir=${ED_GAME_DIR:-}
action=install
quiet=0

usage() {
  cat <<USAGE
Usage: ed-up-install [--game-dir DIR] [--chain-name NAME] [--quiet|-q] [--uninstall]

  --game-dir DIR     folder holding EliteDangerous64.exe (or env ED_GAME_DIR);
                     autodetected (Steam libraries, Heroic/Lutris/Bottles) when omitted
  --chain-name NAME  name given to the other mod's d3d11.dll (default: $chain)
  --quiet, -q        suppress normal output (suitable for pre-launch scripts)
  --uninstall        remove ED-UP and put the chained d3d11.dll back
USAGE
}

while [ $# -gt 0 ]; do
  case $1 in
    --game-dir) game_dir=$2; shift 2 ;;
    --chain-name) chain=$2; shift 2 ;;
    -q|--quiet) quiet=1; shift ;;
    --uninstall) action=uninstall; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

# Same discovery as ED-Outrider: every Steam library listed in libraryfolders.vdf
# (the native, ~/.steam, Flatpak and snap Steams), so games installed on another
# drive or a non-standard library are found, then Heroic/Lutris/Bottles prefixes.
find_exe() { # $1 = folder, $2 = max depth
  find "$1" -maxdepth "$2" -name EliteDangerous64.exe 2>/dev/null | head -n1 || true
}

detect_game_dir() {
  local roots=() libs=() steam vdf lib found manifest dir prefix
  roots=("$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.steam/root" \
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" \
    "$HOME/snap/steam/common/.local/share/Steam")
  for steam in "${roots[@]}"; do
    vdf=$steam/steamapps/libraryfolders.vdf
    if [ -r "$vdf" ]; then
      while IFS= read -r lib; do libs+=("${lib//\\\\//}"); done < <(
        sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$vdf")
    fi
    libs+=("$steam")
  done
  while IFS= read -r lib; do
    [ -d "$lib/steamapps" ] || continue
    # Elite's Steam app id is 359320: its manifest names the install folder
    manifest=$lib/steamapps/appmanifest_359320.acf
    if [ -r "$manifest" ]; then
      dir=$(sed -n 's/^[[:space:]]*"installdir"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$manifest" | head -n1)
      [ -n "$dir" ] && found=`find_exe "$lib/steamapps/common/$dir" 4` || found=
      [ -n "${found:-}" ] && { dirname "$found"; return 0; }
    fi
    found=`find_exe "$lib/steamapps/common" 4`
    [ -n "$found" ] && { dirname "$found"; return 0; }
  done < <(printf '%s\n' "${libs[@]}" | xargs -r -d '\n' -n1 realpath -m 2>/dev/null | awk '!seen[$0]++')
  # Heroic, Lutris and Bottles prefixes
  for prefix in "$HOME"/Games/*/ "$HOME"/Games/Heroic/Prefixes/*/ \
    "$HOME"/.local/share/bottles/bottles/*/ \
    "$HOME"/.var/app/com.usebottles.bottles/data/bottles/bottles/*/; do
    [ -d "$prefix" ] || continue
    found=`find_exe "$prefix" 9`
    [ -n "$found" ] && { dirname "$found"; return 0; }
  done
  return 1
}

if [ -z "$game_dir" ]; then
  game_dir=`detect_game_dir || true`
fi
[ -f "${game_dir:-}/EliteDangerous64.exe" ] || { echo "ED-UP: EliteDangerous64.exe not found; use --game-dir" >&2; exit 1; }
cd "$game_dir"

is_edup() { grep -qa 'edvr\.ini' "$1"; }

set_real_dll() { # $1 = value
  if [ -f edvr.ini ]; then
    sed -i "s/^real_dll *=.*/real_dll = $1/" edvr.ini
  fi
}

# Migrate legacy chain name if present
if [ "$chain" = "d3d11_3dmigoto.dll" ] && [ -f "d3d11_edca.dll" ] && [ ! -f "$chain" ]; then
  mv d3d11_edca.dll "$chain"
fi

if [ "$action" = uninstall ]; then
  if [ -f d3d11.dll ] && is_edup d3d11.dll; then rm -f d3d11.dll; fi
  if [ -f "$chain" ] && [ ! -e d3d11.dll ]; then mv "$chain" d3d11.dll; fi
  [ "$quiet" = 1 ] || echo "ED-UP removed; $chain restored as d3d11.dll (if present)."
  exit 0
fi

# Quick check: already installed, configured and intact
if [ "$quiet" = 1 ] && [ -f d3d11.dll ] && is_edup d3d11.dll && [ -f edvr.ini ]; then
  if [ -f "$chain" ]; then
    set_real_dll "$chain"
  fi
  exit 0
fi

if [ -f d3d11.dll ] && ! is_edup d3d11.dll; then
  [ "$quiet" = 1 ] || echo "Saving existing 3DMigoto d3d11.dll as $chain"
  cp -a d3d11.dll "$chain"
fi

# If chain is missing but an EDCAS backup exists, adopt it as chain
if [ ! -f "$chain" ]; then
  for backup in d3d11.dll.edcas d3d11.dll.official; do
    if [ -f "$backup" ]; then
      [ "$quiet" = 1 ] || echo "Using $backup as initial $chain"
      cp -a "$backup" "$chain"
      break
    fi
  done
fi

install -m644 "$share/d3d11.dll" d3d11.dll
for f in edvr.ini edvr-flat.ini edvr_profile.ini; do
  [ -e "$f" ] || install -m644 "$share/$f" "$f"
done

if [ -e "$chain" ]; then
  set_real_dll "$chain"
  [ "$quiet" = 1 ] || echo "Chained: ED-UP -> $chain -> system d3d11"
else
  set_real_dll ""
fi

if [ "$quiet" = 0 ]; then
  cat <<MSG
ED-UP installed in $game_dir
Launch command (e.g. Steam or MinEdLauncher):
  sh -c 'ed-up-install -q; MinEdLauncher "$@" /autorun /autoquit' -- %command%
MSG
fi
