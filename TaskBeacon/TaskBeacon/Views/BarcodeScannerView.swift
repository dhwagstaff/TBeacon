//
//  BarcodeScannerView.swift
//  TaskBeacon
//
//  Created by Dean Wagstaff on 3/7/25.
//

import AVFoundation
import SwiftUI

struct BarcodeScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    var onCancel: (() -> Void)?  // ✅ New cancel closure

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: BarcodeScannerView

        init(parent: BarcodeScannerView) {
            self.parent = parent
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let scannerVC = ScannerViewController()
        scannerVC.onScan = onScan
        scannerVC.onCancel = onCancel
        return scannerVC
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}



