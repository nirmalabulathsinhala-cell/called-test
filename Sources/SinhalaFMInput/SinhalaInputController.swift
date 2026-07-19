import Cocoa
import InputMethodKit

// MARK: - Sinhala Input Controller

/// The core IMK input controller that handles all keystroke events.
///
/// This controller is instantiated by InputMethodKit when the user selects
/// "Sinhala FM" as their input method. It intercepts every keystroke,
/// passes it through the ReorderingEngine, and sends the correctly
/// ordered text to the target application (e.g., CorelDRAW, Illustrator).
///
/// The `@objc(SinhalaInputController)` attribute ensures the class is visible
/// to the Objective-C runtime, which InputMethodKit requires.
@objc(SinhalaInputController)
class SinhalaInputController: IMKInputController {
    
    // MARK: - Properties
    
    /// The reordering engine for this input session
    private var engine = ReorderingEngine()
    
    /// Track whether we have active composition
    private var compositionActive: Bool = false
    
    // MARK: - IMKInputController Overrides
    
    /// Handle a keyboard event.
    ///
    /// This is called for every key event when our input method is active.
    /// We classify the key, process it through the reordering engine,
    /// and execute the appropriate action (update composition, commit text, etc.)
    ///
    /// - Parameters:
    ///   - event: The keyboard event
    ///   - sender: The IMK text input client (the target application)
    /// - Returns: `true` if we handled the event, `false` to pass through
    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        // Validate inputs
        guard let event = event else {
            NSLog("SinhalaFMInput: handle() called with nil event")
            return false
        }
        
        guard event.type == .keyDown else {
            return false
        }
        
        guard let client = sender as? (any IMKTextInput) else {
            NSLog("SinhalaFMInput: Could not cast sender to IMKTextInput")
            return false
        }
        
        let modifiers = event.modifierFlags
        
        // Let the system handle Cmd, Ctrl, and Option+Ctrl modified keys
        // (e.g., Cmd+C for copy, Cmd+V for paste)
        if modifiers.contains(.command) || modifiers.contains(.control) {
            // Commit any pending composition before system shortcuts
            if compositionActive {
                commitCurrentComposition(client: client)
            }
            return false
        }
        
        let keyCode = event.keyCode
        
        // Handle special keys
        switch keyCode {
        case 51: // Backspace / Delete
            return handleBackspace(client: client)
            
        case 36: // Return
            return handleReturn(client: client)
            
        case 76: // Numpad Enter
            return handleReturn(client: client)
            
        case 53: // Escape
            return handleEscape(client: client)
            
        case 123, 124, 125, 126: // Arrow keys (left, right, down, up)
            // Commit composition and let arrows work normally
            if compositionActive {
                commitCurrentComposition(client: client)
            }
            return false
            
        case 48: // Tab
            if compositionActive {
                commitCurrentComposition(client: client)
            }
            return false
            
        default:
            break
        }
        
        // Get the typed character
        guard let characters = event.characters, !characters.isEmpty else {
            return false
        }
        
        guard let char = characters.first else {
            return false
        }
        
        // Check if this is a split vowel trigger
        if let splitVowel = CharacterMapper.shared.getSplitVowel(for: char) {
            let action = engine.processSplitVowel(splitVowel)
            return executeAction(action, client: client)
        }
        
        // Process through the reordering engine
        let action = engine.processCharacter(char)
        return executeAction(action, client: client)
    }
    
    /// Called when the system wants us to commit the current composition.
    /// This happens when the user clicks elsewhere, switches apps, etc.
    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? (any IMKTextInput) else { return }
        commitCurrentComposition(client: client)
    }
    
    /// Called when this input method is activated (user switches to it).
    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        engine.reset()
        compositionActive = false
        NSLog("SinhalaFMInput: Input method activated (profile: %@)",
              CharacterMapper.shared.currentProfileName)
    }
    
    /// Called when this input method is deactivated (user switches away).
    override func deactivateServer(_ sender: Any!) {
        // Commit any pending composition
        if let client = sender as? (any IMKTextInput) {
            commitCurrentComposition(client: client)
        }
        engine.reset()
        compositionActive = false
        NSLog("SinhalaFMInput: Input method deactivated")
        super.deactivateServer(sender)
    }
    
    /// Return the current composition string.
    override func composedString(_ sender: Any!) -> Any! {
        return engine.compositionText as NSString
    }
    
    // MARK: - Action Execution
    
    /// Execute a ReorderAction by calling the appropriate IMK client methods.
    ///
    /// - Parameters:
    ///   - action: The action from the reordering engine
    ///   - client: The IMK text input client
    /// - Returns: `true` if we handled the event
    private func executeAction(_ action: ReorderAction, client: any IMKTextInput) -> Bool {
        switch action {
        case .updateComposition(let text):
            // Display the composition as marked (underlined) text
            compositionActive = true
            let attrString = createMarkedText(text)
            client.setMarkedText(
                attrString,
                selectionRange: NSRange(location: text.count, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
            return true
            
        case .commitText(let text):
            // Send the final text to the application
            compositionActive = false
            client.insertText(
                text as NSString,
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
            return true
            
        case .commitAndStart(let commitText, let compositionText):
            // Commit the previous syllable
            client.insertText(
                commitText as NSString,
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
            
            // Start a new composition
            if !compositionText.isEmpty {
                compositionActive = true
                let attrString = createMarkedText(compositionText)
                client.setMarkedText(
                    attrString,
                    selectionRange: NSRange(location: compositionText.count, length: 0),
                    replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
                )
            } else {
                compositionActive = false
            }
            return true
            
        case .passThrough:
            // Let the system handle this key
            return false
            
        case .delete(let remaining):
            if let remainingText = remaining {
                // Still have composition — update marked text
                compositionActive = true
                let attrString = createMarkedText(remainingText)
                client.setMarkedText(
                    attrString,
                    selectionRange: NSRange(location: remainingText.count, length: 0),
                    replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
                )
            } else {
                // Composition is now empty — clear marked text
                compositionActive = false
                client.setMarkedText(
                    "" as NSString,
                    selectionRange: NSRange(location: 0, length: 0),
                    replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
                )
            }
            return true
        }
    }
    
    // MARK: - Special Key Handlers
    
    /// Handle the Backspace/Delete key.
    private func handleBackspace(client: any IMKTextInput) -> Bool {
        let action = engine.processDelete()
        
        switch action {
        case .passThrough:
            // Buffer was empty — let the system handle backspace
            return false
        default:
            return executeAction(action, client: client)
        }
    }
    
    /// Handle the Return/Enter key.
    private func handleReturn(client: any IMKTextInput) -> Bool {
        if compositionActive {
            // Commit the composition, then let the system handle Return
            commitCurrentComposition(client: client)
        }
        // Return false so the system processes the Return key normally
        return false
    }
    
    /// Handle the Escape key.
    private func handleEscape(client: any IMKTextInput) -> Bool {
        if compositionActive {
            // Cancel the composition — clear marked text without committing
            engine.reset()
            compositionActive = false
            client.setMarkedText(
                "" as NSString,
                selectionRange: NSRange(location: 0, length: 0),
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
            return true
        }
        return false
    }
    
    // MARK: - Helper Methods
    
    /// Commit whatever is currently in the composition buffer.
    private func commitCurrentComposition(client: any IMKTextInput) {
        guard compositionActive else { return }
        
        if let text = engine.forceCommit(), !text.isEmpty {
            client.insertText(
                text as NSString,
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
        }
        
        compositionActive = false
    }
    
    /// Create an attributed string for marked text display.
    ///
    /// Marked text is shown with an underline to indicate it's still
    /// being composed and hasn't been committed yet.
    private func createMarkedText(_ text: String) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .underlineColor: NSColor.systemBlue
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }
}
