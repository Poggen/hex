import Foundation

/// Experiments › Swedish dictation (Pianissimo), shared with the keyboard.
nonisolated struct PianissimoSettings {
    static let enabledKey = "experiments.pianissimo"
    static let readyKey = "experiments.pianissimo.ready"

    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: KeyboardBridge.appGroup)) {
        self.defaults = defaults
    }

    var isEnabled: Bool {
        get { defaults?.bool(forKey: Self.enabledKey) ?? false }
        nonmutating set { defaults?.set(newValue, forKey: Self.enabledKey) }
    }

    var isTurnedOff: Bool {
        defaults?.object(forKey: Self.enabledKey) as? Bool == false
    }

    var isModelReady: Bool {
        get { defaults?.bool(forKey: Self.readyKey) ?? false }
        nonmutating set { defaults?.set(newValue, forKey: Self.readyKey) }
    }

    func language(
        set: String? = LanguageSettings().dictationLanguage,
        keyboard: String? = LanguageSettings().keyboardDictationLanguage(),
        preferred: [String] = Locale.preferredLanguages,
        physicalMemory: UInt64 = ProcessInfo.processInfo.physicalMemory
    ) -> String? {
        guard isEnabled, MultilingualParakeetSettings.fits(physicalMemory: physicalMemory),
              let wanted = set ?? keyboard ?? preferred.first,
              Locale(identifier: wanted).language.languageCode?.identifier == "sv" else { return nil }
        return wanted
    }

    func keyboardOpensHex(language: String?) -> Bool {
        isEnabled && isModelReady && language != nil
    }
}
