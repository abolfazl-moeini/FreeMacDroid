# Third-Party Notices

FreeMacDroid's Swift macOS wrapper (`src/FreeMacDroid/`), helper shell scripts (`bin/`), and build/packaging scripts (`scripts/`) are licensed under the MIT License (`LICENSE`).

FreeMacDroid bundles and depends on the following third-party software:

## 1. Android File Transfer for Linux (`aft-mtp-mount`, `aft-mtp-cli`)
- **Upstream:** https://github.com/whoozle/android-file-transfer-linux
- **License:** GNU Lesser General Public License v2.1 or later (LGPL-2.1-or-later)
- **Modifications:** `patches/0001-fuse-use-fuse_reply_data-for-macfuse-fskit.patch` modifies `fuse/fuse.cpp` (`Read()`) to use `fuse_reply_data()` for macFUSE FSKit compatibility on reads >= 128 KiB.
- **Source & Build:** Complete source retrieval and patch application are reproduced by `scripts/build-aft.sh`.

## 2. macFUSE (`libfuse3`, `macfuse.fs`)
- **Upstream:** https://macfuse.github.io / https://github.com/macfuse/macfuse
- **Note:** `libfuse3` (`macfuse/library`) is licensed under LGPL-2.1. The `macfuse.fs` FSKit/kernel components are free-of-charge proprietary software distributed separately by the macFUSE project and are **not** redistributed inside the FreeMacDroid source repository.
