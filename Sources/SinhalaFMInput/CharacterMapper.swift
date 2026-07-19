import Foundation

// MARK: - Character Mapper

/// Manages FM font character profiles and provides fast character classification.
///
/// The CharacterMapper loads a font profile (from JSON) and builds internal lookup
/// tables for O(1) character classification. This is critical for real-time keystroke
/// processing — every keystroke must be classified instantly.
///
/// Usage:
/// ```swift
/// try CharacterMapper.shared.loadProfile(named: "fm_abhaya_map")
/// let type = CharacterMapper.shared.classify("k") // → .consonant
/// let isPreBase = CharacterMapper.shared.isPreBase("e") // → true
/// ```
class CharacterMapper {
    
    // MARK: - Singleton
    
    static let shared = CharacterMapper()
    
    // MARK: - Properties
    
    /// The currently active font profile
    private(set) var activeProfile: FMFontProfile?
    
    /// Cached lookup tables for fast classification
    private var charTypeCache: [Character: SinhalaCharType] = [:]
    private var preBaseCache: Set<Character> = []
    private var consonantCache: Set<Character> = []
    private var postBaseCache: Set<Character> = []
    private var splitVowelCache: [Character: SplitVowelEntry] = [:]
    private var conjunctCache: [[Character]: ConjunctEntry] = [:]
    private var halCharacter: Character? = nil
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Profile Loading
    
    /// Load a font profile from the app bundle by name.
    ///
    /// - Parameter name: The resource name (without .json extension)
    /// - Throws: `MapperError.profileNotFound` if the resource doesn't exist
    func loadProfile(named name: String) throws {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw MapperError.profileNotFound(name)
        }
        try loadProfile(from: url)
    }
    
    /// Load a font profile from a specific file URL.
    ///
    /// - Parameter url: The URL of the JSON profile file
    /// - Throws: Decoding errors if the JSON is malformed
    func loadProfile(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let profile = try JSONDecoder().decode(FMFontProfile.self, from: data)
        setProfile(profile)
    }
    
    /// Load a font profile from raw JSON data.
    ///
    /// - Parameter data: The JSON data
    /// - Throws: Decoding errors if the JSON is malformed
    func loadProfile(from data: Data) throws {
        let profile = try JSONDecoder().decode(FMFontProfile.self, from: data)
        setProfile(profile)
    }
    
    /// Directly set a font profile (useful for testing).
    ///
    /// - Parameter profile: The font profile to activate
    func setProfile(_ profile: FMFontProfile) {
        activeProfile = profile
        rebuildCaches(from: profile)
    }
    
    // MARK: - Character Classification
    
    /// Classify a character according to the active font profile.
    ///
    /// - Parameter char: The ASCII character to classify
    /// - Returns: The Sinhala character type, or `.other` if not found
    func classify(_ char: Character) -> SinhalaCharType {
        return charTypeCache[char] ?? .other
    }
    
    /// Check if a character is a pre-base sign (needs reordering before consonant).
    ///
    /// - Parameter char: The character to check
    /// - Returns: `true` if this character must be placed before the consonant
    func isPreBase(_ char: Character) -> Bool {
        return preBaseCache.contains(char)
    }
    
    /// Check if a character is a consonant.
    func isConsonant(_ char: Character) -> Bool {
        return consonantCache.contains(char)
    }
    
    /// Check if a character is a post-base sign (appears after consonant).
    func isPostBase(_ char: Character) -> Bool {
        return postBaseCache.contains(char)
    }
    
    /// Check if a character is the hal/virama marker.
    func isHal(_ char: Character) -> Bool {
        guard let hal = halCharacter else { return false }
        return char == hal
    }
    
    /// Check if a character triggers a split vowel.
    func isSplitVowel(_ char: Character) -> Bool {
        return splitVowelCache[char] != nil
    }
    
    /// Get the split vowel entry for a character, if one exists.
    func getSplitVowel(for char: Character) -> SplitVowelEntry? {
        return splitVowelCache[char]
    }
    
    /// Look up a conjunct form for a given input sequence.
    func getConjunct(for sequence: [Character]) -> ConjunctEntry? {
        return conjunctCache[sequence]
    }
    
    /// Check if a character is a "content" character (consonant, vowel, or sign)
    /// as opposed to a structural character (space, punctuation).
    func isContentCharacter(_ char: Character) -> Bool {
        let type = classify(char)
        switch type {
        case .consonant, .independentVowel, .preBaseSign, .postBaseSign,
             .hal, .conjunctForm, .rakaransaya, .yansaya, .touchedForm,
             .anusvara, .visarga:
            return true
        default:
            return false
        }
    }
    
    /// The name of the currently loaded font profile.
    var currentProfileName: String {
        return activeProfile?.fontName ?? "None"
    }
    
    /// Whether a profile is currently loaded.
    var hasProfile: Bool {
        return activeProfile != nil
    }
    
    // MARK: - Private Methods
    
    /// Rebuild all lookup caches from a profile for O(1) classification.
    private func rebuildCaches(from profile: FMFontProfile) {
        charTypeCache = profile.charTypeMap
        preBaseCache = profile.preBaseChars
        consonantCache = profile.consonantChars
        postBaseCache = profile.postBaseChars
        splitVowelCache = profile.splitVowelMap
        conjunctCache = profile.conjunctMap
        halCharacter = profile.halChar
    }
    
    // MARK: - Error Types
    
    enum MapperError: Error, LocalizedError {
        case profileNotFound(String)
        case invalidProfile(String)
        
        var errorDescription: String? {
            switch self {
            case .profileNotFound(let name):
                return "Font profile '\(name)' not found in bundle resources. " +
                       "Ensure the JSON file is included in the app bundle."
            case .invalidProfile(let reason):
                return "Invalid font profile: \(reason)"
            }
        }
    }
}
