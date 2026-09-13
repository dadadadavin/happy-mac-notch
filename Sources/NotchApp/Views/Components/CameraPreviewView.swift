import AVFoundation
import AppKit
import SwiftUI

public struct CameraPreviewView: NSViewRepresentable {
    public let session: AVCaptureSession

    public init(session: AVCaptureSession) {
        self.session = session
    }

    public func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.layer?.cornerRadius = 10
        view.layer?.masksToBounds = true

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        if let conn = previewLayer.connection, conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = true
        }

        view.previewLayer = previewLayer
        view.layer?.addSublayer(previewLayer)
        return view
    }

    public func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        if let conn = nsView.previewLayer?.connection, conn.isVideoMirroringSupported {
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = true
        }
    }
}

public final class CameraPreviewNSView: NSView {
    public var previewLayer: AVCaptureVideoPreviewLayer?

    public override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}
