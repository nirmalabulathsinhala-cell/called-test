import Cocoa
import InputMethodKit

// MARK: - Sinhala FM Input Method — Entry Point

/// Global reference to the IMK server.
/// Must be held globally to prevent premature deallocation.
var imkServer: IMKServer?

/// Entry point for the Sinhala FM Font Input Method.
///
/// This initializes the IMKServer which connects this input method to the
/// macOS text input system. Once running, macOS will route keyboard events
/// to our SinhalaInputController when the user selects this input method.
func startInputMethod() {
    // Read connection name from Info.plist
    let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String
        ?? "com.sinhala.inputmethod.fminput_Connection"
    
    let bundleID = Bundle.main.bundleIdentifier
        ?? "com.sinhala.inputmethod.fminput"
    
    NSLog("SinhalaFMInput: Starting input method...")
    NSLog("SinhalaFMInput: Connection name: %@", connectionName)
    NSLog("SinhalaFMInput: Bundle ID: %@", bundleID)
    
    // Create the IMK server
    imkServer = IMKServer(name: connectionName, bundleIdentifier: bundleID)
    
    if imkServer == nil {
        NSLog("SinhalaFMInput: ERROR — Failed to create IMKServer!")
        NSLog("SinhalaFMInput: Ensure Info.plist has correct InputMethodConnectionName")
        NSLog("SinhalaFMInput: Ensure bundle identifier contains '.inputmethod.'")
    } else {
        NSLog("SinhalaFMInput: IMKServer created successfully")
    }
    
    // Load the default font profile
    loadDefaultProfile()
    
    // Start the application run loop
    NSLog("SinhalaFMInput: Starting run loop...")
    NSApplication.shared.run()
}

/// Load the default FM font profile.
///
/// Attempts to load fm_abhaya_map.json from the app bundle.
/// Falls back gracefully if the profile is not found.
private func loadDefaultProfile() {
    do {
        try CharacterMapper.shared.loadProfile(named: "fm_abhaya_map")
        NSLog("SinhalaFMInput: Loaded font profile: %@",
              CharacterMapper.shared.currentProfileName)
    } catch {
        NSLog("SinhalaFMInput: WARNING — Could not load default font profile: %@",
              error.localizedDescription)
        NSLog("SinhalaFMInput: The input method will pass all keystrokes through unchanged")
        NSLog("SinhalaFMInput: Ensure fm_abhaya_map.json is in Contents/Resources/")
    }
}

// Launch
startInputMethod()
