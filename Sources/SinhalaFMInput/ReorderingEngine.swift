import Foundation

// MARK: - Reorder Action

/// Actions the input controller should take after the reordering engine processes a character.
enum ReorderAction {
    /// Update the marked (composition) text with this string.
    /// The IMK controller should call `client.setMarkedText()`.
    case updateComposition(String)
    
    /// Commit this text to the target application.
    /// The IMK controller should call `client.insertText()`.
    case commitText(String)
    
    /// Commit the current composition and start a new one.
    /// First commit `commit`, then set marked text to `composition`.
    case commitAndStart(commit: String, composition: String)
    
    /// Don't handle this input — let the system process it normally.
    case passThrough
    
    /// Handle a delete (backspace) within the composition.
    /// If the composition becomes empty, pass through to the app.
    case delete(remaining: String?)
}

// MARK: - Reordering Engine

/// The core reordering engine for Sinhala FM font input.
///
/// This engine processes each keystroke and applies reordering rules specific to
/// FM font encoding. The primary rule is: pre-base vowel signs (like kombuva ෙ)
/// must appear BEFORE the consonant in the ASCII text stream, even though the user
/// types the consonant first.
///
/// ## Reordering Rules
///
/// ### Rule 1: Pre-base vowel signs
/// When a pre-base sign is typed after a consonant, swap their positions.
/// ```
/// Buffer: [k]  →  User types kombuva 'e'  →  Buffer: [e, k]
/// ```
///
/// ### Rule 2: Split vowels
/// Split vowels wrap around the consonant. Insert left part before, right part after.
/// ```
/// Buffer: [k]  →  User types split-o  →  Buffer: [left, k, right]
/// ```
///
/// ### Rule 3: Conjuncts
/// When consonant + hal + consonant matches a known conjunct, optionally replace
/// with the conjunct glyph code.
///
/// ### Rule 4: Auto-commit
/// Spaces, punctuation, and new independent vowels trigger commit of the current buffer.
class ReorderingEngine {
    
    // MARK: - Properties
    
    /// The character mapper for classification
    private let mapper: CharacterMapper
    
    /// The composition buffer
    private(set) var buffer: CompositionBuffer
    
    /// Whether the last character was a hal (waiting for potential conjunct)
    private var pendingHal: Bool = false
    
    // MARK: - Configuration
    
    /// Whether to auto-commit when a space is typed
    var autoCommitOnSpace: Bool = true
    
    /// Whether to auto-commit when punctuation is typed
    var autoCommitOnPunctuation: Bool = true
    
    /// Whether to auto-commit when an independent vowel starts a new syllable
    var autoCommitOnNewSyllable: Bool = true
    
    /// Whether to attempt conjunct substitution
    var enableConjuncts: Bool = true
    
    // MARK: - Initialization
    
    /// Create a new reordering engine.
    ///
    /// - Parameter mapper: The character mapper to use for classification.
    ///                     Defaults to the shared singleton.
    init(mapper: CharacterMapper = .shared) {
        self.mapper = mapper
        self.buffer = CompositionBuffer()
    }
    
    // MARK: - Main Entry Point
    
    /// Process a new character input and determine the action to take.
    ///
    /// This is called for every keystroke. It classifies the character,
    /// applies the appropriate reordering rule, and returns an action
    /// for the IMK controller to execute.
    ///
    /// - Parameter char: The typed ASCII character
    /// - Returns: The action the controller should take
    func processCharacter(_ char: Character) -> ReorderAction {
        // If no profile is loaded, pass everything through
        guard mapper.hasProfile else {
            return .passThrough
        }
        
        let charType = mapper.classify(char)
        
        switch charType {
        case .preBaseSign:
            return handlePreBaseSign(char)
            
        case .consonant:
            return handleConsonant(char)
            
        case .hal:
            return handleHal(char)
            
        case .postBaseSign:
            return handlePostBaseSign(char)
            
        case .independentVowel:
            return handleIndependentVowel(char)
            
        case .anusvara, .visarga:
            return handleModifier(char)
            
        case .space:
            return handleSpace(char)
            
        case .punctuation, .number:
            return handlePunctuation(char)
            
        case .rakaransaya:
            return handleRakaransaya(char)
            
        case .yansaya:
            return handleYansaya(char)
            
        default:
            return handleDefault(char)
        }
    }
    
    /// Handle a delete (backspace) key press.
    ///
    /// - Returns: The action to take
    func processDelete() -> ReorderAction {
        if buffer.isEmpty {
            // Nothing in composition — let the system handle backspace
            return .passThrough
        }
        
        buffer.removeLast()
        pendingHal = false
        
        if buffer.isEmpty {
            return .delete(remaining: nil)
        } else {
            return .delete(remaining: buffer.text)
        }
    }
    
    /// Force-commit the current composition and reset.
    ///
    /// - Returns: The text to commit, or nil if buffer was empty
    func forceCommit() -> String? {
        guard !buffer.isEmpty else { return nil }
        let text = buffer.text
        reset()
        return text
    }
    
    /// Reset the engine state, clearing the buffer.
    func reset() {
        buffer.clear()
        pendingHal = false
    }
    
    /// The current composition text.
    var compositionText: String {
        return buffer.text
    }
    
    /// Whether there is an active composition.
    var hasComposition: Bool {
        return !buffer.isEmpty
    }
    
    // MARK: - Reordering Rule Handlers
    
    /// Handle a pre-base vowel sign (e.g., kombuva ෙ).
    ///
    /// RULE: Insert the pre-base sign BEFORE the last base consonant.
    /// If no consonant exists in the buffer, just append.
    ///
    /// Example: Buffer [k] + pre-base 'e' → Buffer [e, k]
    private func handlePreBaseSign(_ char: Character) -> ReorderAction {
        pendingHal = false
        
        if buffer.isEmpty {
            // No consonant to reorder with — just append
            buffer.append(char)
            return .updateComposition(buffer.text)
        }
        
        // Find the last base consonant (not followed by hal)
        if let consonantIndex = buffer.lastBaseConsonantIndex(using: mapper) {
            // Insert the pre-base sign BEFORE the consonant
            buffer.insertBefore(target: consonantIndex, char: char)
        } else {
            // No consonant found — just append
            buffer.append(char)
        }
        
        return .updateComposition(buffer.text)
    }
    
    /// Handle a consonant character.
    ///
    /// If we were pending a hal (C + hal), this consonant forms a conjunct
    /// or a dead+live consonant sequence. Otherwise, if the buffer already
    /// has a complete syllable, commit it and start fresh.
    private func handleConsonant(_ char: Character) -> ReorderAction {
        if pendingHal {
            // Consonant after hal — check for conjunct
            pendingHal = false
            
            if enableConjuncts {
                // Check if the last few characters + this form a known conjunct
                let lastChars = buffer.lastNCharacters(2) // [consonant, hal]
                let fullSeq = lastChars + [char]
                
                if let conjunct = mapper.getConjunct(for: fullSeq) {
                    // Replace the consonant + hal with the conjunct glyph
                    let startIdx = buffer.count - 2
                    if let conjunctChar = conjunct.outputChar.first {
                        buffer.replaceRange(startIdx..<buffer.count, with: [conjunctChar])
                        return .updateComposition(buffer.text)
                    }
                }
            }
            
            // No conjunct found — just append the consonant after the hal
            buffer.append(char)
            return .updateComposition(buffer.text)
        }
        
        // Check if we should auto-commit the previous syllable
        if autoCommitOnNewSyllable && shouldCommitBeforeNewConsonant() {
            let commitText = buffer.text
            buffer.clear()
            buffer.append(char)
            return .commitAndStart(commit: commitText, composition: buffer.text)
        }
        
        // Just append the consonant
        buffer.append(char)
        return .updateComposition(buffer.text)
    }
    
    /// Handle the hal/virama marker.
    ///
    /// Hal after a consonant creates a "dead consonant" that may combine
    /// with the next consonant to form a conjunct.
    private func handleHal(_ char: Character) -> ReorderAction {
        if buffer.isEmpty {
            // Hal without a consonant — pass through
            return .passThrough
        }
        
        // Check if the last character is a consonant
        if let lastChar = buffer.lastCharacter, mapper.isConsonant(lastChar) {
            buffer.append(char)
            pendingHal = true
            return .updateComposition(buffer.text)
        }
        
        // Hal after something else — just append
        buffer.append(char)
        pendingHal = false
        return .updateComposition(buffer.text)
    }
    
    /// Handle a post-base vowel sign (appears after/above/below consonant).
    ///
    /// Post-base signs don't need reordering — they stay after the consonant.
    private func handlePostBaseSign(_ char: Character) -> ReorderAction {
        pendingHal = false
        buffer.append(char)
        return .updateComposition(buffer.text)
    }
    
    /// Handle an independent vowel (e.g., අ, ආ, ඉ).
    ///
    /// Independent vowels start a new syllable. If there's an active composition,
    /// commit it first.
    private func handleIndependentVowel(_ char: Character) -> ReorderAction {
        pendingHal = false
        
        if autoCommitOnNewSyllable && !buffer.isEmpty {
            let commitText = buffer.text
            buffer.clear()
            buffer.append(char)
            return .commitAndStart(commit: commitText, composition: buffer.text)
        }
        
        buffer.append(char)
        return .updateComposition(buffer.text)
    }
    
    /// Handle anusvara (ං) or visarga (ඃ).
    ///
    /// These modifiers appear at the end of a syllable. They're appended
    /// to the buffer and may trigger a commit.
    private func handleModifier(_ char: Character) -> ReorderAction {
        pendingHal = false
        buffer.append(char)
        return .updateComposition(buffer.text)
    }
    
    /// Handle rakaransaya (repaya).
    ///
    /// Rakaransaya appears BEFORE the consonant visually (like pre-base signs).
    /// Reorder it before the last consonant.
    private func handleRakaransaya(_ char: Character) -> ReorderAction {
        pendingHal = false
        
        if let consonantIndex = buffer.lastBaseConsonantIndex(using: mapper) {
            buffer.insertBefore(target: consonantIndex, char: char)
        } else {
            buffer.append(char)
        }
        
        return .updateComposition(buffer.text)
    }
    
    /// Handle yansaya.
    ///
    /// Yansaya typically appears after the consonant (post-base).
    private func handleYansaya(_ char: Character) -> ReorderAction {
        pendingHal = false
        buffer.append(char)
        return .updateComposition(buffer.text)
    }
    
    /// Handle a space character.
    ///
    /// Spaces commit the current composition and are passed through.
    private func handleSpace(_ char: Character) -> ReorderAction {
        pendingHal = false
        
        if buffer.isEmpty {
            return .passThrough
        }
        
        if autoCommitOnSpace {
            let commitText = buffer.text + String(char)
            buffer.clear()
            return .commitText(commitText)
        }
        
        buffer.append(char)
        return .updateComposition(buffer.text)
    }
    
    /// Handle punctuation or numbers.
    ///
    /// Punctuation commits the current composition and is passed through.
    private func handlePunctuation(_ char: Character) -> ReorderAction {
        pendingHal = false
        
        if buffer.isEmpty {
            return .passThrough
        }
        
        if autoCommitOnPunctuation {
            let commitText = buffer.text + String(char)
            buffer.clear()
            return .commitText(commitText)
        }
        
        buffer.append(char)
        return .updateComposition(buffer.text)
    }
    
    /// Handle any other unclassified character.
    ///
    /// If there's a composition, commit it first and pass the character through.
    private func handleDefault(_ char: Character) -> ReorderAction {
        pendingHal = false
        
        if !buffer.isEmpty {
            let commitText = buffer.text
            buffer.clear()
            return .commitAndStart(commit: commitText, composition: String(char))
        }
        
        return .passThrough
    }
    
    // MARK: - Private Helpers
    
    /// Determine if we should commit the current buffer before adding a new consonant.
    ///
    /// A new consonant after a completed syllable (consonant + vowel sign) typically
    /// starts a new syllable and should trigger a commit.
    private func shouldCommitBeforeNewConsonant() -> Bool {
        guard !buffer.isEmpty else { return false }
        
        // If the last character is a post-base sign, the syllable is complete
        if let lastChar = buffer.lastCharacter {
            if mapper.isPostBase(lastChar) {
                return true
            }
        }
        
        // Don't commit if the last character is a hal (expecting conjunct)
        if pendingHal {
            return false
        }
        
        return false
    }
}

// MARK: - Split Vowel Support

extension ReorderingEngine {
    
    /// Process a split vowel character.
    ///
    /// Split vowels consist of a left part (before consonant) and a right part (after consonant).
    /// Example: "o" kombuva (ො) = kombuva (ෙ) + consonant + aa-pilla (ා)
    ///
    /// - Parameter entry: The split vowel entry
    /// - Returns: The action to take
    func processSplitVowel(_ entry: SplitVowelEntry) -> ReorderAction {
        pendingHal = false
        
        guard !buffer.isEmpty,
              let consonantIndex = buffer.lastBaseConsonantIndex(using: mapper) else {
            // No consonant — treat left+right as sequential
            if let left = entry.leftPart.first {
                buffer.append(left)
            }
            if let right = entry.rightPart.first {
                buffer.append(right)
            }
            return .updateComposition(buffer.text)
        }
        
        // Insert left part before the consonant
        if let left = entry.leftPart.first {
            buffer.insertBefore(target: consonantIndex, char: left)
        }
        
        // Append right part after the consonant (which has shifted right by 1)
        if let right = entry.rightPart.first {
            buffer.append(right)
        }
        
        return .updateComposition(buffer.text)
    }
}
