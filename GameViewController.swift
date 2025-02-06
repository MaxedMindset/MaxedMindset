import UIKit
import SpriteKit

class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Die view des Controllers als SKView casten
        if let skView = self.view as? SKView {
            // Erstelle und präsentiere die GameScene
            let scene = GameScene(size: skView.bounds.size)
            scene.scaleMode = .resizeFill
            skView.presentScene(scene)
            
            // Optionale Debug‑Informationen
            skView.showsFPS = true
            skView.showsNodeCount = true
            skView.ignoresSiblingOrder = true
        }
    }
    
    override func loadView() {
        // Erstelle eine SKView als Root-View
        self.view = SKView(frame: UIScreen.main.bounds)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
