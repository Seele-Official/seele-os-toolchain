#!/usr/bin/env bash
set -euo pipefail

# Generate the freestanding libstdc++ headers from the GCC sources.
#
# libstdc++-v3 is configured on its own against the cross compiler from the
# build environment, and only its headers are installed. Configure plus header
# installation takes a few minutes on the first build.

TARGET="riscv64-unknown-elf"
GCC_VERSION="16.2.0"

# Build out-of-tree inside SRC_DIR for a clean, reproducible configure step.
BUILD="${SRC_DIR}/build-libstdcxx"
mkdir -p "${BUILD}"
pushd "${BUILD}"

# A few checks assume a hosted C library; the target has none.
ac_cv_func_getexecname=no ac_cv_func_fcntl=no \
    "${SRC_DIR}/gcc/libstdc++-v3/configure" \
    --host="${TARGET}" \
    --prefix="${PREFIX}/${TARGET}" \
    --disable-nls \
    --disable-tls \
    --disable-multilib \
    --disable-hosted-libstdcxx \
    --disable-libstdcxx-verbose \
    --disable-libstdcxx-threads \
    --disable-libstdcxx-filesystem-ts \
    --disable-libstdcxx-backtrace \
    --without-headers

# Headers only: no libstdc++.a and no libsupc++ library.
make install-data

popd

INCLUDE_DIR="${PREFIX}/${TARGET}/include/c++/${GCC_VERSION}"

# The generated headers (bits/c++config.h, os_defines.h, gthr.h, ...) are
# staged under <include>/<target>/bits, but GCC expects them directly in bits/.
if [ -d "${INCLUDE_DIR}/${TARGET}/bits" ]; then
    cp -a "${INCLUDE_DIR}/${TARGET}/bits/." "${INCLUDE_DIR}/bits/"
    rm -rf "${INCLUDE_DIR}/${TARGET}"
fi

# ext/pb_ds is hosted-only and not part of the freestanding subset.
rm -rf "${INCLUDE_DIR}/ext/pb_ds"

test -f "${INCLUDE_DIR}/bits/c++config.h"
grep -q '^#define _GLIBCXX_HOSTED 0$' "${INCLUDE_DIR}/bits/c++config.h"
