#!/usr/bin/env bash
# build.sh - restore, build and run the macOS HaloScript compile driver in one command.
#
#   ./build.sh --hsc ../../src/hsc/fe_reinforcements.hsc \
#              --xml ../hsc/tables/reachmcc_u13.xml \
#              --build "Jun 21 2023 15:35:31"
#
#   ./build.sh --help          # driver usage
#   ./build.sh --build-only    # just compile the driver
#
# Everything after the options below is passed straight to the driver.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------- dependency
# Blamite comes from Jestzer/Assembly-CrossPlatform (GPL-3.0, branch dev), the
# net8.0 / Avalonia fork of Assembly. Override the checkout with ACP_DIR.
DEFAULT_EXTERNAL="$HERE/.external/Assembly-CrossPlatform"
if [[ -n "${ACP_DIR:-}" ]]; then
  :
elif [[ -d /tmp/acp_test/Assembly-CrossPlatform/src/Blamite ]]; then
  ACP_DIR=/tmp/acp_test/Assembly-CrossPlatform
else
  ACP_DIR="$DEFAULT_EXTERNAL"
fi

if [[ ! -d "$ACP_DIR/src/Blamite" ]]; then
  echo "== cloning Assembly-CrossPlatform into $ACP_DIR"
  mkdir -p "$(dirname "$ACP_DIR")"
  git clone --depth 1 -b dev https://github.com/Jestzer/Assembly-CrossPlatform.git "$ACP_DIR"
fi

BLAMITE_CSPROJ="$ACP_DIR/src/Blamite/Blamite.csproj"
export BLAMITE_FORMATS="$ACP_DIR/src/Blamite/Formats"

# ------------------------------------------------------- known upstream defect
# Blamite.csproj copies   <None Include="Formats\**\*" ... />   with a Windows
# separator and no <Link>. On macOS the whole Formats tree is FLATTENED into the
# output directory, so Formats/MapInfo/Engines.xml lands on top of the real
# Formats/Engines.xml and the layout loader dies with
#   "A(n) engine element is missing the required build attribute".
# Adding the Link metadata preserves the tree. Idempotent.
if ! grep -q 'RecursiveDir' "$BLAMITE_CSPROJ"; then
  echo "== patching $BLAMITE_CSPROJ (Formats path flattening on non-Windows)"
  python3 - "$BLAMITE_CSPROJ" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8-sig").read()
old = '<None Include="Formats\\**\\*" CopyToOutputDirectory="PreserveNewest" />'
new = ('<None Include="Formats/**/*" CopyToOutputDirectory="PreserveNewest" '
       'Link="Formats/%(RecursiveDir)%(Filename)%(Extension)" />')
if old not in s:
    sys.exit("expected Formats item not found; patch by hand")
open(p, "w", encoding="utf-8").write(s.replace(old, new))
PY
fi

# ---------------------------------------------------------------- toolchain
if ! command -v dotnet >/dev/null 2>&1; then
  echo "dotnet not found. Install it:  brew install dotnet" >&2
  exit 127
fi
# Homebrew ships .NET 11; these projects target net8.0.
export DOTNET_ROLL_FORWARD="${DOTNET_ROLL_FORWARD:-LatestMajor}"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

BUILD_ONLY=0
ARGS=()
for a in "$@"; do
  if [[ "$a" == "--build-only" ]]; then BUILD_ONLY=1; else ARGS+=("$a"); fi
done

LOG="$HERE/build.log"
echo "== building hsc-compile (log: $LOG)"
if ! dotnet build "$HERE/HscCompile.csproj" -c Release \
      -p:BlamiteProject="$BLAMITE_CSPROJ" >"$LOG" 2>&1; then
  echo "BUILD FAILED. Last 40 lines of $LOG:" >&2
  tail -n 40 "$LOG" >&2
  exit 1
fi
grep -E "Warning\(s\)|Error\(s\)|Elapsed" "$LOG" | sed 's/^/   /' || true

DLL="$HERE/bin/Release/net8.0/hsc-compile.dll"
[[ -f "$DLL" ]] || { echo "built, but $DLL is missing" >&2; exit 1; }

if [[ "$BUILD_ONLY" == "1" ]]; then
  echo "== built: $DLL"
  exit 0
fi

echo "== running"
# The driver chdir's to the directory holding Formats itself, after making every
# path argument absolute: the database paths inside Engines.xml are relative to
# the process working directory.
exec dotnet "$DLL" --formats "$BLAMITE_FORMATS" "${ARGS[@]}"
