import SpriteKit

/// Ein Datenmodell für einen Frame im Ghost-Lauf
struct GhostFrame: Codable {
    let time: TimeInterval   // Zeit (in Sekunden) seit Laufstart
    let position: CGPoint    // Position des Spielers zu diesem Zeitpunkt
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Nodes und Lauf‑Daten
    var player: SKSpriteNode!
    var ghost: SKSpriteNode?          // Darstellung des Ghost-Laufs (blau, halbtransparent)
    
    /// Aufzeichnung des aktuellen Laufs (Werte werden pro Frame gesammelt)
    var currentGhostFrames: [GhostFrame] = []
    
    /// Beste (gespeicherte) Ghost‑Frames aus dem bisherigen besten Lauf
    var bestGhostFrames: [GhostFrame] = []
    
    /// Zeitpunkt, ab dem der aktuelle Lauf gestartet wurde
    var runStartTime: TimeInterval = 0
    var recording: Bool = true
    
    // MARK: - UI-Elemente
    var currentTimeLabel: SKLabelNode!
    var bestTimeLabel: SKLabelNode!
    
    /// Beste Zeit (niedrigster Wert) des gespeicherten Laufs
    var bestTime: TimeInterval = 0

    // MARK: - Scene Lifecycle
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        self.backgroundColor = SKColor.cyan
        
        setupGround()
        setupPlayer()
        setupLabels()
        loadBestGhostRun()
        
        runStartTime = 0
        recording = true
        currentGhostFrames = []
    }
    
    // MARK: - Setup Funktionen
    
    /// Erzeugt einen einfachen Boden (als SKSpriteNode) für den Spieler
    func setupGround() {
        let ground = SKSpriteNode(color: .brown, size: CGSize(width: self.size.width * 3, height: 40))
        ground.position = CGPoint(x: self.size.width, y: 100)
        ground.physicsBody = SKPhysicsBody(rectangleOf: ground.size)
        ground.physicsBody?.isDynamic = false
        addChild(ground)
    }
    
    /// Initialisiert den Spieler als rote Box
    func setupPlayer() {
        player = SKSpriteNode(color: .red, size: CGSize(width: 40, height: 40))
        player.position = CGPoint(x: 100, y: 150)
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.restitution = 0.0
        addChild(player)
    }
    
    /// Fügt Labels zur Anzeige von aktueller Laufzeit und Bestzeit hinzu
    func setupLabels() {
        currentTimeLabel = SKLabelNode(fontNamed: "Helvetica")
        currentTimeLabel.fontSize = 20
        currentTimeLabel.fontColor = .black
        currentTimeLabel.position = CGPoint(x: 20, y: self.size.height - 40)
        currentTimeLabel.horizontalAlignmentMode = .left
        addChild(currentTimeLabel)
        
        bestTimeLabel = SKLabelNode(fontNamed: "Helvetica")
        bestTimeLabel.fontSize = 20
        bestTimeLabel.fontColor = .black
        bestTimeLabel.position = CGPoint(x: 20, y: self.size.height - 70)
        bestTimeLabel.horizontalAlignmentMode = .left
        addChild(bestTimeLabel)
    }
    
    /// Lädt den besten Ghost-Lauf (falls vorhanden) aus UserDefaults und erstellt den Ghost-Node
    func loadBestGhostRun() {
        if let data = UserDefaults.standard.data(forKey: "bestGhostRun") {
            let decoder = JSONDecoder()
            if let frames = try? decoder.decode([GhostFrame].self, from: data) {
                bestGhostFrames = frames
                if let last = frames.last {
                    bestTime = last.time
                }
                setupGhost()
            }
        }
    }
    
    /// Erzeugt den Ghost-Node (blaue Box) und startet die Animation basierend auf den gespeicherten GhostFrames
    func setupGhost() {
        ghost?.removeFromParent()
        ghost = SKSpriteNode(color: .blue, size: CGSize(width: 40, height: 40))
        ghost?.alpha = 0.5
        ghost?.position = bestGhostFrames.first?.position ?? CGPoint(x: 100, y: 150)
        if let ghost = ghost {
            addChild(ghost)
        }
        runGhostAnimation()
    }
    
    /// Erzeugt eine SKAction-Sequenz, mit der der Ghost-Node gemäß den gespeicherten Frames animiert wird
    func runGhostAnimation() {
        guard bestGhostFrames.count > 0, let ghost = ghost else { return }
        ghost.removeAllActions()
        
        var actions: [SKAction] = []
        for i in 0..<bestGhostFrames.count {
            let frame = bestGhostFrames[i]
            var duration: TimeInterval = 0
            if i == 0 {
                duration = frame.time  // Falls ein anfängliches Warten nötig ist
            } else {
                duration = frame.time - bestGhostFrames[i - 1].time
            }
            let moveAction = SKAction.move(to: frame.position, duration: duration)
            actions.append(moveAction)
        }
        ghost.run(SKAction.sequence(actions))
    }
    
    // MARK: - Touch Handling
    
    /// Bei Touch-Eingabe springt der Spieler, sofern er nahezu stillsteht (also auf dem Boden ist)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let body = player.physicsBody, abs(body.velocity.dy) < 1.0 {
            body.applyImpulse(CGVector(dx: 0, dy: 300))
        }
    }
    
    // MARK: - Game Loop
    
    override func update(_ currentTime: TimeInterval) {
        // Initialisierung des Startzeitpunkts des Laufs
        if runStartTime == 0 {
            runStartTime = currentTime
        }
        
        // Aktualisierung der Labels
        let elapsed = currentTime - runStartTime
        currentTimeLabel.text = String(format: "Zeit: %.2f s", elapsed)
        bestTimeLabel.text = String(format: "Best: %.2f s", bestTime)
        
        // Aufzeichnung des Spieler-Status für den Ghost-Lauf
        if recording {
            let frame = GhostFrame(time: elapsed, position: player.position)
            currentGhostFrames.append(frame)
        }
        
        // Simuliere konstante Vorwärtsbewegung (Endless-Runner-Effekt)
        player.position.x += 2
        
        // (Optional) Falls die Szene größer als der Bildschirm ist: Verschiebe die Kamera mit dem Spieler
        // Hierzu könnte man einen SKCameraNode einsetzen.
        
        // Überprüfe, ob der Spieler vom Bildschirm gefallen ist oder das Levelende erreicht hat
        if player.position.y < -50 || player.position.x > self.size.width * 2 {
            endRun()
        }
    }
    
    // MARK: - Spielende & Neustart
    
    /// Wird aufgerufen, wenn der Lauf beendet ist (z. B. Spieler fällt ab)
    func endRun() {
        recording = false
        let runTime = currentGhostFrames.last?.time ?? 0
        print("Lauf beendet – Zeit: \(runTime) s")
        
        // Falls der aktuelle Lauf besser (schneller) war, aktualisiere die Bestzeit und speichere den Ghost-Lauf
        if bestTime == 0 || runTime < bestTime {
            bestTime = runTime
            bestGhostFrames = currentGhostFrames
            
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(bestGhostFrames) {
                UserDefaults.standard.set(data, forKey: "bestGhostRun")
            }
        }
        
        // Zeige eine „Game Over“ Nachricht
        let gameOverLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        gameOverLabel.fontSize = 40
        gameOverLabel.fontColor = .red
        gameOverLabel.text = "Run Over!"
        gameOverLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        addChild(gameOverLabel)
        
        // Starte den Neustart des Spiels nach 2 Sekunden
        let wait = SKAction.wait(forDuration: 2)
        let restart = SKAction.run { [weak self] in
            self?.restartGame()
        }
        run(SKAction.sequence([wait, restart]))
    }
    
    /// Startet die Szene neu
    func restartGame() {
        if let view = self.view {
            let newScene = GameScene(size: self.size)
            newScene.scaleMode = self.scaleMode
            view.presentScene(newScene, transition: SKTransition.fade(withDuration: 1.0))
        }
    }
}
