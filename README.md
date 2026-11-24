# seele-toolchain

Source recipes for the public `riscv64-unknown-elf` freestanding GCC conda channel hosted at <https://prefix.dev/seele-official/seele-os-toolchain>.

Built for bare-metal RISC-V 64-bit C/C++ kernels and freestanding targets.

## Packages

| Package                         | Version | Contents                                           |
| ------------------------------- | ------- | -------------------------------------------------- |
| `riscv64-unknown-elf-gcc`       | 16.2.0  | GCC 16.2.0 (C/C++), GNU binutils 2.47, `libgcc.a`  |
| `riscv64-unknown-elf-libstdcxx` | 16.2.0  | Freestanding `libstdc++` headers (`_GLIBCXX_HOSTED=0`) |

Both packages target `-march=rv64gc -mabi=lp64d` (single multilib) by default. They intentionally do **not** ship a C library (no newlib), `libstdc++.a`, `libsupc++`, `libatomic`, or `libgcov`.

## Host Requirements

- `linux-64` host with glibc ≥ 2.28 (built against `conda-forge`'s `sysroot_linux-64 2.28` baseline)
- Pixi ≥ 0.84

## Usage

Consuming projects do not need to clone this repository. Add the public channel directly to `pixi.toml`:

```toml
[workspace]
channels = ["conda-forge", "https://prefix.dev/seele-official/seele-os-toolchain"]
platforms = ["linux-64"]

[dependencies]
riscv64-unknown-elf-gcc = "==16.2.0"
riscv64-unknown-elf-libstdcxx = "==16.2.0"
```

## Building From Source

All packages are built from upstream GNU release tarballs verified by SHA-256 into the local `dist/linux-64/` staging channel:

```bash
# Build both packages from scratch (~25–35 min total)
pixi run build

# Or build each package individually:
pixi run build-gcc        # GCC + binutils + libgcc (~20–30 min)
pixi run build-libstdcxx  # Headers only (~3–4 min; resolves GCC from dist/ or prefix.dev)

# Remove local build output
pixi run clean
```

To publish newly built packages (requires `pixi auth login https://prefix.dev`):

```bash
pixi run upload
```

See [docs/toolchain-packaging.md](docs/toolchain-packaging.md) for host ABI constraints, verification checks, and release guidelines.

## Repository Layout

```text
pixi.toml                                 # Build, index, and upload tasks
docs/toolchain-packaging.md               # Packaging architecture, ABI baseline, and release guide
recipes/riscv64-unknown-elf-gcc/          # Compiler, binutils, and libgcc recipe
recipes/riscv64-unknown-elf-libstdcxx/    # Freestanding libstdc++ headers recipe
```
