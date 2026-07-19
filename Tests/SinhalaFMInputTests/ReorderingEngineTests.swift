import XCTest
@testable import SinhalaFMInput

// MARK: - Reordering Engine Tests

/// Unit tests for the ReorderingEngine.
///
/// These tests verify the core reordering logic that makes FM font input work correctly.
/// They use a minimal test profile rather than the full FM-Abhaya mapping.
///
/// Test Character Assignments (for test profile):
///   k, g, p, b, n = consonants
///   e, E          = pre-base signs (kombuva, diga-kombuva)
///   a, i          = post-base signs (aela-pilla, is-pilla)
///   '             = hal (virama)
///   (space)       = space
///   .             = punctuation
final class ReorderingEngineTests: XCTestCase {
    
    var engine: ReorderingEngine!
    var mapper: CharacterMapper!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        mapper = CharacterMapper()
        
        // Create a minimal test profile
        let testProfile = FMFontProfile(
            fontName: "TestFont",
            version: "1.0",
            description: "Minimal test profile",
            characters: [
                // Consonants
                FMCharacterEntry(key: "k", type: .consonant, sinhalaName: "ka", description: "ka"),
                FMCharacterEntry(key: "g", type: .consonant, sinhalaName: "ga", description: "ga"),
                FMCharacterEntry(key: "p", type: .consonant, sinhalaName: "pa", description: "pa"),
                FMCharacterEntry(key: "b", type: .consonant, sinhalaName: "ba", description: "ba"),
                FMCharacterEntry(key: "n", type: .consonant, sinhalaName: "na", description: "na"),
                
                // Pre-base signs (MUST be reordered before consonant)
                FMCharacterEntry(key: "e", type: .preBaseSign, sinhalaName: "kombuva", description: "e-kombuva"),
                FMCharacterEntry(key: "E", type: .preBaseSign, sinhalaName: "diga-kombuva", description: "ee-kombuva"),
                
                // Post-base signs
                FMCharacterEntry(key: "a", type: .postBaseSign, sinhalaName: "aela-pilla", description: "aa-sign"),
                FMCharacterEntry(key: "i", type: .postBaseSign, sinhalaName: "is-pilla", description: "i-sign"),
                
                // Hal
                FMCharacterEntry(key: "'", type: .hal, sinhalaName: "hal", description: "hal-kirima"),
                
                // Space
                FMCharacterEntry(key: " ", type: .space, sinhalaName: "space", description: "space"),
                
                // Punctuation
                FMCharacterEntry(key: ".", type: .punctuation, sinhalaName: "period", description: "period"),
                
                // Independent vowel
                FMCharacterEntry(key: "u", type: .independentVowel, sinhalaName: "a", description: "ayanna"),
            ],
            splitVowels: [
                SplitVowelEntry(
                    triggerKey: "&",
                    leftPart: "e",
                    rightPart: "a",
                    description: "o-kombuva split vowel"
                )
            ],
            conjuncts: [
                ConjunctEntry(
                    inputSequence: ["k", "'", "k"],
                    outputChar: "@",
                    description: "kka conjunct"
                )
            ]
        )
        
        mapper.setProfile(testProfile)
        engine = ReorderingEngine(mapper: mapper)
    }
    
    override func tearDown() {
        engine = nil
        mapper = nil
        super.tearDown()
    }
    
    // MARK: - Basic Consonant Tests
    
    /// A single consonant should be added to the composition buffer.
    func testSingleConsonantAddsToComposition() {
        let action = engine.processCharacter("k")
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "k", "Single consonant should be in composition")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    /// Multiple consonants typed sequentially should all be in the buffer.
    func testMultipleConsonantsInComposition() {
        _ = engine.processCharacter("k")
        let action = engine.processCharacter("n")
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "kn", "Multiple consonants should accumulate")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    // MARK: - Pre-Base Vowel Reordering Tests (CRITICAL)
    
    /// CORE TEST: Pre-base sign typed after consonant should be reordered BEFORE it.
    /// This is the primary raison d'être of this input method.
    func testPreBaseReorderingAfterConsonant() {
        _ = engine.processCharacter("k")  // Buffer: [k]
        let action = engine.processCharacter("e")  // Should become: [e, k]
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "ek",
                "Pre-base 'e' should be reordered BEFORE consonant 'k'")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    /// Pre-base sign after multiple consonants should only reorder with the LAST one.
    func testPreBaseReorderingWithMultipleConsonants() {
        _ = engine.processCharacter("k")  // Buffer: [k]
        _ = engine.processCharacter("n")  // Buffer: [k, n]
        let action = engine.processCharacter("e")  // Should become: [k, e, n]
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "ken",
                "Pre-base should reorder before LAST consonant only: k + e + n")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    /// Diga kombuva (long E) should also reorder correctly.
    func testDigaKombuvaReordering() {
        _ = engine.processCharacter("p")  // Buffer: [p]
        let action = engine.processCharacter("E")  // Should become: [E, p]
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "Ep",
                "Diga kombuva 'E' should be reordered before consonant 'p'")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    /// Pre-base sign with no preceding consonant should just append.
    func testPreBaseWithNoConsonant() {
        let action = engine.processCharacter("e")  // Buffer empty → just append
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "e",
                "Pre-base with no consonant should just append")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    // MARK: - Post-Base Sign Tests
    
    /// Post-base signs should NOT be reordered — they stay after the consonant.
    func testPostBaseStaysAfterConsonant() {
        _ = engine.processCharacter("k")  // Buffer: [k]
        let action = engine.processCharacter("a")  // Buffer: [k, a]
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "ka",
                "Post-base 'a' should stay AFTER consonant 'k'")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    // MARK: - Hal / Virama Tests
    
    /// Hal after consonant should be added to the buffer.
    func testHalAfterConsonant() {
        _ = engine.processCharacter("k")
        let action = engine.processCharacter("'")
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "k'",
                "Hal should be appended after consonant")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    /// Consonant + hal + consonant sequence should work for conjuncts.
    func testConjunctFormation() {
        _ = engine.processCharacter("k")  // [k]
        _ = engine.processCharacter("'")  // [k, ']
        let action = engine.processCharacter("k")  // Should become [@] (conjunct)
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "@",
                "k + hal + k should produce conjunct '@'")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    /// Consonant + hal + different consonant (no conjunct defined) should stay as sequence.
    func testNonConjunctSequence() {
        _ = engine.processCharacter("k")  // [k]
        _ = engine.processCharacter("'")  // [k, ']
        let action = engine.processCharacter("g")  // [k, ', g] — no conjunct for k'g
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "k'g",
                "Unknown conjunct sequence should stay as-is")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    // MARK: - Space and Commit Tests
    
    /// Space should commit the current composition.
    func testSpaceCommitsComposition() {
        _ = engine.processCharacter("k")
        _ = engine.processCharacter("a")
        let action = engine.processCharacter(" ")
        
        if case .commitText(let text) = action {
            XCTAssertEqual(text, "ka ",
                "Space should commit composition with the space included")
        } else {
            XCTFail("Expected .commitText, got \(action)")
        }
        
        // Engine should be reset
        XCTAssertFalse(engine.hasComposition, "Buffer should be empty after commit")
    }
    
    /// Space with empty buffer should pass through.
    func testSpaceWithEmptyBuffer() {
        let action = engine.processCharacter(" ")
        
        if case .passThrough = action {
            // Expected
        } else {
            XCTFail("Expected .passThrough for space with empty buffer, got \(action)")
        }
    }
    
    /// Punctuation should commit the composition.
    func testPunctuationCommitsComposition() {
        _ = engine.processCharacter("k")
        let action = engine.processCharacter(".")
        
        if case .commitText(let text) = action {
            XCTAssertEqual(text, "k.",
                "Punctuation should commit composition with the punctuation")
        } else {
            XCTFail("Expected .commitText, got \(action)")
        }
    }
    
    // MARK: - Delete Tests
    
    /// Delete should remove the last character from the composition.
    func testDeleteRemovesLastCharacter() {
        _ = engine.processCharacter("k")
        _ = engine.processCharacter("a")
        let action = engine.processDelete()
        
        if case .delete(let remaining) = action {
            XCTAssertEqual(remaining, "k",
                "Delete should remove last character, leaving 'k'")
        } else {
            XCTFail("Expected .delete, got \(action)")
        }
    }
    
    /// Delete on empty buffer should pass through.
    func testDeleteOnEmptyBuffer() {
        let action = engine.processDelete()
        
        if case .passThrough = action {
            // Expected
        } else {
            XCTFail("Expected .passThrough for delete on empty buffer, got \(action)")
        }
    }
    
    /// Delete that empties the buffer should return nil remaining.
    func testDeleteEmptiesBuffer() {
        _ = engine.processCharacter("k")
        let action = engine.processDelete()
        
        if case .delete(let remaining) = action {
            XCTAssertNil(remaining,
                "Delete that empties buffer should return nil remaining")
        } else {
            XCTFail("Expected .delete, got \(action)")
        }
    }
    
    // MARK: - Split Vowel Tests
    
    /// Split vowel should insert left part before consonant and right part after.
    func testSplitVowelReordering() {
        _ = engine.processCharacter("k")  // Buffer: [k]
        
        // Create the split vowel entry manually (simulating what processCharacter would do)
        let splitEntry = SplitVowelEntry(
            triggerKey: "&",
            leftPart: "e",
            rightPart: "a",
            description: "o-kombuva"
        )
        let action = engine.processSplitVowel(splitEntry)  // Should become: [e, k, a]
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "eka",
                "Split vowel should produce: left + consonant + right")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    // MARK: - Force Commit Tests
    
    /// Force commit should return the buffer text and clear it.
    func testForceCommit() {
        _ = engine.processCharacter("k")
        _ = engine.processCharacter("a")
        
        let committed = engine.forceCommit()
        XCTAssertEqual(committed, "ka", "Force commit should return buffer contents")
        XCTAssertFalse(engine.hasComposition, "Buffer should be empty after force commit")
    }
    
    /// Force commit on empty buffer should return nil.
    func testForceCommitEmptyBuffer() {
        let committed = engine.forceCommit()
        XCTAssertNil(committed, "Force commit on empty buffer should return nil")
    }
    
    // MARK: - Independent Vowel Tests
    
    /// Independent vowel after composition should commit previous and start new.
    func testIndependentVowelCommitsPrevious() {
        _ = engine.processCharacter("k")
        _ = engine.processCharacter("a")
        let action = engine.processCharacter("u")  // Independent vowel
        
        if case .commitAndStart(let commit, let composition) = action {
            XCTAssertEqual(commit, "ka", "Previous syllable should be committed")
            XCTAssertEqual(composition, "u", "New composition should start with the vowel")
        } else {
            XCTFail("Expected .commitAndStart, got \(action)")
        }
    }
    
    // MARK: - Complex Sequence Tests
    
    /// Full syllable: consonant + pre-base + post-base
    func testFullSyllableWithPreBase() {
        _ = engine.processCharacter("k")  // [k]
        _ = engine.processCharacter("e")  // [e, k]  (reordered)
        let action = engine.processCharacter("a")  // [e, k, a]
        
        if case .updateComposition(let text) = action {
            XCTAssertEqual(text, "eka",
                "Full syllable should be: pre-base + consonant + post-base")
        } else {
            XCTFail("Expected .updateComposition, got \(action)")
        }
    }
    
    /// Reset should clear everything.
    func testReset() {
        _ = engine.processCharacter("k")
        _ = engine.processCharacter("a")
        engine.reset()
        
        XCTAssertFalse(engine.hasComposition, "Buffer should be empty after reset")
        XCTAssertEqual(engine.compositionText, "", "Composition text should be empty after reset")
    }
}
