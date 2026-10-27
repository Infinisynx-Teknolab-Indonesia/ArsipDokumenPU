import Cocoa
import FlutterMacOS

// Arsip Dokumen PU — perilaku aplikasi macOS
@main
class AppDelegate: FlutterAppDelegate {
  // Tombol merah (tutup) hanya menyembunyikan jendela ke ikon menu bar
  // (seperti system tray di Windows). Aplikasi tetap berjalan supaya antrian
  // upload tetap terkirim. Keluar total: ikon menu bar -> Keluar, atau Cmd+Q.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // Klik ikon di Dock saat jendela tersembunyi -> tampilkan lagi.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in sender.windows {
        window.makeKeyAndOrderFront(self)
      }
      sender.activate(ignoringOtherApps: true)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
