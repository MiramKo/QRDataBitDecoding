//MIT License
//Copyright (c) 2021 Mikhail Kostrov (MiramKo)
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

import UIKit
import AVFoundation

final class ViewController: UIViewController {
    @IBOutlet weak var previewBox: UIView!
    @IBOutlet weak var resultsTextView: UITextView!
    @IBOutlet weak var startStopButton: UIButton!
    
    private var captureSession = AVCaptureSession()
    private var previewLayer = AVCaptureVideoPreviewLayer()

    @IBAction func scanButtonTapped(_ sender: Any) {
        if !captureSession.isRunning {
            (sender as? UIButton)?.setTitle("Stop", for: .normal)
            captureSession.startRunning()
        } else {
            (sender as? UIButton)?.setTitle("Start", for: .normal)
            captureSession.stopRunning()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard
            let videoCaptureDevice = AVCaptureDevice.default(for: .video),
            let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }
        
        let metaDataOutput = AVCaptureMetadataOutput()
        captureSession.addInput(videoInput)
        captureSession.addOutput(metaDataOutput)
        
        metaDataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.global(qos: .userInitiated))
        metaDataOutput.metadataObjectTypes = [.qr]
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = previewBox.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewBox.layer.addSublayer(previewLayer)
        
        let test = String.Encoding.utf8
        print(test.rawValue)
        
        captureSession.startRunning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = previewBox.bounds
    }
}


extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        DispatchQueue.main.async { [weak self] in
            self?.startStopButton.setTitle("Start", for: .normal)
        }
        //descriptor is a raw QR data wich encoded in numeric, alphanumeric, byte etc
        guard
            let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let descriptor = readableObject.descriptor as? CIQRCodeDescriptor,
            let stringValue = QRRawDataParser(with: descriptor.errorCorrectedPayload, qrVersion: descriptor.symbolVersion).getDecodedString() else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.resultsTextView.text = stringValue
        }
    }
}
