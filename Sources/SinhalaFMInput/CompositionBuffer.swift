import Foundation

// MARK: - Composition Buffer

/// Manages the text being composed before it is committed to the target application.
///
/// The composition buffer holds characters during the composition phase, allowing
/// the reordering engine to rearrange characters (e.g., moving pre-base vowel signs
/// before consonants) before the final text is sent to the application.
///
/// In IMK terms, the contents of this buffer are displayed as "marked text"
/// (underlined text) in the target application.
class CompositionBuffer {
    
    // MARK: - Properties
    
    /// The internal character buffer
    private var buffer: [Character] = []
    
    /// The current composition as a String
    var text: String {
        return String(buffer)
    }
    
    /// Number of characters in the buffer
    var count: Int {
        return buffer.count
    }
    
    /// Whether the buffer is empty
    var isEmpty: Bool {
        return buffer.isEmpty
    }
    
    /// Access the buffer contents as an array (read-only)
    var characters: [Character] {
        return buffer
    }
    
    /// The last character in the buffer, if any
    var lastCharacter: Character? {
        return buffer.last
    }
    
    // MARK: - Basic Operations
    
    /// Append a character to the end of the buffer.
    ///
    /// - Parameter char: The character to append
    func append(_ char: Character) {
        buffer.append(char)
    }
    
    /// Insert a character at a specific index.
    ///
    /// - Parameters:
    ///   - char: The character to insert
    ///   - index: The position to insert at (0-based)
    /// - Precondition: index must be in range 0...buffer.count
    func insert(_ char: Character, at index: Int) {
        guard index >= 0 && index <= buffer.count else { return }
        buffer.insert(char, at: index)
    }
    
    /// Insert a character before the character at the specified index.
    /// This is equivalent to `insert(char, at: targetIndex)`.
    ///
    /// - Parameters:
    ///   - targetIndex: The index of the character to insert before
    ///   - char: The character to insert
    func insertBefore(target targetIndex: Int, char: Character) {
        insert(char, at: targetIndex)
    }
    
    /// Remove and return the last character from the buffer.
    ///
    /// - Returns: The removed character, or nil if the buffer is empty
    @discardableResult
    func removeLast() -> Character? {
        guard !buffer.isEmpty else { return nil }
        return buffer.removeLast()
    }
    
    /// Remove a character at a specific index.
    ///
    /// - Parameter index: The index to remove at
    /// - Returns: The removed character, or nil if index is out of bounds
    @discardableResult
    func remove(at index: Int) -> Character? {
        guard index >= 0 && index < buffer.count else { return nil }
        return buffer.remove(at: index)
    }
    
    /// Clear all characters from the buffer.
    func clear() {
        buffer.removeAll()
    }
    
    // MARK: - Sinhala-Specific Operations
    
    /// Find the index of the last consonant in the buffer.
    ///
    /// This is used when a pre-base vowel sign is typed — we need to find
    /// the consonant it should be placed before.
    ///
    /// - Parameter mapper: The character mapper for classification
    /// - Returns: The index of the last consonant, or nil if none found
    func lastConsonantIndex(using mapper: CharacterMapper) -> Int? {
        for i in stride(from: buffer.count - 1, through: 0, by: -1) {
            if mapper.isConsonant(buffer[i]) {
                return i
            }
        }
        return nil
    }
    
    /// Find the index of the last consonant that is NOT followed by a hal marker.
    /// This is the "base" consonant of the current syllable.
    ///
    /// - Parameter mapper: The character mapper for classification
    /// - Returns: The index of the base consonant, or nil if none found
    func lastBaseConsonantIndex(using mapper: CharacterMapper) -> Int? {
        for i in stride(from: buffer.count - 1, through: 0, by: -1) {
            if mapper.isConsonant(buffer[i]) {
                // Check if this consonant is followed by a hal (making it a dead consonant)
                if i + 1 < buffer.count && mapper.isHal(buffer[i + 1]) {
                    continue // This is a dead consonant (C + hal), skip it
                }
                return i
            }
        }
        return nil
    }
    
    /// Get the last N characters from the buffer.
    ///
    /// - Parameter n: Number of characters to return
    /// - Returns: Array of the last n characters (or fewer if buffer is smaller)
    func lastNCharacters(_ n: Int) -> [Character] {
        let startIndex = max(0, buffer.count - n)
        return Array(buffer[startIndex...])
    }
    
    /// Replace a range of characters in the buffer.
    ///
    /// - Parameters:
    ///   - range: The range to replace
    ///   - chars: The replacement characters
    func replaceRange(_ range: Range<Int>, with chars: [Character]) {
        let clampedStart = max(0, range.lowerBound)
        let clampedEnd = min(buffer.count, range.upperBound)
        guard clampedStart <= clampedEnd else { return }
        buffer.replaceSubrange(clampedStart..<clampedEnd, with: chars)
    }
    
    /// Check if the buffer ends with the given sequence of characters.
    ///
    /// - Parameter sequence: The sequence to check for
    /// - Returns: true if the buffer ends with this sequence
    func endsWith(_ sequence: [Character]) -> Bool {
        guard buffer.count >= sequence.count else { return false }
        let tail = Array(buffer.suffix(sequence.count))
        return tail == sequence
    }
    
    // MARK: - Debug
    
    /// String representation showing character codes for debugging
    var debugDescription: String {
        let codes = buffer.map { char -> String in
            let scalar = char.unicodeScalars.first!
            return "'\(char)'(\(scalar.value))"
        }
        return "CompositionBuffer[\(codes.joined(separator: ", "))]"
    }
}
