# PLAN: Mount an Android Phone in macOS Finder Over USB (Free, No USB Debugging)

> Audience: an AI agent that executes this plan step by step on the user's Mac.
> Follow the phases in order. Do not improvise. Do not skip a **Verify** block.

## 1. Goal and Success Criteria
Plug an Android phone into the Mac with a USB cable. Double-click **Mount Android.app**. A Finder window opens showing the phone's storage, and files can be copied both ways.

Constraints: USB debugging stays **OFF**. No paid apps (no MacDroid). No kernel extension, no Recovery Mode, no lowered security.

Success means ALL of these are shown with real command output:
1. `mount` lists `~/Android` as a mounted volume.
2. A file copied phone → Mac and a file copied Mac → phone both have identical SHA-256 checksums.
3. `Mount Android.app` finishes in under about 20 seconds without hanging.
4. Unmount (Finder Eject or `Unmount Android.app`) works and leaves no stale mount.

---

## 2. Facts, Assumptions, and Environment

### 2.1 Verified on this Mac (do not re-check)
- macOS 27.2.1, Apple Silicon (`arm64`). Homebrew is at `/opt/homebrew/bin/brew`.
- Already installed: `MacDroid.app` (paid, running, menu-bar app), `Freedroid.app` (bundles `adb`, needs USB debugging, **not needed here**), `Android File Transfer.app` (Google's old app, has an "Agent" helper), and Homebrew casks `android-commandlinetools` and `flutter`. **The user is probably an Android/Flutter developer, so never kill or uninstall `adb` in any script.**
- A Samsung Smart Switch daemon exists: `/Library/LaunchDaemons/com.devguru.ssconnservice2.plist` (`KeepAlive`, runs `/Library/LaunchAgents/ss_conn_service2`).
- `brew install android-file-transfer-linux` builds with `-DBUILD_FUSE=OFF`, so it has **no `aft-mtp-mount`**. The cask `whoozle-android-file-transfer` is disabled by Homebrew. **`aft-mtp-mount` must be built from source.**
- `macfuse` cask is 5.5.0. It ships `libfuse3` 3.18.3 and a user-space **FSKit backend** (`-o backend=fskit`). FSKit needs macOS 26 or newer (satisfied). No kext, no reboot.

### 2.2 Verified in source code (these drive the design)
- **Likely root cause of "it won't mount" (standard MTP behavior, not tested on this Mac):** only one process at a time can claim the phone's MTP USB interface. Likely claimers: MacDroid, Google's Android File Transfer Agent, macOS `ptpcamerad` / Image Capture, and (Samsung only, unproven) Smart Switch. `adb` normally uses a different USB interface and is probably not a blocker.
- `aft-mtp-mount` opens the USB device **first**, then mounts. So `connect failed: ...` or `no MTP device found` means a USB/MTP problem. Errors mentioning `fuse` or `File system extension` mean a macFUSE problem.
- macFUSE 5.5.0 `fuse_daemonize()` prints `fuse: forking after mount is not supported` and forces foreground mode. **Always pass `-f` and background the process from the shell with all stdio redirected.**
- **FSKit large-read fix (verified on this Mac):** Upstream `aft/fuse/fuse.cpp` uses `fuse_reply_buf()`, which causes macFUSE 5.5.0 FSKit to fail with `EIO` (`Input/output error`) on reads `>= 128 KB` (breaking `cp`/`fcopyfile` and `cat`). Patching `Read()` in `aft/fuse/fuse.cpp` to use `fuse_reply_data()` (`MFMessageGetReplyBuffer`) fixes all large reads.
- macFUSE passes these as mount options (all verified in `mount_darwin.c`): `backend=fskit`, `volname=`, `local`, `noappledouble`, `noapplexattr`, `defer_permissions`, `daemon_timeout=`, `ro`.
- macFUSE 5.5.0 release notes: `local` volumes now show as local volumes in Finder and can be ejected from Finder (fixed in 5.5.0). Read-only mounts work on macOS 26.4+. FSKit has two extensions that both must be enabled: **macFUSE** and **macFUSE (local)**.
- macFUSE 5.5.0 turns empty `FUSE_READ` replies into `EIO` to avoid an FSKit data-corruption bug. A file whose size changes on the phone during a read can fail. **Do not use the phone's camera or apps that write storage during copies.**
- `aft-mtp-mount` cannot create files at the top level (the list of storages). `EPERM` there is **expected**. Write only inside a storage folder such as `Internal shared storage/Download`.
- Writing needs the Android MTP "EditObject" extension. If the phone lacks it, the log says `your device does not have android EditObject extension`. Reads still work.
- `aft-mtp-mount --help` prints `Additional AFT options:` and exits before touching USB. It is a safe "does the binary run" test.
- Known macFUSE issue #1232 (open): after roughly 15-20 mounts, FSKit may report `File system extension not enabled` and the user must re-toggle it in System Settings.

### 2.3 UNVERIFIED assumptions (test them, report results, never claim them as fact)
- U1: whether a volume mounted at `~/Android` appears in the Finder sidebar under Locations. The guaranteed behavior is only that `open ~/Android` shows it in a Finder window.
- U2: whether `ptpcamerad` re-launches itself when the phone is plugged in. Plan: kill it and retry.
- U3: whether Smart Switch (`ss_conn_service2`) really blocks MTP on this Mac. Plan: touch it only if evidence shows it does.
- U4: whether Finder copies work over FSKit with this filesystem. Plan: test with checksums.

### 2.4 Shell preamble (put these two lines at the top of every command session)
```bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export HOMEBREW_NO_AUTO_UPDATE=1
```

### 2.5 Command-safety rules for process matching
- `pkill -f` and `pgrep -f` match the **whole command line**, including your own `zsh -c "..."` wrapper. A plain `pkill -f "Android File Transfer"` can kill your own shell. **Always use the bracket trick** on the first letter, e.g. `'[A]ndroid File Transfer'`, `'[M]acDroid'`.
- Use `pgrep -x name` (exact process name) for short names: `ptpcamerad`, `aft-mtp-mount`.

---

## 3. Who Does What

| Step | Agent can do | Only the user can do |
|---|---|---|
| Phone USB mode, unlock, cable | – | Yes (give exact instructions) |
| Install macFUSE (`sudo` password) | – | Yes: user runs one command in their own Terminal |
| Toggle macFUSE extensions | – | Yes: System Settings |
| Image Capture "No application" setting | – | Yes |
| Homebrew deps, clone, build, scripts, apps | Yes | – |
| Mount/unmount tests, checksum tests | Yes | – |
| Unload Samsung daemon (needs `sudo`) | – | Yes, only if Phase 1 evidence demands it |
| Final double-click test of the app | – | Yes |

**Efficiency tip:** In your first message to the user, send ONE checklist covering every user-only action (Phase 0, Phase 1 manual items, Phase 2). Then continue with agent-only work while they do it.

## 4. Hard Rules
1. **Never** disable SIP, lower security in Recovery Mode, or enable kernel extensions without explicit user permission.
2. **Never** script around a permission gate: do not edit the TCC database, do not use `pluginkit`/`systemextensionsctl` to force-enable the macFUSE extension, do not try to feed a password to `sudo`. The user toggles and types passwords themselves. If a gate blocks you, stop and report.
3. **Never** uninstall MacDroid, Freedroid, Android File Transfer, or `adb`. Quitting them is enough.
4. **Never** use `sudo` without first telling the user why.
5. Run each phase's **Verify** and paste the real output in your report. If Verify fails, use Section 6 (Troubleshooting). If still failing, stop and report the exact output. No guessing, no skipping.
6. Keep source and build files in `~/Documents/ideas/mac-android/`. Keep binaries and scripts in `~/.local/bin/`. Do not start interactive programs (anything that waits for keyboard input) from the agent shell.

---

## 5. Phases

### Phase 0: Phone setup (user)
Ask the user to:
1. Use a **USB data cable** (charge-only cables fail), plugged directly into the Mac.
2. **Unlock the phone and keep the screen on.** A locked phone often shows empty storage.
3. Pull down the notification shade → tap "Charging this device via USB" (wording varies) → choose **File transfer / MTP** (Samsung: "Transferring files"). Android resets this to "No data transfer" on every re-plug, so repeat after every re-plug.
4. Leave **USB debugging OFF**.

**Verify:**
```bash
system_profiler SPUSBHostDataType 2>/dev/null | grep -i -E "android|samsung|pixel|xiaomi|oneplus|huawei|motorola|google|oppo|vivo|realme|nothing" | head
# If nothing matches: run `system_profiler SPUSBHostDataType` once with the phone unplugged and once plugged, and compare. The new entry is the phone.
```
The phone's maker or model must appear. If it does not, the problem is the cable or port. Stop and ask the user to try another cable.

### Phase 1: Release competing USB/MTP claimers (agent)
```bash
pkill -x MacDroid 2>/dev/null
pkill -x DroiderLauncher 2>/dev/null
pkill -f '[F]reedroid' 2>/dev/null
pkill -f '[A]ndroid File Transfer' 2>/dev/null
pkill -x ptpcamerad 2>/dev/null
true
```
Why `pkill -x MacDroid` and not AppleScript `quit`: AppleScript would trigger a macOS Automation permission prompt. `adb` is intentionally left alone.

Ask the user to do these one-time manual steps:
1. System Settings → General → Login Items & Extensions: turn **off** MacDroid / DroiderLauncher and Android File Transfer Agent so they do not restart at login.
2. Open **Image Capture** with the phone connected, select the phone, and set "Connecting this device opens" to **No application**.

**Verify (must print `CLEAN`):**
```bash
pgrep -fil '[M]acDroid|[D]roiderLauncher|[F]reedroid|[A]ndroid File Transfer' || echo CLEAN
```

**Samsung only, and only if Phase 3 (raw MTP test) reports the device is busy after everything above is clean:**
```bash
pgrep -fl '[s]s_conn_service2'
```
If it is running, explain to the user that Smart Switch's background service may be holding the phone, and ask permission to run this (temporary until reboot):
```bash
sudo launchctl bootout system/com.devguru.ssconnservice2
```

### Phase 2: Install macFUSE 5.5.0 and enable both FSKit extensions (user + agent)
1. First check whether it is already installed: `ls /Library/Filesystems | grep -i macfuse`. If present and `pkg-config` can find `fuse3` (Phase 3 step 2), skip to step 3.
2. **The agent cannot enter a password.** Tell the user to run this ONE line in their own Terminal, type their macOS password when asked, and tell you when it finishes:
   ```bash
   brew install --cask macfuse
   ```
   Ignore the cask's printed "kernel extension" caveat. We use the FSKit backend, not the kext. No reboot is needed.
3. Register the FSKit extensions so macOS lists them in System Settings (no `sudo`, does not bypass user approval):
   ```bash
   /Library/Filesystems/macfuse.fs/Contents/Resources/macfuse.app/Contents/MacOS/macfuse install --components file-system-extensions
   ```
4. Ask the user to open (or close and re-open) **System Settings → General → Login Items & Extensions**, look under **By Category** (NOT *By App*!), click the **`i`** info button next to **File System Extensions**, and turn **ON both** entries: **macFUSE** and **macFUSE (local)**. *(Note: macOS has a known bug — macfuse#1194 — where toggling them under "By App" silently fails with `EPERM`, while toggling them under **By Category → File System Extensions** works.)*

**Verify:**
```bash
ls /Library/Filesystems | grep -i macfuse
find /usr/local /Library/Filesystems -name 'fuse3.pc' 2>/dev/null
pluginkit -m -p com.apple.fskit.fsmodule | grep -i macfuse
```
Both must return results. Typical `fuse3.pc` location: `/usr/local/lib/pkgconfig/fuse3.pc`. If it is elsewhere, use that directory as `PKG_CONFIG_PATH` in Phase 3.

If a later mount says `File system extension not found` or `not enabled`: have the user switch both macFUSE toggles off and on. If it still fails, the macFUSE maintainer suggested (unconfirmed fix) running this once, without `sudo`:
```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Library/Filesystems/macfuse.fs/Contents/Resources/macfuse.app"
```

### Phase 3: Build `aft-mtp-mount` from source (agent)
1. Tools. If `xcode-select -p` fails, tell the user to run `xcode-select --install` (opens a GUI installer) and wait for them to finish. Then:
   ```bash
   brew install cmake pkg-config readline
   ```
   (`readline` is only for the optional `aft-mtp-cli` niceties. It is "keg-only", so it needs a hint below.)
2. Check `fuse3` is visible BEFORE running CMake:
   ```bash
   export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
   pkg-config --modversion fuse3
   ```
   Must print `3.x` (expected `3.18.3`). If not, fix `PKG_CONFIG_PATH` using the Phase 2 `find` result. Do not continue until this works.
3. Clone and configure:
   ```bash
   mkdir -p ~/Documents/ideas/mac-android ~/.local/bin
   cd ~/Documents/ideas/mac-android
   [ -d aft ] || git clone --depth 1 https://github.com/whoozle/android-file-transfer-linux.git aft
   cd aft && git rev-parse HEAD        # record this commit hash in your report
   rm -rf build
   cmake -S . -B build \
     -DCMAKE_BUILD_TYPE=Release \
     -DBUILD_FUSE=ON -DBUILD_QT_UI=OFF -DBUILD_MTPZ=OFF \
     -DBUILD_PYTHON=OFF -DBUILD_TAGLIB=OFF -DBUILD_SHARED_LIB=OFF \
     -DCMAKE_PREFIX_PATH="$(brew --prefix readline)" \
     -DCMAKE_INSTALL_PREFIX="$HOME/.local"
   ```
   The CMake output **must** contain `fuse found, building mount helper`. If it does not, `rm -rf build`, fix `PKG_CONFIG_PATH`, and re-run. A `no readline library found, using stub` warning is harmless.
4. Build and install:
   ```bash
   cmake --build build -j && cmake --install build
   ```
   If `~/.local/bin/aft-mtp-mount` is missing, copy it from `build/fuse/aft-mtp-mount`.
   If master fails to compile, retry once with the release tag: `git fetch --depth 1 origin tag v4.6 && git checkout v4.6`, then rebuild from `rm -rf build`. Report which one worked.

**Verify (binary runs, then raw MTP works with the phone connected, unlocked, and in MTP mode):**
```bash
~/.local/bin/aft-mtp-mount --help | grep "Additional AFT options"
otool -L ~/.local/bin/aft-mtp-mount | grep -i fuse3
printf 'ls\nquit\n' | ~/.local/bin/aft-mtp-cli -b
```
- The first command must print the line. The second must show a `libfuse3` path. The third must list the phone's storage (for example `Internal shared storage`). An empty list usually means the phone is locked.
- `device not found` / `no MTP device found`: go to Phase 0 and Phase 1. `busy`: go to Section 6.

### Phase 4: First manual mount and integrity test (agent)
Baseline mount options (the only ones to use at first):
`backend=fskit,volname=Android,local,noappledouble` *(omit `noapplexattr`: `noapplexattr` returns `EPERM` on `setxattr`, causing `cp` writes to exit `1`, whereas omitting it returns `ENOTSUP` so `cp` succeeds cleanly while `noappledouble` still blocks `._*` files)*

```bash
MNT="$HOME/Android"; LOG=/tmp/aft-mtp-mount.log
mkdir -p "$MNT"
pkill -x ptpcamerad 2>/dev/null
nohup ~/.local/bin/aft-mtp-mount -f \
  -o backend=fskit,volname=Android,local,noappledouble,noapplexattr \
  "$MNT" >"$LOG" 2>&1 </dev/null &
disown
for i in $(seq 1 20); do mount | grep -Fq " on $MNT (" && break; sleep 0.5; done
mount | grep -F " on $MNT (" || { echo "NOT MOUNTED"; cat "$LOG"; }
```
Notes:
- `-f` plus `&` plus full stdio redirect is mandatory (see 2.2). Without the redirect, tool calls and AppleScript applets will hang until unmount.
- The mount point must be an existing, empty directory you own.
- If your agent tool kills background jobs when a command ends, run the mount as a managed background/daemon task instead. Then confirm it survived by running `mount | grep Android` in a **separate** command.
- Option ladder, add ONE option at a time and only if needed:
  - `Permission denied` on writes → add `defer_permissions`.
  - The mount hangs after unplugging the phone → add `daemon_timeout=120`. Keep it large, because listing a huge MTP folder can take a long time.
  - Writes behave badly → use the safe read-only mode in Section 7.
- If an option is rejected, check `$LOG`, drop only that option, and record which option was rejected.

```bash
open "$MNT"
```

**Verify, all five are mandatory:**
1. The Finder window shows the phone's storage folder(s). Also look at the sidebar and tell the user whether "Android" appears under Locations (this settles assumption U1, report either answer).
2. **Read test with integrity:** copy any file of at least 20 MB from the phone to `/tmp/from_phone.bin` with `cp`, and confirm its size equals the size shown on the phone side (`stat -f %z`).
3. **Write + round-trip test** (must be INSIDE a storage folder, not at the top level):
   ```bash
   dd if=/dev/urandom of=/tmp/rt.bin bs=1m count=20
   shasum -a 256 /tmp/rt.bin
   cp /tmp/rt.bin "$MNT/Internal shared storage/Download/rt_test.bin"
   ```
   (Use the real storage folder name seen in step 1.)
4. Eject, remount using the same command as above, then:
   ```bash
   shasum -a 256 "$MNT/Internal shared storage/Download/rt_test.bin"
   ```
   The checksum must equal step 3. Remounting forces a real read from the phone instead of a cache. Then delete `rt_test.bin` from the phone.
5. Unmount cleanly:
   ```bash
   diskutil unmount "$MNT" || diskutil unmount force "$MNT" || umount "$MNT"
   pgrep -x aft-mtp-mount || echo "process gone"
   ```

If checksums differ or the copy fails, stop. Report the exact log from `$LOG` and use Section 7.

### Phase 5: One-click launcher (agent writes, user double-clicks)
Use the exact baseline flags that passed Phase 4 (plus any ladder option you had to add).

**5.1 `~/.local/bin/android-mount`**, then `chmod +x`. Write it exactly like this:
```bash
#!/bin/bash
# Mount the USB-connected Android phone (MTP) in Finder via aft-mtp-mount + macFUSE FSKit.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$HOME/.local/bin"
MNT="$HOME/Android"
BIN="$HOME/.local/bin/aft-mtp-mount"
LOG="/tmp/aft-mtp-mount.log"
OPTS="backend=fskit,volname=Android,local,noappledouble"   # add Phase 4 ladder options here if needed

is_mounted() { /sbin/mount | /usr/bin/grep -Fq " on $MNT ("; }
fail() {
  echo "Mount failed: $1" >&2
  /usr/bin/tail -n 15 "$LOG" >&2 2>/dev/null
  exit 1
}

# Already mounted and server alive: just show it.
if is_mounted && /usr/bin/pgrep -x aft-mtp-mount >/dev/null; then
  /usr/bin/open "$MNT"; exit 0
fi

# Clean stale state (phone was unplugged, or the previous server died).
is_mounted && /usr/sbin/diskutil unmount force "$MNT" >/dev/null 2>&1
/usr/bin/pkill -x aft-mtp-mount 2>/dev/null

# Release competing USB claimers. Do NOT kill adb here.
/usr/bin/pkill -x MacDroid 2>/dev/null
/usr/bin/pkill -x DroiderLauncher 2>/dev/null
/usr/bin/pkill -f '[F]reedroid' 2>/dev/null
/usr/bin/pkill -f '[A]ndroid File Transfer' 2>/dev/null

/bin/mkdir -p "$MNT"

# Up to 4 attempts: ptpcamerad may re-grab the phone between attempts.
for attempt in 1 2 3 4; do
  /usr/bin/pkill -x ptpcamerad 2>/dev/null
  nohup "$BIN" -f -o "$OPTS" "$MNT" >"$LOG" 2>&1 </dev/null &
  PID=$!
  disown 2>/dev/null
  for _ in $(seq 1 20); do                      # wait up to 10 s
    if is_mounted; then /usr/bin/open "$MNT"; exit 0; fi
    kill -0 "$PID" 2>/dev/null || break         # server exited early: retry
    /bin/sleep 0.5
  done
  kill "$PID" 2>/dev/null
  /bin/sleep 1
done

if /usr/bin/grep -q "no MTP device found" "$LOG" 2>/dev/null; then
  fail "phone not detected. Unlock it, choose File transfer (MTP) in the USB notification, and re-plug the cable."
fi
fail "mount did not appear. If the log mentions 'File system extension', toggle macFUSE and macFUSE (local) in System Settings > Login Items & Extensions > File System Extensions."
```

**5.2 `~/.local/bin/android-unmount`**, then `chmod +x`:
```bash
#!/bin/bash
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
MNT="$HOME/Android"
if /sbin/mount | /usr/bin/grep -Fq " on $MNT ("; then
  /usr/sbin/diskutil unmount "$MNT" 2>/dev/null || /usr/sbin/diskutil unmount force "$MNT" 2>/dev/null || /sbin/umount -f "$MNT"
fi
/usr/bin/pkill -x aft-mtp-mount 2>/dev/null
exit 0
```

**5.3 Double-click apps** (`quoted form of` handles spaces in the home path; the `try` block shows script errors in a dialog):
```bash
mkdir -p ~/Applications
osacompile -o "$HOME/Applications/Mount Android.app" \
  -e 'try' \
  -e 'do shell script quoted form of ((POSIX path of (path to home folder)) & ".local/bin/android-mount")' \
  -e 'on error errMsg' \
  -e 'display alert "Mount Android failed" message errMsg as critical' \
  -e 'end try'
osacompile -o "$HOME/Applications/Unmount Android.app" \
  -e 'try' \
  -e 'do shell script quoted form of ((POSIX path of (path to home folder)) & ".local/bin/android-unmount")' \
  -e 'on error errMsg' \
  -e 'display alert "Unmount Android failed" message errMsg as critical' \
  -e 'end try'
```

**5.4 Verify (agent first, then user):**
1. Test the script directly first, with the phone connected, unlocked, in MTP mode:
   ```bash
   ~/.local/bin/android-mount; echo "exit=$?"
   ```
   Expect `exit=0` within about 20 s and a Finder window. Run it a second time: it must just re-open Finder, not remount. Then run `~/.local/bin/android-unmount; mount | grep Android` (no output expected).
2. Ask the user to unplug and re-plug the phone, set MTP mode again, and double-click `~/Applications/Mount Android.app`. It must finish by itself (no spinning Dock icon) and Finder must open the phone. A macOS permission prompt about removable volumes or files may appear once: the user clicks Allow.
3. Ask the user to eject via Finder (or `Unmount Android.app`) and confirm `mount | grep "$HOME/Android"` is empty.
4. Optional for the user: drag `~/Android` into the Finder sidebar Favorites, and drag `Mount Android.app` into the Dock.

---

## 6. Troubleshooting Matrix

| Symptom / log text | Meaning | Action |
|---|---|---|
| `no MTP device found`, `device not found` | Phone not in MTP mode, locked, or bad cable | Phase 0 again; try another cable and port |
| `busy`, `claim interface`, `access denied`, `exclusive` | Another process holds the MTP interface | Re-run Phase 1 (use `pgrep -fil` to find the holder). Try `pkill -x ptpcamerad` and retry immediately. Samsung: see Phase 1 Samsung note |
| `fuse: mount tool missing` | macFUSE is not installed correctly | Redo Phase 2 |
| Mount point error, mount silently fails, or no mount appears for `~/Android` | FSKit may reject mount points outside `/Volumes` (unverified) | Tell the user why, then ask them to run once: `sudo mkdir -p /Volumes/Android && sudo chown "$USER" /Volumes/Android`. Set `MNT=/Volumes/Android` in Phase 4 and in both scripts. macOS may delete the empty folder at reboot, so repeat then |
| `File system extension not found` / `not enabled`, or Settings toggle won't turn ON | FSKit extension off, or toggled under *By App* (macOS bug #1194) | Enable both under **By Category → File System Extensions** (not *By App*). If still failing, run `macfuse install --components file-system-extensions` and `lsregister -f` from Phase 2 |
| `forking after mount is not supported` | You forgot `-f` | Add `-f` |
| `Operation not permitted` writing at `~/Android/` top level | Expected: top level is the storage list | Write inside a storage folder |
| Empty storage folder, or a mount that looks empty | Phone is locked | Unlock the phone, keep the screen on |
| `your device does not have android EditObject extension` | Writes into files unsupported | Reads still work; use `aft-mtp-cli` for uploads |
| Finder shows error 100078 or zero-byte copied files | Known macFUSE FSKit write problems on macOS 27 | Section 7 |
| Mount point says `Device not configured` or `ls` hangs | Stale mount after unplug | `~/.local/bin/android-unmount`, then mount again |
| Anything unclear in FSKit | Need logs | `log show --last 5m --info --predicate 'subsystem BEGINSWITH "io.macfuse" OR process == "fskitd"'` and report the output |

## 7. Fallbacks (only after Phase 4 or 5 fails; always report first, then ask)
- **A. Safe read-only mount.** Add `ro` to the options (supported on macOS 26.4+). Reads and copying out still work through Finder. This avoids the FSKit write and corruption risks. Best choice if the user mainly wants to copy photos off the phone. Tell the user this limitation.
- **B. Uploads via CLI.** If Finder writes fail but reads work, keep the mount read-only for browsing and use `aft-mtp-cli` (unmount first, because only one process can hold the phone) for uploads: `-b` reads commands from **stdin** (not from an argument), e.g. `printf 'ls\nquit\n' | aft-mtp-cli -b`. Run `printf 'help\nquit\n' | aft-mtp-cli -b` first to learn the exact `put`/`cd` syntax, then pipe the upload commands the same way.
- **C. macFUSE kernel-extension backend.** Drop `backend=fskit`. This needs "Reduced Security" and a kext approval in Recovery Mode on Apple Silicon. **Do not do this without the user's explicit agreement** and a clear explanation of the security cost.
- **D. FUSE-T** (`brew install --cask fuse-t`) is **not recommended**. `aft-mtp-mount` needs the libfuse3 low-level API and there is no known `fuse3.pc`. Only attempt it if the user asks, and expect it to fail.
- **E. Last resort, if no Finder mount is possible at all:** tell the user honestly that cable-based Finder mounting failed, and offer an open-source two-pane MTP app (OpenMTP, `brew install --cask openmtp`) as a non-Finder alternative. Do not install it without the user's agreement.

## 8. Rollback (if the user wants everything removed)
```bash
~/.local/bin/android-unmount
rm -f ~/.local/bin/android-mount ~/.local/bin/android-unmount ~/.local/bin/aft-mtp-mount ~/.local/bin/aft-mtp-cli
rm -rf ~/Applications/"Mount Android.app" ~/Applications/"Unmount Android.app" ~/Documents/ideas/mac-android/aft
# NEVER `rm -rf ~/Android`: if it is still mounted, that deletes files ON THE PHONE.
mount | grep -Fq " on $HOME/Android (" && echo "STILL MOUNTED - stop" || rmdir ~/Android
```
`brew uninstall --cask macfuse` needs the user's password, so the user runs it. Never remove MacDroid, Freedroid, or Android File Transfer unless the user asks.

## 9. Final Report Template (send this when finished)
- Result: success / partial / failed.
- Commit or tag of `aft` that was built.
- Exact mount options that worked, and any ladder option you had to add.
- Evidence: the `mount` line, the two checksums, the exit code of `android-mount`, the time it took.
- Answers to the unverified assumptions U1 to U4.
- Anything the user must remember (phone must be unlocked and in MTP mode on every re-plug; re-toggle the macFUSE extensions if they get disabled).

## 10. Known Limits (tell the user)
- The first listing of a huge folder (for example `DCIM/Camera`) over MTP is slow. This is normal.
- While mounted, no other MTP app (Image Capture, MacDroid, Android File Transfer) can use the phone.
- After re-plugging, rebooting the phone, or changing USB mode, run **Mount Android** again. macOS never auto-mounts MTP.
- macFUSE FSKit is young on macOS 27. Keep a copy of important files and prefer the checksum test for big transfers.
