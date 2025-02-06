import SpriteKit

/// Datenmodell für einen Frame im Ghost-Lauf
struct GhostFrame: Codable {
    let time: TimeInterval   // Zeit (in Sekunden) seit Laufstart
    let position: CGPoint    // Position des Spielers zu diesem Zeitpunkt
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Nodes und Lauf‑Daten
    var player: SKSpriteNode!
    var ghost: SKSpriteNode?          // Darstellung des Ghost-Laufs (blau, halbtransparent)
    
    /// Aufzeichnung des aktuellen Laufs (pro Frame werden Daten gespeichert)
    var currentGhostFrames: [GhostFrame] = []
    /// Beste (gespeicherte) Ghost‑Frames aus dem bisherigen Lauf
    var bestGhostFrames: [GhostFrame] = []
    
    /// Zeitpunkt des Laufstartes
    var runStartTime: TimeInterval = 0
    var recording: Bool = true
    
    // MARK: - UI-Elemente (als SpriteKit-Labels)
    var currentTimeLabel: SKLabelNode!
    var bestTimeLabel: SKLabelNode!
    
    /// Beste Zeit (niedrigster Wert) des gespeicherten Laufs
    var bestTime: TimeInterval = 0
    
    // Zusätzliche Variable für die Spielgeschwindigkeit (wird in der ContentView via Settings angepasst)
    var gameSpeed: CGFloat = 2.0

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
        
        // Observer für Settings-Änderungen hinzufügen
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateGameSettings(_:)),
                                               name: Notification.Name("UpdateGameSettings"),
                                               object: nil)
    }
    
    // MARK: - Setup-Funktionen
    
    /// Erzeugt einen einfachen Boden als SKSpriteNode
    func setupGround() {
        let ground = SKSpriteNode(color: .brown, size: CGSize(width: self.size.width * 3, height: 40))
        ground.position = CGPoint(x: self.size.width, y: 100)
        ground.physicsBody = SKPhysicsBody(rectangleOf: ground.size)
        ground.physicsBody?.isDynamic = false
        addChild(ground)
    }
    
    /// Initialisiert den Spieler (rote Box)
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
    
    /// Lädt den besten Ghost-Lauf (falls vorhanden) aus UserDefaults
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
    
    /// Erzeugt den Ghost-Node (blaue Box) und startet die Animation anhand der gespeicherten GhostFrames
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
    
    /// Erzeugt eine SKAction-Sequenz, um den Ghost-Node anhand der gespeicherten Frames zu animieren
    func runGhostAnimation() {
        guard bestGhostFrames.count > 0, let ghost = ghost else { return }
        ghost.removeAllActions()
        
        var actions: [SKAction] = []
        for i in 0..<bestGhostFrames.count {
            let frame = bestGhostFrames[i]
            var duration: TimeInterval = 0
            if i == 0 {
                duration = frame.time
            } else {
                duration = frame.time - bestGhostFrames[i - 1].time
            }
            let moveAction = SKAction.move(to: frame.position, duration: duration)
            actions.append(moveAction)
        }
        ghost.run(SKAction.sequence(actions))
    }
    
    // MARK: - Touch Handling
    
    /// Bei Touch-Eingabe springt der Spieler, sofern er auf dem Boden ist
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let body = player.physicsBody, abs(body.velocity.dy) < 1.0 {
            body.applyImpulse(CGVector(dx: 0, dy: 300))
        }
    }
    
    // MARK: - Game Loop
    
    override func update(_ currentTime: TimeInterval) {
        if runStartTime == 0 {
            runStartTime = currentTime
        }
        
        let elapsed = currentTime - runStartTime
        currentTimeLabel.text = String(format: "Zeit: %.2f s", elapsed)
        bestTimeLabel.text = String(format: "Best: %.2f s", bestTime)
        
        // Aufzeichnung des Spielerstatus für den Ghost-Lauf
        if recording {
            let frame = GhostFrame(time: elapsed, position: player.position)
            currentGhostFrames.append(frame)
        }
        
        // Konstante Vorwärtsbewegung basierend auf der einstellbaren gameSpeed
        player.position.x += gameSpeed
        
        // Überprüfe, ob der Spieler das Spielfeld verlässt
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
        
        // Aktualisiere Bestzeit und speichere den Ghost-Lauf, falls der aktuelle Lauf besser war
        if bestTime == 0 || runTime < bestTime {
            bestTime = runTime
            bestGhostFrames = currentGhostFrames
            
            let encoder = JSONEncoder()
            if let data = try? encoder.encode(bestGhostFrames) {
                UserDefaults.standard.set(data, forKey: "bestGhostRun")
            }
        }
        
        // Zeige eine „Game Over“-Nachricht
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
    
    // MARK: - Settings-Update
    @objc func updateGameSettings(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            // Aktualisiere die Spielerfarbe
            if let newColor = userInfo["playerColor"] as? UIColor {
                player.color = newColor
            }
            // Aktualisiere die Spielgeschwindigkeit
            if let newSpeed = userInfo["gameSpeed"] as? Double {
                gameSpeed = CGFloat(newSpeed)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
