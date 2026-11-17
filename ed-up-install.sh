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
                     autodetected for Steam when omitted
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

if [ -z "$game_dir" ]; then
  for steam in "$HOME/.local/share/Steam" "$HOME/.steam/steam" \
    "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
    found=$(find "$steam/steamapps/common" -maxdepth 4 -name EliteDangerous64.exe 2>/dev/null | head -n1 || true)
    [ -n "$found" ] && { game_dir=$(dirname "$found"); break; }
  done
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
