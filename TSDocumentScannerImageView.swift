//
//  TSDocumentScanner.swift
//  Finja
//
//  Created by Tallha Sarwar on 25/03/2020.
//  Copyright © 2020 Finja Pvt Limited. All rights reserved.
//

import UIKit
import Foundation
import MobileCoreServices
import AVFoundation
import Vision
import VisionKit


protocol TSDocumentChangeProtocol : AnyObject {
    func updatedImageStatus (imageView : TSDocumentScannerImageView)
}

@IBDesignable class TSDocumentScannerImageView: UIImageView, VNDocumentCameraViewControllerDelegate {
    
    var parentController: UIViewController?
    var imageChanged = false
    var statusUpdateDelegate : TSDocumentChangeProtocol?
    
    @IBInspectable var placeholderImage: UIImage? {
        didSet {
            self.image = placeholderImage
        }
    }
    
    @IBInspectable var cornerRadius: CGFloat = 10 {
        didSet {
            refreshCorners(value: cornerRadius)
            layer.cornerRadius = cornerRadius
            
        }
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.isUserInteractionEnabled = true
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(self.imageViewTapped(sender:)))
        self.addGestureRecognizer(singleTap)
        
        self.refreshCorners(value: cornerRadius)
        
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.refreshCorners(value: cornerRadius)
        
    }
    
    func refreshCorners(value: CGFloat) {
        layer.cornerRadius = value
    }
    
    @objc func imageViewTapped(sender: UITapGestureRecognizer){
        
        checkCameraAccess()

    }
    
    func checkCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied:
            print("Denied, request permission from settings")
            presentCameraSettings()
        case .restricted:
            print("Restricted, device owner must approve")
        case .authorized:
            print("Authorized, proceed")
            DispatchQueue.main.async {
                self.scanDocument()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { success in
                if success {
                    print("Permission granted, proceed")
                    DispatchQueue.main.async {
                        self.scanDocument()
                    }
                } else {
                    print("Permission denied")
                }
            }
        @unknown default:
            fatalError()
        }
    }
    
    func presentCameraSettings() {
        
        self.showAlert(withTitle: "Permission required", message: "Camera access is denied please allow to use this functionality", okButton: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: { _ in
                    // Handle
                    self.reloadInputViews()
                })
            }
        }) {
            
        }
    }
    
    func showAlert(withTitle title: String, message : String , okButton success:@escaping () -> () , cancelButton failure:@escaping () -> ())  {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default) { action in
            success()
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { action in
            failure()
        }
        alertController.addAction(OKAction)
        alertController.addAction(cancel)
        
        self.window?.rootViewController?.present(alertController, animated: true, completion: nil)
        
    }
    
    func scanDocument() {
        if #available(iOS 13.0, *) {
            let scannerViewController = VNDocumentCameraViewController()
            scannerViewController.delegate = self
            
            self.parentController?.present(scannerViewController, animated: true)
        } else {
            // Fallback on earlier versions
        }
    }
    
    // MARK: - Scan Handling
    
    private func processImage(_ image: UIImage) {
        self.image = image
        self.imageChanged = true
        self.statusUpdateDelegate?.updatedImageStatus(imageView: self)
    }
    
    // MARK: - VNDocumentCameraViewControllerDelegate

    @available(iOS 13.0, *)
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        // Make sure the user scanned at least one page
        guard scan.pageCount >= 1 else {
            // You are responsible for dismissing the VNDocumentCameraViewController.
            controller.dismiss(animated: true)
            return
        }
        
        // This is a workaround for the VisionKit bug which breaks the `UIImage` returned from `VisionKit`
        // See the `Image Loading Hack` section below for more information.
        let originalImage = scan.imageOfPage(at: 0)
        let fixedImage = reloadedImage(originalImage)
        
        // You are responsible for dismissing the VNDocumentCameraViewController.
        controller.dismiss(animated: true)
        
        // Process the image
        processImage(fixedImage)
    }
    
    @available(iOS 13.0, *)
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        // The VNDocumentCameraViewController failed with an error.
        // For now, we'll print it, but you should handle it appropriately in your app.
        print(error)
        
        // You are responsible for dismissing the VNDocumentCameraViewController.
        controller.dismiss(animated: true)
    }
    
    @available(iOS 13.0, *)
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        // You are responsible for dismissing the VNDocumentCameraViewController.
        controller.dismiss(animated: true)
    }
    
    // MARK: - Image Loading Hack
    
    func reloadedImage(_ originalImage: UIImage) -> UIImage {
        guard let imageData = originalImage.jpegData(compressionQuality: 1),
            let reloadedImage = UIImage(data: imageData) else {
                return originalImage
        }
        return reloadedImage
    }
    
    
}
