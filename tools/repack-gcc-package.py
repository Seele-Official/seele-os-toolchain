#!/usr/bin/env python3
"""Turn a prebuilt riscv64-unknown-elf-gcc conda package into a clean,
GCC-only artifact for the local channel.

The historical artifact was built by a single-package conda-build recipe that
bundled the freestanding libstdc++ headers (and its own info/recipe, info/test
and info/hash_input.json).  The headers now live in the separate
riscv64-unknown-elf-libstdcxx package, so this tool:

  * drops the header tree and every info/files, info/paths.json and
    info/has_prefix entry that points into it,
  * drops info/recipe, info/test and info/hash_input.json,
  * rewrites info/about.json to describe what the package actually contains,
  * bumps the build number so the repackaged artifact is distinct from the
    original with the same name and version.

This is a one-off maintenance tool, not part of the normal channel build.
It needs conda-package-handling:

  pixi exec -s python -s conda-package-handling -- \
      python tools/repack-gcc-package.py <pkg.conda> <out-dir>

The dist-info of the produced package is printed together with its sha256, for
recording in vendor/SHA256SUMS.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import tempfile
from pathlib import Path

from conda_package_handling.api import create, extract


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def filter_lines(path: Path, prefixes: tuple[str, ...]) -> None:
    kept = [
        line
        for line in path.read_text().splitlines()
        if not any(line.split(" ")[-1].startswith(prefix) for prefix in prefixes)
    ]
    path.write_text("\n".join(kept) + "\n")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path, help="input .conda package")
    parser.add_argument("output_dir", type=Path, help="directory for the result")
    parser.add_argument(
        "--drop",
        action="append",
        default=[],
        help="payload prefix to remove (repeatable). Defaults to the libstdc++ headers",
    )
    parser.add_argument("--build-number", type=int, default=None)
    args = parser.parse_args(argv)

    src = args.package.resolve()
    if not src.is_file():
        parser.error(f"input package not found: {src}")

    drops = tuple(args.drop) or ("riscv64-unknown-elf/include/c++/",)
    source_sha256 = sha256(src)

    args.output_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="seele-gcc-repack-") as tmp:
        root = Path(tmp) / "root"
        extract(str(src), str(root))

        index_path = root / "info/index.json"
        index = json.loads(index_path.read_text())

        # Payload.
        for prefix in drops:
            target = root / prefix
            if target.is_dir():
                shutil.rmtree(target)
            elif target.exists():
                target.unlink()

        # Metadata that lists payload files.
        for name in ("files", "has_prefix"):
            meta = root / "info" / name
            if meta.exists():
                filter_lines(meta, drops)

        paths_path = root / "info/paths.json"
        if paths_path.exists():
            paths = json.loads(paths_path.read_text())
            paths["paths"] = [
                entry
                for entry in paths["paths"]
                if not entry["_path"].startswith(drops)
            ]
            paths_path.write_text(json.dumps(paths, indent=2) + "\n")

        # Stale provenance from the old single-package build.
        for name in ("recipe", "test", "hash_input.json"):
            target = root / "info" / name
            if target.is_dir():
                shutil.rmtree(target)
            elif target.exists():
                target.unlink()

        # Distinct build so the repackaged artifact cannot be confused with the
        # original one in a package cache.
        build_number = args.build_number
        if build_number is None:
            build_number = index["build_number"] + 1
        index["build_number"] = build_number
        index["build"] = f"{index['build'].rsplit('_', 1)[0]}_{build_number}"
        index_path.write_text(json.dumps(index, indent=2) + "\n")

        about_path = root / "info/about.json"
        about = json.loads(about_path.read_text()) if about_path.exists() else {}
        about["summary"] = "GCC 16 C/C++ cross compiler for riscv64-unknown-elf"
        about["description"] = (
            "A freestanding GCC 16.2.0 C/C++ cross compiler for the "
            "riscv64-unknown-elf target, bundled with GNU binutils 2.47.\n\n"
            "It installs libgcc (compiler helpers such as __divti3) and the "
            "compiler and binutils binaries. It does not install a C library, "
            "libstdc++.a, libsupc++, libatomic or libgcov. The freestanding "
            "libstdc++ headers are provided by the separate "
            "riscv64-unknown-elf-libstdcxx package.\n\n"
            f"Repackaged from {src.name} "
            f"(sha256 {source_sha256}) to drop the bundled libstdc++ headers "
            "and the stale conda-build metadata.\n"
        )
        about["repackaged_from"] = {
            "filename": src.name,
            "sha256": source_sha256,
            "dropped_prefixes": list(drops),
        }
        about_path.write_text(json.dumps(about, indent=2) + "\n")

        file_list = sorted(
            str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()
        )
        out_name = f"{index['name']}-{index['version']}-{index['build']}.conda"
        out = args.output_dir / out_name
        create(str(root), file_list, out_name, str(args.output_dir))

    print(out)
    print(f"sha256 {sha256(out)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
