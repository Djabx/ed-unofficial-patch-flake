#!/usr/bin/env bash
# Installs ED-UP's d3d11.dll in front of any other d3d11 mod (EDCAS, EDHM, ...).
# The other mod's d3d11.dll is renamed and ED-UP chains to it via advanced.real_dll.
set -euo pipefail

share=@share@
chain=d3d11_edca.dll
game_dir=${ED_GAME_DIR:-}
action=install

usage() {
  cat <<USAGE
Usage: ed-up-install [--game-dir DIR] [--chain-name NAME] [--uninstall]

  --game-dir DIR     folder holding EliteDangerous64.exe (or env ED_GAME_DIR);
                     autodetected (Steam libraries, Heroic/Lutris/Bottles) when omitted
  --chain-name NAME  name given to the other mod's d3d11.dll (default: $chain)
  --uninstall        remove ED-UP and put the chained d3d11.dll back
USAGE
}

while [ $# -gt 0 ]; do
  case $1 in
    --game-dir) game_dir=$2; shift 2 ;;
    --chain-name) chain=$2; shift 2 ;;
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
      [ -n "$dir" ] && found=$(find_exe "$lib/steamapps/common/$dir" 4) || found=
      [ -n "${found:-}" ] && { dirname "$found"; return 0; }
    fi
    found=$(find_exe "$lib/steamapps/common" 4)
    [ -n "$found" ] && { dirname "$found"; return 0; }
  done < <(printf '%s\n' "${libs[@]}" | xargs -r -d '\n' -n1 realpath -m 2>/dev/null | awk '!seen[$0]++')
  # Heroic, Lutris and Bottles prefixes
  for prefix in "$HOME"/Games/*/ "$HOME"/Games/Heroic/Prefixes/*/ \
    "$HOME"/.local/share/bottles/bottles/*/ \
    "$HOME"/.var/app/com.usebottles.bottles/data/bottles/bottles/*/; do
    [ -d "$prefix" ] || continue
    found=$(find_exe "$prefix" 9)
    [ -n "$found" ] && { dirname "$found"; return 0; }
  done
  return 1
}

if [ -z "$game_dir" ]; then
  game_dir=$(detect_game_dir || true)
fi
[ -f "${game_dir:-}/EliteDangerous64.exe" ] || { echo "ED-UP: EliteDangerous64.exe not found; use --game-dir" >&2; exit 1; }
cd "$game_dir"

is_edup() { grep -qa 'edvr\.ini' "$1"; }

set_real_dll() { # $1 = value
  sed -i "s/^real_dll *=.*/real_dll = $1/" edvr.ini
}

if [ "$action" = uninstall ]; then
  if [ -f d3d11.dll ] && is_edup d3d11.dll; then rm -f d3d11.dll; fi
  if [ -f "$chain" ] && [ ! -e d3d11.dll ]; then mv "$chain" d3d11.dll; fi
  echo "ED-UP removed; edvr.ini kept."
  exit 0
fi

if [ -f d3d11.dll ] && ! is_edup d3d11.dll; then
  if [ -e "$chain" ]; then
    echo "ED-UP: $chain already exists next to a foreign d3d11.dll; resolve by hand" >&2
    exit 1
  fi
  echo "Renaming the other mod's d3d11.dll to $chain"
  mv d3d11.dll "$chain"
fi

install -m644 "$share/d3d11.dll" d3d11.dll
for f in edvr.ini edvr-flat.ini edvr_profile.ini; do
  [ -e "$f" ] || install -m644 "$share/$f" "$f"
done

if [ -e "$chain" ]; then
  set_real_dll "$chain"
  echo "Chained: ED-UP -> $chain -> system d3d11"
else
  set_real_dll ""
fi

cat <<MSG
ED-UP installed in $game_dir
Steam launch option (Proton):
  WINEDLLOVERRIDES="d3d11,d3dcompiler_47,nvapi64=n,b" %command%
MSG
