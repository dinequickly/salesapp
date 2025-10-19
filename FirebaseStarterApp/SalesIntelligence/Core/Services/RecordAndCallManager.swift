import AVFoundation
import UIKit

final class RecordAndCallManager: NSObject {
    enum ManagerError: Error {
        case permissionDenied
        case cannotConfigureSession
        case notRecording
    }

    private let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var recordingContinuation: CheckedContinuation<(URL, TimeInterval), Error>?
    private var recordingStartDate: Date?
    private var isConfigured = false

    @MainActor
    func start(on previewView: UIView) async throws {
        try await ensurePermissions()
        try configureSessionIfNeeded()
        attachPreview(to: previewView)

        if !captureSession.isRunning {
            captureSession.startRunning()
        }

        guard !movieOutput.isRecording else { return }

        recordingStartDate = Date()
        let outputURL = RecordAndCallManager.makeTemporaryURL()
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
    }

    @MainActor
    func stop() async throws -> (URL, TimeInterval) {
        guard movieOutput.isRecording else { throw ManagerError.notRecording }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, TimeInterval), Error>) in
            recordingContinuation = continuation
            movieOutput.stopRecording()
        }
    }

    @MainActor
    func updatePreviewLayout(in view: UIView) {
        previewLayer?.frame = view.bounds
    }

    private func attachPreview(to view: UIView) {
        if previewLayer == nil {
            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            previewLayer = layer
        }

        if let previewLayer, previewLayer.superlayer !== view.layer {
            previewLayer.frame = view.bounds
            view.layer.insertSublayer(previewLayer, at: 0)
        }
    }

    private func ensurePermissions() async throws {
        let cameraGranted = await RecordAndCallManager.requestCameraAccess()
        let microphoneGranted = await RecordAndCallManager.requestMicrophoneAccess()
        guard cameraGranted && microphoneGranted else {
            throw ManagerError.permissionDenied
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord,
                                     mode: .videoChat,
                                     options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowBluetoothHFP])
        try audioSession.setActive(true)
    }

    private func configureSessionIfNeeded() throws {
        guard !isConfigured else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high

        do {
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                    ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                throw ManagerError.cannotConfigureSession
            }
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            guard captureSession.canAddInput(videoInput) else {
                throw ManagerError.cannotConfigureSession
            }
            captureSession.addInput(videoInput)

            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                guard captureSession.canAddInput(audioInput) else {
                    throw ManagerError.cannotConfigureSession
                }
                captureSession.addInput(audioInput)
            }
        } catch {
            captureSession.commitConfiguration()
            throw ManagerError.cannotConfigureSession
        }

        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        } else {
            captureSession.commitConfiguration()
            throw ManagerError.cannotConfigureSession
        }

        captureSession.commitConfiguration()
        isConfigured = true
    }

    private static func makeTemporaryURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
        let filename = "practice_\(UUID().uuidString).mov"
        return directory.appendingPathComponent(filename)
    }

    private static func requestCameraAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private static func requestMicrophoneAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
}

extension RecordAndCallManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        captureSession.stopRunning()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let duration = recordingStartDate.map { Date().timeIntervalSince($0) } ?? 0
        recordingStartDate = nil

        if let error {
            recordingContinuation?.resume(throwing: error)
        } else {
            recordingContinuation?.resume(returning: (outputFileURL, duration))
        }

        recordingContinuation = nil
    }
}
