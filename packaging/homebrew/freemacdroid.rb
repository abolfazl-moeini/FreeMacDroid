cask "freemacdroid" do
  version "0.2.0"
  sha256 "1abc0ba4170d63110a8f60efe41dc7b3ba877c9bdbd5bcdbd8b18b2a238ff6fc"

  url "https://github.com/abolfazl-moeini/FreeMacDroid/releases/download/v#{version}/FreeMacDroid.dmg"
  name "FreeMacDroid"
  desc "Open-source one-click Android MTP Finder mount for macOS (no USB debugging)"
  homepage "https://github.com/abolfazl-moeini/FreeMacDroid"

  depends_on macos: ">= :sequoia"
  depends_on cask: "macfuse"

  app "FreeMacDroid.app"
  binary "#{appdir}/FreeMacDroid.app/Contents/Helpers/android-mount"
  binary "#{appdir}/FreeMacDroid.app/Contents/Helpers/android-unmount"

  caveats <<~EOS
    To enable FreeMacDroid's user-space Finder mount (no kernel extension needed):
      1. Register macFUSE FSKit extensions (or click "Register Extensions" in FreeMacDroid):
         /Library/Filesystems/macfuse.fs/Contents/Resources/macfuse.app/Contents/MacOS/macfuse install --components file-system-extensions
      2. Open System Settings -> General -> Login Items & Extensions -> By Category -> File System Extensions (i)
         and enable both "macFUSE" and "macFUSE (local)".
      3. Unlock your Android phone and select "File transfer / MTP" in the USB notification.
  EOS
end
