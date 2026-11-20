# vendor：预构建制品

存放 channel 使用的预构建二进制制品。`.conda` 文件不进入 git（见根目录
`.gitignore`），仓库只提交校验和与说明。

## riscv64-unknown-elf-gcc

| 项目          | 值                                                                 |
| ------------- | ------------------------------------------------------------------ |
| 文件          | `riscv64-unknown-elf-gcc-16.2.0-h3fd9d12_1.conda`                  |
| sha256        | 见 [`SHA256SUMS`](SHA256SUMS)                                      |
| 来源          | 早期 conda-build 单包（含 GCC、binutils、libgcc 和头文件）         |
| 原始包 sha256 | `314e9916e600d3862986b3beeb2344c2ad6dd9baebc5cff64770472d27d86505` |

包内容为 GCC、binutils 和 libgcc；不含 libstdc++ 头文件（头文件由
`recipes/riscv64-unknown-elf-libstdcxx` 单独生成）。

`tools/repack-gcc-package.py` 生成了这个包：删除 libstdc++ 头文件、`info/recipe`、
`info/test`、`info/hash_input.json`，重写 `info/about.json`，build number 从 `0`
升到 `1`。

`tools/build-toolchain-channel.sh` 取 `vendor/` 中唯一的
`riscv64-unknown-elf-gcc-16.2.0-*.conda`，按 `SHA256SUMS` 校验后复制到 channel。
校验命令：

```bash
cd vendor && sha256sum --quiet -c SHA256SUMS
```

## 从原始单包生成

```bash
pixi exec -s python -s conda-package-handling -- \
    python tools/repack-gcc-package.py <原包.conda> vendor
# 更新 vendor/SHA256SUMS
```

脚本打印产物文件名和 sha256。

需要从源码重建这个包时，用
`pixi publish --path recipes/riscv64-unknown-elf-gcc --target-dir vendor`，然后删除
旧包并更新 `SHA256SUMS`。
