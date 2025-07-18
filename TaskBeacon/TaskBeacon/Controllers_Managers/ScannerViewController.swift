//
//  ScannerViewController.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/8/25.
//

import AudioToolbox
import AVFoundation
import SwiftUI

// MARK: - Scanner ViewController
class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var focusSquareView: UIView!
    var onScan: ((String) -> Void)?
    var onCancel: (() -> Void)? // ✅ New cancel closure
    var detectedBarcode: String?
    
    private var lastScanTime: Date = Date.distantPast
    private let scanCooldown: TimeInterval = 1.5 // Prevents multiple scans within 1.5 seconds

    private var loadingIndicator: UIActivityIndicatorView! // ✅ Loading Spinner

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLoadingIndicator()
        setupCamera()
        setupCancelButton()
        setupFocusSquare()
        setupFlashButton()
    }
    
    func setupCancelButton() {
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(Constants.cancel, for: .normal)
        
        // Use system colors that adapt to dark/light mode
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.8)
        
        // Add a subtle shadow for better visibility
        cancelButton.layer.shadowColor = UIColor.black.cgColor
        cancelButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        cancelButton.layer.shadowRadius = 4
        cancelButton.layer.shadowOpacity = 0.3
        
        cancelButton.layer.cornerRadius = 10
        cancelButton.frame = CGRect(x: 20, y: 50, width: 100, height: 40)
        cancelButton.addTarget(self, action: #selector(cancelScanner), for: .touchUpInside)
        view.addSubview(cancelButton)
    }

    func setupFlashButton() {
        let flashButton = UIButton(type: .system)
        flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
        
        // Use system colors that adapt to dark/light mode
        flashButton.tintColor = .white
        flashButton.backgroundColor = UIColor.systemGray.withAlphaComponent(0.8)
        
        // Add a subtle shadow for better visibility
        flashButton.layer.shadowColor = UIColor.black.cgColor
        flashButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        flashButton.layer.shadowRadius = 4
        flashButton.layer.shadowOpacity = 0.3
        
        flashButton.layer.cornerRadius = 25
        flashButton.frame = CGRect(x: view.bounds.width - 70, y: 50, width: 50, height: 50)
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        view.addSubview(flashButton)
    }
    
    @objc func cancelScanner() {
        onCancel?() // ✅ Call cancel function
        dismiss(animated: true) // ✅ Close scanner
    }
    
    // MARK: - Setup Loading Indicator
    func setupLoadingIndicator() {
        loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.center = view.center
        loadingIndicator.color = .label
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
    }

    // MARK: - Setup Camera
    func setupCamera() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput

        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            ErrorAlertManager.shared.showCameraError("Failed to initialize camera: \(error.localizedDescription)")
            
            print("❌ Error creating video input: \(error)")
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            ErrorAlertManager.shared.showDataError("❌ Could not add video input")

            print("❌ Could not add video input")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.ean13, .ean8, .upce]
        } else {
            ErrorAlertManager.shared.showDataError("❌ Could not add metadata output")

            print("❌ Could not add metadata output")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()

            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating()
                self.loadingIndicator.removeFromSuperview()
            }
        }
    }

    // MARK: - Focus Square Overlay
    func setupFocusSquare() {
        let size: CGFloat = 200
        let centerX = view.bounds.midX - size / 2
        let centerY = view.bounds.midY - size / 2

        focusSquareView = UIView(frame: CGRect(x: centerX, y: centerY, width: size, height: size))
        focusSquareView.layer.borderColor = UIColor.green.cgColor
        focusSquareView.layer.borderWidth = 2
        focusSquareView.backgroundColor = UIColor.clear
        view.addSubview(focusSquareView)
    }

    // MARK: - Flash Toggle Button
//    func setupFlashButton() {
//        let flashButton = UIButton(type: .system)
//        flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
//        flashButton.tintColor = .label
//        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
//        flashButton.layer.cornerRadius = 25
//        flashButton.frame = CGRect(x: view.bounds.width - 70, y: 50, width: 50, height: 50)
//        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
//        view.addSubview(flashButton)
//    }

    @objc func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = (device.torchMode == .on) ? .off : .on
            device.unlockForConfiguration()
        } catch {
            ErrorAlertManager.shared.showDataError("❌ Error toggling flash: \(error.localizedDescription)")

            print("❌ Error toggling flash: \(error)")
        }
    }

    // MARK: - Handle Barcode Detection
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcodeValue = metadataObject.stringValue else {
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastScanTime) > scanCooldown else {
            print("⚠️ Scan ignored due to cooldown")
            return
        }

        lastScanTime = now
        detectedBarcode = barcodeValue

        // Check if barcode is inside the focus area
        if let transformedObject = previewLayer.transformedMetadataObject(for: metadataObject) as? AVMetadataMachineReadableCodeObject {
            let barcodeBounds = transformedObject.bounds
            if focusSquareView.frame.contains(barcodeBounds) {
                DispatchQueue.main.async {
                    AudioServicesPlaySystemSound(1108)
                    
                    self.captureSession.stopRunning()
                    self.showConfirmationAlert()
                }
            } else {
                ErrorAlertManager.shared.showDataError("⚠️ Barcode detected but outside focus area")

                print("⚠️ Barcode detected but outside focus area")
            }
        }
    }

    // MARK: - Confirmation Alert
    func showConfirmationAlert() {
        let alert = UIAlertController(title: "Confirm Scan", message: "Scanned Barcode: \(detectedBarcode ?? "Unknown")", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { _ in
            self.onScan?(self.detectedBarcode ?? "")
            self.dismiss(animated: true)
        }))

        alert.addAction(UIAlertAction(title: "Rescan", style: .cancel, handler: { _ in
            self.lastScanTime = Date.distantPast
            self.captureSession.startRunning()
        }))

        present(alert, animated: true)
    }

    // MARK: - Tap-to-Focus
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touchPoint = touches.first?.location(in: view) else { return }
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        focus(at: devicePoint)
    }

    func focus(at point: CGPoint) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            
            animateFocusSquare(to: point)

        } catch {
            ErrorAlertManager.shared.showDataError("❌ Error focusing: \(error.localizedDescription)")

            print("❌ Error focusing: \(error)")
        }
    }

    // MARK: - Animate Focus Square
    func animateFocusSquare(to point: CGPoint) {
        let size: CGFloat = 100
        let focusFrame = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)

        DispatchQueue.main.async {
            self.focusSquareView.frame = focusFrame
            self.focusSquareView.layer.borderColor = UIColor.yellow.cgColor
            
            UIView.animate(withDuration: 0.2, animations: {
                self.focusSquareView.alpha = 1
            }) { _ in
                UIView.animate(withDuration: 0.3, delay: 0.8, options: [], animations: {
                    self.focusSquareView.alpha = 0
                })
            }
        }
    }
}
