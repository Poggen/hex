import Foundation

extension DictationController {
    func preparePianissimoAtLaunch() -> Bool {
        let settings = PianissimoSettings()
        let loads = ParakeetLoadGuard(model: ParakeetUltraTranscriber.Model.pianissimo.loadGuardKey)
        loads.noteLaunch()
        guard settings.isEnabled else {
            if settings.isTurnedOff { try? FileManager.default.removeItem(at: SpeechModelStore.pianissimo) }
            return false
        }
        if !PianissimoModel.isDownloaded { settings.isModelReady = false }
        if PianissimoModel.isDownloaded && loads.lastLoadWasInterrupted {
            settings.isModelReady = false
            pianissimoDownload.fail(String(localized: "Hex closed while getting Pianissimo ready, likely short of memory."))
        }
        startPianissimoDownloadIfWanted()
        guard let candidate = PianissimoModel.candidate(),
              ParakeetCompileRecord(key: candidate.model.compileKey).isCurrent else { return false }
        prepareModel(candidate: candidate)
        return true
    }

    func startPianissimoDownloadIfWanted() {
        let settings = PianissimoSettings()
        guard settings.isEnabled, MultilingualParakeetSettings.fits(), pianissimoRemoval == nil,
              !PianissimoModel.isDownloaded, !pianissimoDownload.isFailed else { return }
        settings.isModelReady = false
        pianissimoDownload.start()
    }

    /// Returns true when Pianissimo takes Swedish, leaving Parakeet Ultra eligible otherwise.
    func syncPianissimo() -> Bool {
        startPianissimoDownloadIfWanted()
        let settings = PianissimoSettings()
        guard settings.language() != nil, PianissimoModel.isDownloaded else {
            if !pianissimoDownload.isRunning, !pianissimoDownload.isFailed { pianissimoDownload.settle() }
            return false
        }
        if (transcriber as? ParakeetUltraTranscriber)?.model == .pianissimo, isModelReady {
            pianissimoDownload.settle()
            return true
        }
        guard !pianissimoDownload.isFailed else { return false }
        guard let candidate = PianissimoModel.candidate() else {
            settings.isModelReady = false
            pianissimoDownload.fail(String(localized: "Not enough memory for Pianissimo. Hex is using its usual model."))
            return false
        }
        switch phase {
        case .recording, .transcribing, .requestingPermission:
            pendingLanguagePreparation = true
        case .preparingModel:
            break // The preparation in flight will call us again when it finishes.
        case .modelRequired, .ready, .failed:
            prepareModel(candidate: candidate)
        }
        return true
    }

    func setPianissimoEnabled(_ enabled: Bool) {
        let settings = PianissimoSettings()
        guard settings.isEnabled != enabled else { return }
        settings.isEnabled = enabled
        settings.isModelReady = false
        if enabled {
            retryPianissimo()
            return
        }

        // Wait for the transfer before removing its files. A quick re-enable resumes them.
        if pianissimoRemoval == nil {
            pianissimoRemoval = Task {
                await pianissimoDownload.stop()
                if !settings.isEnabled {
                    try? FileManager.default.removeItem(at: SpeechModelStore.pianissimo)
                }
                pianissimoRemoval = nil
                if settings.isEnabled { syncMultilingualParakeet() }
            }
        }
        if engineName == ParakeetUltraTranscriber.Model.pianissimo.name {
            switch phase {
            case .recording, .transcribing, .requestingPermission:
                pendingLanguagePreparation = true
            case .modelRequired, .preparingModel, .ready, .failed:
                prepareModel()
            }
        } else {
            syncMultilingualParakeet()
        }
    }

    func retryPianissimo() {
        ParakeetLoadGuard(model: ParakeetUltraTranscriber.Model.pianissimo.loadGuardKey).forget()
        pianissimoDownload.settle()
        syncMultilingualParakeet()
    }

    func pianissimoFailedToLoad(_ error: Error) {
        let settings = PianissimoSettings()
        settings.isModelReady = false
        guard settings.isEnabled else { return }
        if (error as? ParakeetUltraTranscriber.TranscriberError) == .notDownloaded {
            pianissimoDownload.settle()
            startPianissimoDownloadIfWanted()
            return
        }
        ParakeetLoadGuard(model: ParakeetUltraTranscriber.Model.pianissimo.loadGuardKey).setAside()
        let message = (error as? ParakeetUltraTranscriber.TranscriberError) == .notEnoughMemory
            ? String(localized: "Not enough memory for Pianissimo. Hex is using its usual model.")
            : String(localized: "Pianissimo couldn't get ready. Hex is using its usual model.")
        pianissimoDownload.fail(message)
    }
}
