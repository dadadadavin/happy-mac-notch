@preconcurrency import AVFoundation
@preconcurrency import AppKit
import Combine
import SwiftUI

// Background hardware camera session controller (isolated from MainActor)
final class CameraSessionController: @unchecked Sendable {
    let session = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.happymac.notch.cameraSessionQueue", qos: .userInitiated)
    private var isConfigured = false

    func configureAndStart(onStatus: @escaping @Sendable (Bool, String?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            var errorMsg: String? = nil
            if !self.isConfigured {
                errorMsg = self.configureSession()
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            onStatus(self.session.isRunning, errorMsg)
        }
    }

    func stop(onStatus: @escaping @Sendable (Bool) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.session.beginConfiguration()
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            for output in self.session.outputs {
                self.session.removeOutput(output)
            }
            self.session.commitConfiguration()
            self.isConfigured = false
            onStatus(false)
        }
    }

    private func configureSession() -> String? {
        session.beginConfiguration()
        session.sessionPreset = .photo

        let deviceDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .front
        )

        guard let camera = deviceDiscovery.devices.first ?? AVCaptureDevice.default(for: .video) else {
            session.commitConfiguration()
            return "No camera found."
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                photoOutput.maxPhotoQualityPrioritization = .balanced
            }
            session.commitConfiguration()
            isConfigured = true
            return nil
        } catch {
            session.commitConfiguration()
            return "Failed to access camera device: \(error.localizedDescription)"
        }
    }

    func capturePhoto(delegate: PhotoCaptureProcessor) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
}

// Concurrency-safe photo processor passing raw Data (Sendable) across boundaries
final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (Data?) -> Void

    init(completion: @escaping @Sendable (Data?) -> Void) {
        self.completion = completion
        super.init()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let fileData = photo.fileDataRepresentation() else {
            completion(nil)
            return
        }
        completion(fileData)
    }
}

// MainActor view model for camera UI & interaction
@MainActor
public final class CameraManager: ObservableObject {
    public static let shared = CameraManager()

    @Published public var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published public var isSessionRunning: Bool = false
    @Published public var capturedImage: NSImage? = nil
    @Published public var capturedTempURL: URL? = nil
    @Published public var isCountingDown: Bool = false
    @Published public var countdownRemaining: Int = 0
    @Published public var isFlashing: Bool = false
    @Published public var isCapturing: Bool = false
    @Published public var useTimer: Bool = false
    @Published public var isEnlarged: Bool = false
    @Published public var errorMessage: String? = nil

    private let controller = CameraSessionController()
    private var activeProcessor: PhotoCaptureProcessor?

    public var captureSession: AVCaptureSession {
        controller.session
    }

    public init() {
        self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    public func checkPermissionAndStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        self.authorizationStatus = status

        switch status {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self.startSession()
                    }
                }
            }
        case .denied, .restricted:
            self.errorMessage = "Camera access denied. Enable in System Settings."
        @unknown default:
            break
        }
    }

    public func startSession() {
        guard authorizationStatus == .authorized else {
            checkPermissionAndStart()
            return
        }

        controller.configureAndStart { [weak self] running, errorMsg in
            Task { @MainActor in
                guard let self = self else { return }
                self.isSessionRunning = running
                if let err = errorMsg {
                    self.errorMessage = err
                }
            }
        }
    }

    public func stopSession() {
        self.isEnlarged = false
        controller.stop { [weak self] running in
            Task { @MainActor in
                guard let self = self else { return }
                self.isSessionRunning = running
            }
        }
    }

    public func triggerShutter() {
        guard capturedImage == nil, !isCountingDown else { return }

        if useTimer {
            startCountdown()
        } else {
            snapPhoto()
        }
    }

    private func startCountdown() {
        isCountingDown = true
        countdownRemaining = 3

        Task {
            for i in stride(from: 3, through: 1, by: -1) {
                await MainActor.run {
                    self.countdownRemaining = i
                    NSSound(named: "Tink")?.play()
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            await MainActor.run {
                self.isCountingDown = false
                self.snapPhoto()
            }
        }
    }

    private func snapPhoto() {
        guard !isCapturing else { return }
        isCapturing = true

        // Flash visual effect
        withAnimation(.easeOut(duration: 0.15)) {
            self.isFlashing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.25)) {
                self.isFlashing = false
            }
        }

        // Shutter sound
        NSSound(named: "Glass")?.play()

        let processor = PhotoCaptureProcessor { [weak self] photoData in
            Task { @MainActor in
                guard let self = self else { return }
                self.isCapturing = false

                if let data = photoData, let raw = NSImage(data: data) {
                    // Mirror image horizontally so the saved selfie matches the mirror preview
                    let mirrored = raw.mirroredHorizontally()
                    self.capturedImage = mirrored
                    self.saveTempFile(image: mirrored)
                }
                self.activeProcessor = nil
            }
        }

        self.activeProcessor = processor
        self.controller.capturePhoto(delegate: processor)
    }

    public func retake() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.capturedImage = nil
            self.capturedTempURL = nil
            self.isCountingDown = false
        }
        startSession()
    }

    public func copyToClipboard() {
        guard let image = capturedImage else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    public func saveToDownloads() -> URL? {
        guard let image = capturedImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Downloads")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let filename = "NotchSelfie_\(formatter.string(from: Date())).png"
        let targetURL = downloads.appendingPathComponent(filename)

        do {
            try pngData.write(to: targetURL)
            return targetURL
        } catch {
            return nil
        }
    }

    private func saveTempFile(image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("NotchSelfie_\(UUID().uuidString).png")
        try? pngData.write(to: tempURL)
        self.capturedTempURL = tempURL
    }
}

// Horizontal mirroring helper so selfie orientation matches the mirror preview
extension NSImage {
    func mirroredHorizontally() -> NSImage {
        let existingSize = self.size
        let newImage = NSImage(size: existingSize)
        newImage.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: existingSize.width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()
        self.draw(at: .zero, from: NSRect(origin: .zero, size: existingSize), operation: .sourceOver, fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
