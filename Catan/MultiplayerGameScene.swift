import SpriteKit
import GameplayKit

class MultiplayerGameScene: GameScene {
    
    // Multiplayer specific properties
    var players: [LobbyPlayer] = []
    var isHost: Bool = false
    private var networkManager: NetworkManager?
    private var localPlayerId: String = ""
    private var connectionStatusNode: SKLabelNode!
    private var playerStatusNodes: [SKNode] = []
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        setupMultiplayerUI()
        initializeMultiplayerGame()
        
        // Set local player ID
        localPlayerId = players.first(where: { !$0.isBot && ($0.isHost == isHost) })?.id ?? ""
    }
    
    private func setupMultiplayerUI() {
        // Connection status indicator
        connectionStatusNode = SKLabelNode(text: "🟢 Connected")
        connectionStatusNode.fontName = "Helvetica"
        connectionStatusNode.fontSize = 14
        connectionStatusNode.fontColor = .systemGreen
        connectionStatusNode.horizontalAlignmentMode = .right
        connectionStatusNode.position = CGPoint(x: self.size.width - 20, y: self.size.height - 30)
        connectionStatusNode.zPosition = 1000
        self.addChild(connectionStatusNode)
        
        // Player status indicators
        setupPlayerStatusIndicators()
        
        // Chat button
        let chatButton = SKShapeNode(circleOfRadius: 25)
        chatButton.fillColor = .systemBlue
        chatButton.strokeColor = .white
        chatButton.lineWidth = 2
        chatButton.position = CGPoint(x: self.size.width - 40, y: 100)
        chatButton.zPosition = 1000
        chatButton.name = "multiplayerChatButton"
        
        let chatIcon = SKLabelNode(text: "💬")
        chatIcon.fontSize = 20
        chatIcon.verticalAlignmentMode = .center
        chatButton.addChild(chatIcon)
        
        self.addChild(chatButton)
    }
    
    private func setupPlayerStatusIndicators() {
        let startY = self.size.height * 0.8
        let spacing: CGFloat = 30
        
        for (index, player) in players.enumerated() {
            let statusNode = createPlayerStatusNode(player: player)
            statusNode.position = CGPoint(x: 20, y: startY - CGFloat(index) * spacing)
            statusNode.zPosition = 1000
            playerStatusNodes.append(statusNode)
            self.addChild(statusNode)
        }
    }
    
    private func createPlayerStatusNode(player: LobbyPlayer) -> SKNode {
        let container = SKNode()
        
        // Background
        let background = SKShapeNode(rectOf: CGSize(width: 150, height: 25), cornerRadius: 5)
        background.fillColor = getUIColor(for: player.colorName).withAlphaComponent(0.3)
        background.strokeColor = getUIColor(for: player.colorName)
        background.lineWidth = 1
        container.addChild(background)
        
        // Player name
        let nameLabel = SKLabelNode(text: player.username)
        nameLabel.fontName = "Helvetica"
        nameLabel.fontSize = 12
        nameLabel.fontColor = .white
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.position = CGPoint(x: -70, y: -4)
        container.addChild(nameLabel)
        
        // Connection indicator (for non-bot players)
        if !player.isBot {
            let connectionDot = SKShapeNode(circleOfRadius: 4)
            connectionDot.fillColor = .systemGreen
            connectionDot.strokeColor = .clear
            connectionDot.position = CGPoint(x: 65, y: 0)
            connectionDot.name = "connection_\(player.id)"
            container.addChild(connectionDot)
        }
        
        // Turn indicator
        let turnArrow = SKLabelNode(text: "▶")
        turnArrow.fontName = "Helvetica-Bold"
        turnArrow.fontSize = 12
        turnArrow.fontColor = .systemYellow
        turnArrow.position = CGPoint(x: -85, y: -4)
        turnArrow.isHidden = true
        turnArrow.name = "turnIndicator_\(player.id)"
        container.addChild(turnArrow)
        
        return container
    }
    
    private func initializeMultiplayerGame() {
        // Override the standard game initialization
        // Set up players based on lobby configuration
        
        gameState.players.removeAll()
        
        for (index, lobbyPlayer) in players.enumerated() {
            let player = Player(id: index, isBot: lobbyPlayer.isBot)
            player.assetColor = lobbyPlayer.colorName
            
            // Set initial resources for all players
            if gameState.isSetupPhase {
                // Setup phase - no initial resources
            } else {
                // For testing, give some starting resources
                player.resources = [.wood: 2, .brick: 2, .sheep: 1, .wheat: 1, .ore: 0]
            }
            
            gameState.players.append(player)
        }
        
        // Initialize network manager if not a bot-only game
        if players.contains(where: { !$0.isBot }) {
            networkManager = NetworkManager()
            networkManager?.delegate = self
            
            if isHost {
                networkManager?.startHost()
            } else {
                networkManager?.joinGame()
            }
        }
    }
    
    private func getUIColor(for colorName: String) -> UIColor {
        switch colorName {
        case "black": return .black
        case "blue": return .systemBlue
        case "bronze": return .brown
        case "gold": return .systemYellow
        case "green": return .systemGreen
        case "mysticblue": return .systemTeal
        case "orange": return .systemOrange
        case "pink": return .systemPink
        case "purple": return .systemPurple
        case "red": return .systemRed
        case "silver": return .lightGray
        case "white": return .white
        default: return .gray
        }
    }
    
    // Override touch handling to send network messages
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = self.atPoint(location)
        
        // Check for multiplayer-specific buttons first
        if node.name == "multiplayerChatButton" {
            showChatOverlay()
            return
        }
        
        // For multiplayer, only allow actions on your turn
        let currentLobbyPlayer = players[gameState.currentPlayerIndex]
        if currentLobbyPlayer.id != localPlayerId && !currentLobbyPlayer.isBot {
            showMessage("Wait for your turn")
            return
        }
        
        // Call parent implementation for game actions
        super.touchesBegan(touches, with: event)
    }
    
    private func showChatOverlay() {
        // Create chat overlay
        let overlay = SKNode()
        overlay.name = "chatOverlay"
        overlay.zPosition = 2000
        
        // Background
        let background = SKShapeNode(rectOf: self.size)
        background.fillColor = .black.withAlphaComponent(0.8)
        background.strokeColor = .clear
        overlay.addChild(background)
        
        // Chat window
        let chatWindow = SKShapeNode(rectOf: CGSize(width: self.size.width * 0.8, height: self.size.height * 0.6), 
                                     cornerRadius: 15)
        chatWindow.fillColor = UIColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)
        chatWindow.strokeColor = .white
        chatWindow.lineWidth = 2
        chatWindow.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
        overlay.addChild(chatWindow)
        
        // Chat title
        let titleLabel = SKLabelNode(text: "Game Chat")
        titleLabel.fontName = "Helvetica-Bold"
        titleLabel.fontSize = 24
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.75)
        overlay.addChild(titleLabel)
        
        // Close button
        let closeButton = SKShapeNode(circleOfRadius: 20)
        closeButton.fillColor = .systemRed
        closeButton.strokeColor = .white
        closeButton.position = CGPoint(x: self.size.width * 0.85, y: self.size.height * 0.75)
        closeButton.name = "closeChatButton"
        
        let closeLabel = SKLabelNode(text: "✕")
        closeLabel.fontSize = 20
        closeLabel.fontColor = .white
        closeLabel.verticalAlignmentMode = .center
        closeLabel.name = "closeChatButton"
        closeButton.addChild(closeLabel)
        overlay.addChild(closeButton)
        
        // Sample chat messages
        let messages = [
            "Welcome to the game!",
            "Good luck everyone!",
            "Nice move!",
            "Anyone want to trade?"
        ]
        
        for (index, message) in messages.enumerated() {
            let messageLabel = SKLabelNode(text: message)
            messageLabel.fontName = "Helvetica"
            messageLabel.fontSize = 16
            messageLabel.fontColor = .white
            messageLabel.horizontalAlignmentMode = .left
            messageLabel.position = CGPoint(x: self.size.width * 0.15, 
                                           y: self.size.height * 0.6 - CGFloat(index) * 30)
            overlay.addChild(messageLabel)
        }
        
        // Chat input hint
        let inputHint = SKLabelNode(text: "Chat functionality coming soon...")
        inputHint.fontName = "Helvetica"
        inputHint.fontSize = 14
        inputHint.fontColor = .white.withAlphaComponent(0.6)
        inputHint.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.25)
        overlay.addChild(inputHint)
        
        self.addChild(overlay)
    }
    
    private func showMessage(_ text: String) {
        let messageLabel = SKLabelNode(text: text)
        messageLabel.fontName = "Helvetica"
        messageLabel.fontSize = 20
        messageLabel.fontColor = .systemYellow
        messageLabel.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
        messageLabel.zPosition = 2000
        self.addChild(messageLabel)
        
        messageLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
    
    // Override end turn to handle network synchronization
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        // Update turn indicators
        for (index, player) in players.enumerated() {
            if let turnIndicator = self.childNode(withName: "//turnIndicator_\(player.id)") {
                turnIndicator.isHidden = index != gameState.currentPlayerIndex
            }
        }
    }
    
    // Handle chat overlay dismissal
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = self.atPoint(location)
        
        if node.name == "closeChatButton" {
            self.childNode(withName: "chatOverlay")?.removeFromParent()
        }
        
        super.touchesEnded(touches, with: event)
    }
}

// MARK: - NetworkManagerDelegate
extension MultiplayerGameScene: NetworkManagerDelegate {
    func networkManager(_ manager: NetworkManager, didReceiveGameAction action: GameAction) {
        // Handle incoming game actions from other players
        processNetworkAction(action)
    }
    
    func networkManager(_ manager: NetworkManager, didUpdateConnectionStatus connected: Bool) {
        // Update connection status indicator
        DispatchQueue.main.async {
            if connected {
                self.connectionStatusNode.text = "🟢 Connected"
                self.connectionStatusNode.fontColor = .systemGreen
            } else {
                self.connectionStatusNode.text = "🔴 Disconnected"
                self.connectionStatusNode.fontColor = .systemRed
            }
        }
    }
    
    func networkManager(_ manager: NetworkManager, playerDidDisconnect playerId: String) {
        // Handle player disconnection
        if let disconnectedPlayer = players.first(where: { $0.id == playerId }) {
            showMessage("\(disconnectedPlayer.username) disconnected")
            
            // Update connection indicator
            if let connectionDot = self.childNode(withName: "//connection_\(playerId)") as? SKShapeNode {
                connectionDot.fillColor = .systemRed
            }
        }
    }
    
    private func processNetworkAction(_ action: GameAction) {
        // Process game actions received from network
        // This would include dice rolls, building placements, trades, etc.
        
        switch action.type {
        case .diceRoll:
            // Handle dice roll from another player
            break
        case .buildRoad:
            // Handle road building from another player
            break
        case .buildSettlement:
            // Handle settlement building from another player
            break
        case .buildCity:
            // Handle city building from another player
            break
        case .trade:
            // Handle trade proposal/acceptance
            break
        case .endTurn:
            // Handle turn ending
            gameState.nextPlayer()
            updatePlayerUISection()
        default:
            break
        }
    }
}