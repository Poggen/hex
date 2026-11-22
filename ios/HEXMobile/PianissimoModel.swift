import Foundation

/// Magnus Hjelm's 8-bit Core ML export of Klang Pianissimo, CC BY 4.0.
nonisolated enum PianissimoModel {
    static let repository = "magnushjelm/pianissimo-sv-coreml"

    static var baseURL: String {
        #if DEBUG
        if let base = ProcessInfo.processInfo.environment["HEX_PIANISSIMO_MODEL_BASE"], !base.isEmpty {
            return base
        }
        #endif
        return "https://huggingface.co/\(repository)/resolve/\(SpeechModelStore.pianissimoRevision)"
    }

    static let files: [ParakeetUltraModel.File] = [
        .init(path: "Decoder.mlmodelc/analytics/coremldata.bin", size: 243,
              sha256: "71ee87b9dc76636c55797ae5ba569768bfd8d81f70760ff363380a20165faaaa"),
        .init(path: "Decoder.mlmodelc/coremldata.bin", size: 565,
              sha256: "44c777d0f545b07d86a2f9f764eadf3f2105930b3b9bef7a76c3a09707ec0e30"),
        .init(path: "Decoder.mlmodelc/metadata.json", size: 3_429,
              sha256: "6917a5b3c44b8e1b59fc2540d963bc17816efa0469dba2955d563b13d981aa56"),
        .init(path: "Decoder.mlmodelc/model.mil", size: 13_110,
              sha256: "34bd2cc0a00dd7a485f0aa90f58d6b516c94ee8f4842de92aad7b581849df289"),
        .init(path: "Decoder.mlmodelc/weights/weight.bin", size: 23_604_992,
              sha256: "9e34a5cc5da3477cf0e49126f55d4754a6a332b5df52a22812d6ddbd84af0e39"),
        .init(path: "Encoder.mlmodelc/analytics/coremldata.bin", size: 243,
              sha256: "5ba634cfa9d2dfe8068b1139802837fa150f6705f87626d723e155fb8e3d4868"),
        .init(path: "Encoder.mlmodelc/coremldata.bin", size: 500,
              sha256: "a3f2bc5cdb7fbe2490addfeab6b02d0df52c072841f5b7928d402e50278556a8"),
        .init(path: "Encoder.mlmodelc/metadata.json", size: 2_937,
              sha256: "982b6dcc39e5700b92153f638a69e1124e3e52a4f549adb3d7ca99e33d7bb987"),
        .init(path: "Encoder.mlmodelc/model.mil", size: 960_233,
              sha256: "89878c7de37f07c32e0a83dc31e6405ef666d03c3d5477e25a57086b5364270e"),
        .init(path: "Encoder.mlmodelc/weights/weight.bin", size: 593_445_952,
              sha256: "adb71a2b3f7fea1c93f9f2906cd0176794388c5d635e17de4f65798bd3221af9"),
        .init(path: "JointDecisionv3.mlmodelc/analytics/coremldata.bin", size: 243,
              sha256: "68daea88123bb1bed958df781aed9b18829c4d29bf27db2a950ff98c03214890"),
        .init(path: "JointDecisionv3.mlmodelc/coremldata.bin", size: 597,
              sha256: "7497800778965aea71234f8fd329ec56279478fadc10bca5e028822d7ed31f21"),
        .init(path: "JointDecisionv3.mlmodelc/metadata.json", size: 3_573,
              sha256: "0ae2453e73dd53564d051b88874602a96015030f4e0de39d410a7fb3a4f2c321"),
        .init(path: "JointDecisionv3.mlmodelc/model.mil", size: 11_777,
              sha256: "167357ff6d558349e745047c6e3f610010d047ec21ab6f56df2dbb041f096baa"),
        .init(path: "JointDecisionv3.mlmodelc/weights/weight.bin", size: 12_642_764,
              sha256: "1f841daf3a6ce483ac136cd7a5e48d6071543e7c5eddcbba4525bda74695cb61"),
        .init(path: "Preprocessor.mlmodelc/analytics/coremldata.bin", size: 243,
              sha256: "c9beeb989c8d66f8be11df59bc6df277ec76cee404f6865b46243835ef562f6d"),
        .init(path: "Preprocessor.mlmodelc/coremldata.bin", size: 486,
              sha256: "dbde3f2300842c1fd51ef3ff948a0bcffe65ffd2dca10707f2509f32c1d65b1d"),
        .init(path: "Preprocessor.mlmodelc/metadata.json", size: 2_841,
              sha256: "2a98699e22d279dd37fa1d238aeb1c6db1df0d6fad687775324157689d8f3acf"),
        .init(path: "Preprocessor.mlmodelc/model.mil", size: 28_181,
              sha256: "4b8518a956450fec57f06c2a21bdffc26973f7f1fa6842fb38fe917f896b6b93"),
        .init(path: "Preprocessor.mlmodelc/weights/weight.bin", size: 491_072,
              sha256: "129b76e3aeafa8afa3ea76d995b964b145fe83700d579f6ff42c4c38fa0968ea"),
        .init(path: "parakeet_vocab.json", size: 151_122,
              sha256: "7ec60e05f1b24480736ec0eed40900f4626bce1fa9a60fd700ec7e2a59198735"),
    ]

    static let totalBytes = files.reduce(Int64(0)) { $0 + $1.size }

    static var isDownloaded: Bool {
        ParakeetUltraModel.isDownloaded(in: SpeechModelStore.pianissimo, files: files)
    }

    @MainActor static func makeDownload() -> ParakeetUltraDownload {
        ParakeetUltraDownload(directory: SpeechModelStore.pianissimo, files: files, base: baseURL, isPianissimo: true)
    }

    static func candidate() -> ParakeetUltraTranscriber? {
        guard let language = PianissimoSettings().language(), isDownloaded,
              !ParakeetLoadGuard(model: ParakeetUltraTranscriber.Model.pianissimo.loadGuardKey).lastLoadWasInterrupted,
              ParakeetUltraTranscriber.hasRoomToLoad(available: UInt64(max(0, os_proc_available_memory()))) else { return nil }
        return ParakeetUltraTranscriber(language: language, model: .pianissimo)
    }
}
