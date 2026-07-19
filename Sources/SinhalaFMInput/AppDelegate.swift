import Cocoa
import InputMethodKit

// MARK: - App Delegate

/// Application delegate for the Sinhala FM Input Method.
///
/// Since this is a background-only input method (LSBackgroundOnly = YES),
/// there is no visible UI. The delegate handles lifecycle events and
/// can optionally provide a status bar menu for preferences.
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("SinhalaFMInput: Application did finish launching")
        NSLog("SinhalaFMInput: Active font profile: %@",
              CharacterMapper.shared.currentProfileName)
        
        // TODO: Future enhancement — Add a status bar menu item for:
        // - Switching between FM font profiles
        // - Enabling/disabling reordering
        // - Opening preferences
        // - Showing the character map
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NSLog("SinhalaFMInput: Application will terminate")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running — input methods are background processes
        return false
    }
}
