//
//  ARViewController.swift
//  DrawAR
//
//  Created by Finn Voorhees on 10/05/2021.
//

import UIKit
import ARKit
import MultipeerConnectivity

class ARViewController: UIViewController, ARSessionDelegate {
    @IBOutlet var arView: ARSCNView!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sendMapButton: UIButton!
    @IBOutlet weak var sessionInfoView: UIVisualEffectView!
    @IBOutlet weak var colorWellView: UIView!
    
    let drawingDistance: Float = 0.2
    let strokeWidth: CGFloat = 0.002
    
    private var shouldDraw = false
    private var previousPosition: SCNVector3?
    private var selectedColor: UIColor = .red
    
    private var multipeerSession: MultipeerSession!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.button.layer.cornerRadius = self.button.frame.width / 2
        self.button.layer.masksToBounds = false
        
        self.button.layer.shadowColor = UIColor.black.cgColor
        self.button.layer.shadowOpacity = 0.5
        self.button.layer.shadowRadius = 5
        self.button.layer.shadowOffset = CGSize(width: 2, height: 2)
        
        self.sendMapButton.layer.cornerRadius = self.sendMapButton.frame.width / 2
        self.sendMapButton.layer.masksToBounds = false
        
        self.sendMapButton.layer.shadowColor = UIColor.black.cgColor
        self.sendMapButton.layer.shadowOpacity = 0.5
        self.sendMapButton.layer.shadowRadius = 5
        self.sendMapButton.layer.shadowOffset = CGSize(width: 2, height: 2)
        self.arView.delegate = self
        
        let colorWell = UIColorWell(frame: self.colorWellView.bounds)
        colorWell.selectedColor = self.selectedColor
        colorWell.addTarget(self, action: #selector(self.colorWellChanged(_:)), for: .valueChanged)
        self.colorWellView.addSubview(colorWell)
        
        self.multipeerSession = MultipeerSession(receivedDataHandler: self.receivedData)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        self.arView.session.run(configuration)
        self.arView.automaticallyUpdatesLighting = false
        self.arView.session.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's AR session.
        self.arView.session.pause()
    }
    
    @IBAction func colorWellChanged(_ sender: UIColorWell) {
        self.selectedColor = sender.selectedColor ?? .red
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        switch frame.worldMappingStatus {
        case .notAvailable, .limited:
            self.sendMapButton.isEnabled = false
        case .extending:
            self.sendMapButton.isEnabled = !self.multipeerSession.connectedPeers.isEmpty
        case .mapped:
            self.sendMapButton.isEnabled = !self.multipeerSession.connectedPeers.isEmpty
        @unknown default:
            self.sendMapButton.isEnabled = false
        }
//        mappingStatusLabel.text = frame.worldMappingStatus.description
        self.updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    var mapProvider: MCPeerID?
    func receivedData(_ data: Data, from peer: MCPeerID) {
        if let worldMap = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
            // Run the session with the received world map.
            let configuration = ARWorldTrackingConfiguration()
            configuration.isLightEstimationEnabled = true
            configuration.initialWorldMap = worldMap
            self.arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            
            // Remember who provided the map for showing UI feedback.
            self.mapProvider = peer
        }
        else if let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
            // Add anchor to the session, ARSCNView delegate adds visible content.
            self.arView.session.add(anchor: anchor)
        }
        else {
            print("unknown data recieved from \(peer)")
        }
    }
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty && multipeerSession.connectedPeers.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move around to map the environment, or wait to join a shared session."
            
        case .normal where !multipeerSession.connectedPeers.isEmpty && mapProvider == nil:
            let peerNames = multipeerSession.connectedPeers.map({ $0.displayName }).joined(separator: ", ")
            message = "Connected with \(peerNames)."
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing) where mapProvider != nil,
             .limited(.relocalizing) where mapProvider != nil:
            message = "Received map from \(mapProvider!.displayName)."
            
        case .limited(.relocalizing):
            message = "Resuming session — move to where you were when the session was interrupted."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        default:
            // No feedback needed when tracking is normal and planes are visible.
            // (Nor when in unreachable limited-tracking states.)
            message = ""
            
        }
        
        self.sessionInfoView.isHidden = message.isEmpty
        self.sessionInfoLabel.text = message
    }
    
    @IBAction func shareSession(_ button: UIButton) {
        self.arView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { print("Error: \(error!.localizedDescription)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
            self.multipeerSession.sendToAllPeers(data)
        }
    }
}

extension ARViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.shouldDraw = self.button.isHighlighted
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let components = anchor.name?.components(separatedBy: "=") ?? []
        let cylinder = SCNCylinder(radius: self.strokeWidth, height: CGFloat(Float(components[0]) ?? 0))
        cylinder.radialSegmentCount = 7
        cylinder.firstMaterial?.diffuse.contents = UIColor.UIColorFromString(string: components[1])
        cylinder.firstMaterial?.lightingModel = .lambert
        let node = SCNNode(geometry: cylinder)
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        guard let pointOfView = self.arView.pointOfView else { return }
        let transform = pointOfView.transform
        let direction = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
        let currentPosition = pointOfView.position + (direction * self.drawingDistance)
        
        if let previousPosition = self.previousPosition, self.shouldDraw {
            let delta = currentPosition - previousPosition
            let length = delta.length()
  
            let node = SCNNode()
            node.position = (currentPosition + previousPosition) / 2
            node.eulerAngles = SCNVector3(
                .pi / 2,
                acos((currentPosition.z - previousPosition.z) / length),
                atan2(currentPosition.y - previousPosition.y, currentPosition.x - previousPosition.x)
            )
            
            let anchor = ARAnchor(name: "\(length)=\(UIColor.StringFromUIColor(color: self.selectedColor))", transform: node.simdWorldTransform)
            self.arView.session.add(anchor: anchor)
            
            guard let data = try? NSKeyedArchiver.archivedData(
                withRootObject: anchor,
                requiringSecureCoding: true
            ) else { fatalError("can't encode anchor") }
            self.multipeerSession.sendToAllPeers(data)
        }
        
        self.previousPosition = currentPosition
    }
}

func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}

func * (vector: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3Make(vector.x * scalar, vector.y * scalar, vector.z * scalar)
}

func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x - right.x, left.y - right.y, left.z - right.z)
}

func / (vector: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3Make(vector.x / scalar, vector.y / scalar, vector.z / scalar)
}

extension SCNVector3 {
    func length() -> Float {
        return sqrtf((x * x) + (y * y) + (z * z))
    }
}

public extension UIColor {
    class func StringFromUIColor(color: UIColor) -> String {
        let components = color.cgColor.components ?? []
        return "[\(components[0]), \(components[1]), \(components[2]), \(components[3])]"
    }
    
    class func UIColorFromString(string: String) -> UIColor {
        let componentsString = string.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
        let components = componentsString.components(separatedBy: ", ")
        return UIColor(red: CGFloat((components[0] as NSString).floatValue),
                     green: CGFloat((components[1] as NSString).floatValue),
                      blue: CGFloat((components[2] as NSString).floatValue),
                     alpha: CGFloat((components[3] as NSString).floatValue))
    }
}
