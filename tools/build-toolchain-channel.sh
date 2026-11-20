#!/usr/bin/env bash
set -euo pipefail

# Assemble the local conda channel that provides the riscv64 cross toolchain.
#
# GCC comes from the pinned prebuilt package in vendor/: this script verifies
# vendor/SHA256SUMS, hardlinks that package into .channel/linux-64, builds and
# publishes the libstdc++ header package, and indexes the result with
# rattler-index.  The channel is indexed before the header package is published
# because that package's configure step resolves the cross compiler from it.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANNEL="${ROOT}/.channel"
LINUX64="${CHANNEL}/linux-64"
VENDOR="${ROOT}/vendor"
GCC_VERSION="16.2.0"

shopt -s nullglob
gcc_packages=("${VENDOR}/riscv64-unknown-elf-gcc-${GCC_VERSION}"-*.conda)
shopt -u nullglob

if [ "${#gcc_packages[@]}" -ne 1 ]; then
    cat >&2 <<EOF
error: expected exactly one prebuilt GCC package in ${VENDOR}, found ${#gcc_packages[@]}

Put riscv64-unknown-elf-gcc-${GCC_VERSION}-<build>.conda in ${VENDOR} and record
it in ${VENDOR}/SHA256SUMS.  See vendor/README.md.

Given the original single-package conda-build artifact, create it with:
  pixi exec -s python -s conda-package-handling -- \\
      python tools/repack-gcc-package.py <pkg.conda> ${VENDOR}
EOF
    exit 1
fi

(cd "${VENDOR}" && sha256sum --quiet -c SHA256SUMS)

rm -rf "${CHANNEL}"
mkdir -p "${LINUX64}"
# Hardlink when the channel is on the same filesystem: the package is 110 MB
# and nothing ever modifies it in place.
ln -f "${gcc_packages[0]}" "${LINUX64}/" 2>/dev/null \
    || cp -f "${gcc_packages[0]}" "${LINUX64}/"

# rattler-index runs through `pixi exec` on purpose: it must not depend on any
# workspace environment.
index_channel() {
    pixi exec -s rattler-index -- rattler-index fs "${CHANNEL}"
}

# Index before publishing: the headers recipe has the cross compiler as a build
# dependency and resolves it from this channel.
index_channel

pixi publish --path "${ROOT}/recipes/riscv64-unknown-elf-libstdcxx" \
    --target-dir "${LINUX64}" --force

# Re-index to add the package that was just published.
index_channel

for name in riscv64-unknown-elf-gcc riscv64-unknown-elf-libstdcxx; do
    grep -q "\"${name}\"" "${LINUX64}/repodata.json" || {
        echo "error: ${name} is missing from ${LINUX64}/repodata.json" >&2
        exit 1
    }
done

echo "local channel: file://${CHANNEL}"
