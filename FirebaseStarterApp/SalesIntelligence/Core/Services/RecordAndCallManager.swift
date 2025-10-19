import AVFoundation
import UIKit

final class RecordAndCallManager: NSObject {
    enum ManagerError: Error {
        case permissionDenied
        case cannotConfigureSession
        case notRecording
        case cameraUnavailable
    }

    private let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var recordingContinuation: CheckedContinuation<(URL, TimeInterval), Error>?
    private var recordingStartDate: Date?
    private var isConfigured = false
    private var isCancellingRecording = false

    @MainActor
    func start(on previewView: UIView) async throws {
        try await ensurePermissions()
        try configureSessionIfNeeded()
        attachPreview(to: previewView)
        isCancellingRecording = false

        if !captureSession.isRunning {
            captureSession.startRunning()
        }

        guard !movieOutput.isRecording else { return }

        recordingStartDate = Date()
        let outputURL = RecordAndCallManager.makeTemporaryURL()
        if let connection = movieOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
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

    @MainActor
    func cancelRecording() async {
        if movieOutput.isRecording {
            recordingContinuation?.resume(throwing: CancellationError())
            recordingContinuation = nil
            isCancellingRecording = true
            movieOutput.stopRecording()
        } else if captureSession.isRunning {
            captureSession.stopRunning()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        recordingStartDate = nil
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
            guard let videoDevice = RecordAndCallManager.findVideoDevice() else {
                throw ManagerError.cameraUnavailable
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
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private static func findVideoDevice() -> AVCaptureDevice? {
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTrueDepthCamera,
            .builtInWideAngleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInTripleCamera,
            .builtInUltraWideCamera
        ]

        // Prefer any front-facing camera first
        let frontDiscovery = AVCaptureDevice.DiscoverySession(deviceTypes: preferredTypes,
                                                              mediaType: .video,
                                                              position: .front)
        if let front = frontDiscovery.devices.first {
            return front
        }

        // Fall back to any available camera (likely back-facing)
        let anyDiscovery = AVCaptureDevice.DiscoverySession(deviceTypes: preferredTypes,
                                                            mediaType: .video,
                                                            position: .unspecified)
        if let anyDevice = anyDiscovery.devices.first {
            return anyDevice
        }

        return AVCaptureDevice.default(for: .video)
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

        if isCancellingRecording {
            isCancellingRecording = false
            try? FileManager.default.removeItem(at: outputFileURL)
            return
        }

        if let error {
            recordingContinuation?.resume(throwing: error)
        } else {
            recordingContinuation?.resume(returning: (outputFileURL, duration))
        }

        recordingContinuation = nil
    }
}

extension RecordAndCallManager.ManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera or microphone permission is required to record practice sessions."
        case .cannotConfigureSession:
            return "Unable to configure capture session. Please restart the app and try again."
        case .notRecording:
            return "Recording is not active."
        case .cameraUnavailable:
            return "No camera is available. Please run on a device with a camera."
        }
    }
}
