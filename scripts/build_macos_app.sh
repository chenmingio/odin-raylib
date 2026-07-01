#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_name="OdinRaylib"
app_dir="$root_dir/build/$app_name.app"

should_build=0
should_open=0

for arg in "$@"; do
  case "$arg" in
    --build)
      should_build=1
      ;;
    --open)
      should_open=1
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [--build] [--open]" >&2
      exit 2
      ;;
  esac
done

if [[ "$should_build" -eq 1 ]]; then
  mkdir -p "$root_dir/build"
  odin build "$root_dir" -debug -out:"$root_dir/build/game" -o:none
  odin build "$root_dir/game" -out:"$root_dir/build/game-lib.dylib" -o:none -debug -build-mode:shared
fi

mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$root_dir/macos/Info.plist" "$app_dir/Contents/Info.plist"
cp "$root_dir/macos/odin-raylib-launcher" "$app_dir/Contents/MacOS/odin-raylib-launcher"
chmod +x "$app_dir/Contents/MacOS/odin-raylib-launcher"

echo "Updated $app_dir"

if [[ "$should_open" -eq 1 ]]; then
  open "$app_dir"
fi
