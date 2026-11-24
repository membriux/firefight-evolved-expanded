#!/usr/bin/env python3
"""
unpatch_map.py -- undo a change set written by ``patch_map.py``.

    python3 tools/patch/unpatch_map.py CHANGESET.json              # dry run
    python3 tools/patch/unpatch_map.py CHANGESET.json --apply
    python3 tools/patch/unpatch_map.py CHANGESET.json --target moved.map --out back.map --apply

It is the same code path as ``patch_map.py --revert``; this is a separate entry
point so an unpatch never needs the map, the definitions or the scanner.

Guarantees, all of them tested against synthetic fixtures:
  * refuses unless the target file's sha256 is exactly what the manifest
    recorded for the patched output;
  * refuses unless every byte the manifest claims to have written is still there;
  * restores the header checksum field verbatim, so the result is byte-identical
    to the original input -- and says so by comparing sha256 with the manifest;
  * refuses to write a result that does not re-parse;
  * dry run by default, backs up anything it would overwrite.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import patch_map as pm          # noqa: E402


def main(argv=None):
    ap = argparse.ArgumentParser(
        prog="unpatch_map.py",
        description="Undo a patch_map.py change set from its JSON manifest.")
    ap.add_argument("manifest", help="the .patch.json change set")
    ap.add_argument("--target", help="the patched map, if it is not where the manifest says")
    ap.add_argument("--out", help="where to write the restored map "
                                  "(default: <target>.reverted)")
    ap.add_argument("--apply", action="store_true", help="actually write (default: dry run)")
    args = ap.parse_args(argv)
    ns = argparse.Namespace(revert=args.manifest, target=args.target, out=args.out,
                            apply=args.apply)
    try:
        return pm.cmd_revert(ns)
    except pm.ManifestError as exc:
        print("MANIFEST ERROR: %s" % exc, file=sys.stderr)
        return pm.EXIT_MANIFEST
    except pm.PatchError as exc:
        print("ERROR: %s" % exc, file=sys.stderr)
        return pm.EXIT_USAGE


if __name__ == "__main__":
    sys.exit(main())
