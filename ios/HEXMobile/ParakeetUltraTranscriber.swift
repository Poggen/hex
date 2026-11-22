import FluidAudio
import Foundation
import os

/// Downloadable Parakeet v3 models through FluidAudio's decoder in Hex's process.
actor ParakeetUltraTranscriber: LocalTranscribing {
    nonisolated enum Model: Sendable {
        case ultra, pianissimo

        var name: String { self == .pianissimo ? "Pianissimo" : ParakeetUltraTranscriber.name }
        var loadGuardKey: String { self == .pianissimo ? "pianissimo" : ParakeetUltraTranscriber.loadGuardModel }
        var compileKey: String { self == .pianissimo ? "pianissimo.compiledForSystem" : ParakeetUltraTranscriber.compileRecordKey }
        var directory: URL { self == .pianissimo ? SpeechModelStore.pianissimo : ParakeetUltraModel.directory }
        var isDownloaded: Bool {
            if self == .pianissimo { return PianissimoModel.isDownloaded }
            return ParakeetUltraModel.isDownloaded()
        }
    }

    enum TranscriberError: HexDescribedError {
        case notPrepared
        case emptyTranscript
        case notEnoughMemory
        /// Not on the iPhone yet: `ParakeetUltraDownload` gets it beside the usual engine.
        case notDownloaded

        var errorDescription: String? {
            switch self {
            case .notPrepared:
                String(localized: "The multilingual model isn't ready.")
            case .emptyTranscript:
                String(localized: "No speech heard.")
            case .notEnoughMemory:
                String(localized: "Not enough memory for the multilingual model.")
            case .notDownloaded:
                String(localized: "The multilingual model isn't downloaded yet.")
            }
        }
    }

    static let name = "Parakeet Ultra"
    /// After a load that ended Hex (`ParakeetLoadGuard`), beside Try again.
    nonisolated static var setAsideMessage: String {
        String(localized: "Hex closed while getting the multilingual model ready, likely short of memory.")
    }
    /// `ParakeetLoadGuard`'s and `ParakeetCompileRecord`'s keys, apart from V2's.
    static let loadGuardModel = "parakeetUltra"
    static let compileRecordKey = "parakeetUltra.compiledForSystem"

    /// What loading it takes in Hex, as `ParakeetTranscriber.loadMemory` for V2: the encoder
    /// is 594 MB of int8 weights, which the Neural Engine may hold as 16-bit (1.2 GB) before
    /// the A17, then the other three models (a joint four times V2's) and a first transcription.
    nonisolated static let loadMemory: UInt64 = 1_500 << 20

    /// Whether `available` (`os_proc_available_memory`) leaves room to load it. 0 means iOS
    /// didn't say (the simulator).
    nonisolated static func hasRoomToLoad(available: UInt64) -> Bool {
        available == 0 || available >= loadMemory
    }

    nonisolated let model: Model
    nonisolated let displayName: String
    let languageIdentifier: String
    private var manager: AsrManager?

    init(language: String, model: Model = .ultra) {
        self.model = model
        displayName = model.name
        languageIdentifier = language
    }

    var languageName: String {
        SpeechLanguagePicker.displayName(for: languageIdentifier)
    }

    /// The language the experiment dictates in now, or nil for the engine Hex uses without it:
    /// off, an iPhone without the memory, a language it doesn't know, a load that ended Hex
    /// (`ParakeetLoadGuard`, until the experiment is turned off and on), or less memory left
    /// than loading takes (`os_proc_available_memory`, 0 where iOS sets no limit).
    nonisolated static func chosenLanguage(
        language: String? = MultilingualParakeetSettings().language(),
        availableMemory: UInt64 = UInt64(max(0, os_proc_available_memory())),
        setAside: Bool = ParakeetLoadGuard(model: loadGuardModel).lastLoadWasInterrupted
    ) -> String? {
        guard let language, !setAside, hasRoomToLoad(available: availableMemory) else { return nil }
        return language
    }

    /// "632.2 MB", kept on one line.
    nonisolated static var downloadSize: String {
        ByteCountFormatter.string(fromByteCount: ParakeetUltraModel.totalBytes, countStyle: .file)
            .replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    /// Whether Core ML compiled it for this iOS already, so loading it takes seconds rather
    /// than the minute or more of a first load.
    nonisolated static var isCompiled: Bool {
        ParakeetCompileRecord(key: compileRecordKey).isCurrent
    }

    /// Loads the downloaded model; the download itself is `ParakeetUltraDownload`'s, beside
    /// the engine Hex dictates with meanwhile.
    func prepare(
        progressHandler: @escaping @Sendable (ModelPreparationProgress) -> Void
    ) async throws {
        guard manager == nil else { return }
        guard model.isDownloaded else { throw TranscriberError.notDownloaded }

        let compiled = ParakeetCompileRecord(key: model.compileKey)
        let progress = ParakeetProgressFeed(
            ParakeetPreparationProgress(downloads: false, compiledBefore: compiled.isCurrent),
            emit: progressHandler
        )
        let ticker = Task {
            while !Task.isCancelled {
                progress.tick()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        defer { ticker.cancel() }

        // As V2: only the load, where iOS can end Hex short of memory, counts for the guard,
        // and too little left to load it sets it aside for the engine Hex uses without it.
        let loads = ParakeetLoadGuard(model: model.loadGuardKey)
        guard Self.hasRoomToLoad(available: UInt64(max(0, os_proc_available_memory()))) else {
            loads.setAside()
            throw TranscriberError.notEnoughMemory
        }
        loads.begin()
        var loaded = false
        defer { loads.end(loaded: loaded) }
        progress.update { $0.startLoading(at: Date.now.timeIntervalSinceReferenceDate) }
        let models = try ParakeetUltraModel.load(from: model.directory) {
            let now = Date.now.timeIntervalSinceReferenceDate
            progress.update { $0.finishModel(at: now) }
        }
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        self.manager = manager
        loaded = true
        compiled.markCurrent()
        progress.update { $0.finish() }
    }

    func transcribe(_ audioURL: URL) async throws -> String {
        guard let manager else {
            throw TranscriberError.notPrepared
        }
        let decoderLayers = await manager.decoderLayerCount
        var decoderState = TdtDecoderState.make(decoderLayers: decoderLayers)
        let result = try await manager.transcribe(audioURL, decoderState: &decoderState)
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw TranscriberError.emptyTranscript
        }
        return text
    }
}

extension ParakeetUltraTranscriber.TranscriberError: NoSpeechError {
    var meansNoSpeech: Bool { self == .emptyTranscript }
}
