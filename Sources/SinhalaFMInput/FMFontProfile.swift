import Foundation

// MARK: - Character Type Classification

/// Classification of characters in the Sinhala writing system.
/// Used to determine reordering behavior for FM font rendering.
enum SinhalaCharType: String, Codable, CaseIterable {
    case consonant          // ක, ග, ච, etc.
    case independentVowel   // අ, ආ, ඉ, etc.
    case preBaseSign        // Signs that visually appear LEFT of consonant (kombuva ෙ, etc.)
    case postBaseSign       // Signs that appear after/above/below consonant (ා, ි, ු, etc.)
    case hal                // Virama / Hal-kirima ්
    case conjunctForm       // Pre-composed conjunct glyph codes
    case rakaransaya        // Rakaransaya form (repaya)
    case yansaya            // Yansaya form
    case touchedForm        // Touching letters (e.g., conjunct ligatures)
    case anusvara           // Anusvara ං
    case visarga            // Visarga ඃ
    case number             // Numerals
    case punctuation        // Punctuation marks
    case space              // Whitespace
    case other              // Unclassified characters
}

// MARK: - Character Entry

/// A single character entry in an FM font mapping profile.
/// Maps a keyboard key (ASCII character) to its Sinhala classification.
struct FMCharacterEntry: Codable {
    /// The keyboard key or ASCII character (e.g., "k", "K", "e")
    let key: String
    
    /// What type of Sinhala character this key produces in the FM font
    let type: SinhalaCharType
    
    /// Transliterated Sinhala name (e.g., "ka", "kombuva")
    let sinhalaName: String
    
    /// Human-readable description of the character
    let description: String
}

// MARK: - Split Vowel Entry

/// Defines a split vowel — a vowel sign that wraps around the consonant.
/// In visual order: [leftPart] + [consonant] + [rightPart]
/// Example: "o" kombuva (ො) = kombuva (ෙ) + consonant + aa-pilla (ා)
struct SplitVowelEntry: Codable {
    /// The keyboard key that triggers this split vowel
    let triggerKey: String
    
    /// ASCII character for the left component (placed before consonant)
    let leftPart: String
    
    /// ASCII character for the right component (placed after consonant)
    let rightPart: String
    
    /// Human-readable description (e.g., "o-kombuva")
    let description: String
}

// MARK: - Conjunct Entry

/// Defines a conjunct — a combined consonant form.
/// When a specific sequence of characters is typed, it may be replaced
/// by a single pre-composed conjunct glyph code.
struct ConjunctEntry: Codable {
    /// The input key sequence that triggers this conjunct
    /// (e.g., ["k", "'", "Y"] for ka + hal + ya)
    let inputSequence: [String]
    
    /// The single output character (conjunct glyph code)
    let outputChar: String
    
    /// Human-readable description
    let description: String
}

// MARK: - FM Font Profile

/// Complete character mapping profile for an FM font.
///
/// FM fonts are legacy, non-Unicode Sinhala fonts that map ASCII character positions
/// to Sinhala glyphs. Each FM font family (FM-Abhaya, FM-MalithiX, etc.) has its own
/// specific character mapping. This profile defines that mapping and the character
/// classifications needed for the reordering engine.
struct FMFontProfile: Codable {
    /// Font family name (e.g., "FM-Abhaya")
    let fontName: String
    
    /// Profile version
    let version: String
    
    /// Description of this profile
    let description: String
    
    /// All character mappings
    let characters: [FMCharacterEntry]
    
    /// Split vowel definitions
    let splitVowels: [SplitVowelEntry]
    
    /// Conjunct definitions
    let conjuncts: [ConjunctEntry]
}

// MARK: - Computed Lookup Tables

extension FMFontProfile {
    
    /// Set of all ASCII characters classified as pre-base signs in this font.
    /// These characters MUST be reordered to appear BEFORE the consonant in the text stream.
    var preBaseChars: Set<Character> {
        Set(characters
            .filter { $0.type == .preBaseSign }
            .compactMap { $0.key.first })
    }
    
    /// Set of all ASCII characters classified as consonants in this font.
    var consonantChars: Set<Character> {
        Set(characters
            .filter { $0.type == .consonant }
            .compactMap { $0.key.first })
    }
    
    /// Set of all ASCII characters classified as post-base signs in this font.
    var postBaseChars: Set<Character> {
        Set(characters
            .filter { $0.type == .postBaseSign }
            .compactMap { $0.key.first })
    }
    
    /// The ASCII character used for hal/virama in this font, if defined.
    var halChar: Character? {
        characters.first { $0.type == .hal }?.key.first
    }
    
    /// Build a lookup dictionary from ASCII character to its Sinhala type.
    var charTypeMap: [Character: SinhalaCharType] {
        var map: [Character: SinhalaCharType] = [:]
        for entry in characters {
            if let ch = entry.key.first {
                map[ch] = entry.type
            }
        }
        return map
    }
    
    /// Build a lookup dictionary for split vowels by trigger key.
    var splitVowelMap: [Character: SplitVowelEntry] {
        var map: [Character: SplitVowelEntry] = [:]
        for entry in splitVowels {
            if let ch = entry.triggerKey.first {
                map[ch] = entry
            }
        }
        return map
    }
    
    /// Build a lookup for conjuncts by their input sequence.
    var conjunctMap: [[Character]: ConjunctEntry] {
        var map: [[Character]: ConjunctEntry] = [:]
        for entry in conjuncts {
            let seq = entry.inputSequence.compactMap { $0.first }
            if seq.count == entry.inputSequence.count {
                map[seq] = entry
            }
        }
        return map
    }
}
