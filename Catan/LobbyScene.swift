import SpriteKit
import UIKit

struct LobbyPlayer {
    let id: String
    var username: String
    var avatarIndex: Int
    var isHost: Bool
    var isBot: Bool
    var isReady: Bool
    var colorName: String
}

class LobbyScene: SKScene {
    
    // Properties
    var isHost: Bool = false
    var isQuickPlay: Bool = false
    private var lobbyCode: String = ""
    private var players: [LobbyPlayer] = []
    private let maxPlayers = 4
    
    // Network properties
    private var networkManager: NetworkManager?
    private var isConnectedToServer: Bool = false
    
    // UI Components
    private var backButton: SKShapeNode!
    private var titleLabel: SKLabelNode!
    private var lobbyCodeLabel: SKLabelNode!
    private var copyCodeButton: SKShapeNode!
    private var playerSlots: [SKNode] = []
    private var startButton: SKShapeNode!
    private var settingsContainer: SKNode!
    private var chatButton: SKShapeNode!
    
    // Game settings
    private var victoryPoints = 10
    private var discardLimit = 7
    
    // Available colors for players
    private let colorOptions = ["black", "blue", "bronze", "gold", "green",
                                "mysticblue", "orange", "pink", "purple",
                                "red", "silver", "white"]
    private var takenColors: Set<String> = []
    
    override func didMove(to view: SKView) {
        self.backgroundColor = SKColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)
        
        if isHost {
            generateLobbyCode()
            createHostPlayer()
            // Connect to server and create room
            setupServerConnection()
        } else {
            // If joining, we should already have the lobby code
            // Connect and join the room
            joinServerRoom()
        }
        
        setupUI()
        updatePlayerDisplay()
    }
    
    private func generateLobbyCode() {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        lobbyCode = String((0..<6).map { _ in letters.randomElement()! })
    }
    
    private func createHostPlayer() {
        let username = UserDefaults.standard.string(forKey: "playerUsername") ?? "Host"
        let avatarIndex = UserDefaults.standard.integer(forKey: "selectedAvatar")
        
        let hostPlayer = LobbyPlayer(
            id: UUID().uuidString,
            username: username,
            avatarIndex: avatarIndex,
            isHost: true,
            isBot: false,
            isReady: true,
            colorName: colorOptions[0]
        )
        
        players.append(hostPlayer)
        takenColors.insert(colorOptions[0])
        
        // Add bot players for quick play
        if isQuickPlay {
            addBotPlayer()
            addBotPlayer()
        }
    }
    
    private func setupUI() {
        // Title
        titleLabel = SKLabelNode(text: isHost ? "Create Lobby" : "Lobby")
        titleLabel.fontName = "Helvetica-Bold"
        titleLabel.fontSize = self.size.width * 0.07
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.92)
        self.addChild(titleLabel)
        
        // Back Button
        backButton = createBackButton()
        backButton.position = CGPoint(x: 50, y: self.size.height - 50)
        backButton.name = "backButton"
        self.addChild(backButton)
        
        // Lobby Code Section
        if isHost {
            setupLobbyCodeSection()
        }
        
        // Player Slots
        setupPlayerSlots()
        
        // Settings Section (only for host)
        if isHost {
            setupSettingsSection()
        }
        
        // Start/Ready Button
        setupStartButton()
        
        // Chat Button
        setupChatButton()
    }
    
    private func setupLobbyCodeSection() {
        // Lobby code label
        let codeTitle = SKLabelNode(text: "Lobby Code:")
        codeTitle.fontName = "Helvetica"
        codeTitle.fontSize = self.size.width * 0.04
        codeTitle.fontColor = .white
        codeTitle.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.83)
        self.addChild(codeTitle)
        
        // Code display
        lobbyCodeLabel = SKLabelNode(text: lobbyCode)
        lobbyCodeLabel.fontName = "Helvetica-Bold"
        lobbyCodeLabel.fontSize = self.size.width * 0.08
        lobbyCodeLabel.fontColor = .white
        lobbyCodeLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.78)
        self.addChild(lobbyCodeLabel)
        
        // Copy button
        copyCodeButton = SKShapeNode(rectOf: CGSize(width: 80, height: 30), cornerRadius: 5)
        copyCodeButton.fillColor = .white.withAlphaComponent(0.2)
        copyCodeButton.strokeColor = .white
        copyCodeButton.position = CGPoint(x: self.size.width * 0.75, y: self.size.height * 0.78)
        copyCodeButton.name = "copyCode"
        
        let copyLabel = SKLabelNode(text: "Copy")
        copyLabel.fontName = "Helvetica"
        copyLabel.fontSize = 14
        copyLabel.fontColor = .white
        copyLabel.verticalAlignmentMode = .center
        copyLabel.name = "copyCode"
        copyCodeButton.addChild(copyLabel)
        
        self.addChild(copyCodeButton)
    }
    
    private func setupPlayerSlots() {
        let startY = self.size.height * 0.65
        let slotHeight: CGFloat = 80
        let spacing: CGFloat = 10
        
        for i in 0..<maxPlayers {
            let slot = createPlayerSlot(index: i)
            slot.position = CGPoint(x: self.size.width/2, y: startY - CGFloat(i) * (slotHeight + spacing))
            playerSlots.append(slot)
            self.addChild(slot)
        }
    }
    
    private func createPlayerSlot(index: Int) -> SKNode {
        let container = SKNode()
        container.name = "playerSlot_\(index)"
        
        // Background
        let background = SKShapeNode(rectOf: CGSize(width: self.size.width * 0.9, height: 70), 
                                     cornerRadius: 10)
        background.fillColor = .white.withAlphaComponent(0.1)
        background.strokeColor = .white.withAlphaComponent(0.3)
        container.addChild(background)
        
        // Player number
        let numberLabel = SKLabelNode(text: "P\(index + 1)")
        numberLabel.fontName = "Helvetica-Bold"
        numberLabel.fontSize = 20
        numberLabel.fontColor = .white
        numberLabel.position = CGPoint(x: -self.size.width * 0.38, y: 0)
        numberLabel.verticalAlignmentMode = .center
        container.addChild(numberLabel)
        
        return container
    }
    
    private func setupSettingsSection() {
        settingsContainer = SKNode()
        settingsContainer.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.25)
        
        // Victory Points
        let vpLabel = SKLabelNode(text: "Victory Points: \(victoryPoints)")
        vpLabel.fontName = "Helvetica"
        vpLabel.fontSize = 16
        vpLabel.fontColor = .white
        vpLabel.position = CGPoint(x: -80, y: 20)
        settingsContainer.addChild(vpLabel)
        
        // VP adjustment buttons
        let vpMinusButton = createAdjustButton(text: "-", name: "vpMinus")
        vpMinusButton.position = CGPoint(x: 20, y: 20)
        settingsContainer.addChild(vpMinusButton)
        
        let vpPlusButton = createAdjustButton(text: "+", name: "vpPlus")
        vpPlusButton.position = CGPoint(x: 60, y: 20)
        settingsContainer.addChild(vpPlusButton)
        
        // Discard Limit
        let discardLabel = SKLabelNode(text: "Discard Limit: \(discardLimit)")
        discardLabel.fontName = "Helvetica"
        discardLabel.fontSize = 16
        discardLabel.fontColor = .white
        discardLabel.position = CGPoint(x: -80, y: -10)
        settingsContainer.addChild(discardLabel)
        
        // Discard adjustment buttons
        let discardMinusButton = createAdjustButton(text: "-", name: "discardMinus")
        discardMinusButton.position = CGPoint(x: 20, y: -10)
        settingsContainer.addChild(discardMinusButton)
        
        let discardPlusButton = createAdjustButton(text: "+", name: "discardPlus")
        discardPlusButton.position = CGPoint(x: 60, y: -10)
        settingsContainer.addChild(discardPlusButton)
        
        self.addChild(settingsContainer)
    }
    
    private func createAdjustButton(text: String, name: String) -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: 15)
        button.fillColor = .white.withAlphaComponent(0.2)
        button.strokeColor = .white
        button.name = name
        
        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 20
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        button.addChild(label)
        
        return button
    }
    
    private func setupStartButton() {
        let buttonText = isHost ? "Start Game" : "Ready"
        startButton = SKShapeNode(rectOf: CGSize(width: self.size.width * 0.6, height: 50), 
                                  cornerRadius: 10)
        startButton.fillColor = isHost ? .systemGreen : .systemBlue
        startButton.strokeColor = .clear
        startButton.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.1)
        startButton.name = "startButton"
        
        let label = SKLabelNode(text: buttonText)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = "startButton"
        startButton.addChild(label)
        
        self.addChild(startButton)
    }
    
    private func setupChatButton() {
        chatButton = SKShapeNode(circleOfRadius: 25)
        chatButton.fillColor = .systemBlue
        chatButton.strokeColor = .white
        chatButton.lineWidth = 2
        chatButton.position = CGPoint(x: self.size.width - 60, y: 60)
        chatButton.name = "chatButton"
        
        // Chat icon (simple bubble)
        let bubblePath = CGMutablePath()
        bubblePath.addEllipse(in: CGRect(x: -12, y: -8, width: 24, height: 16))
        bubblePath.move(to: CGPoint(x: -5, y: -8))
        bubblePath.addLine(to: CGPoint(x: -8, y: -15))
        bubblePath.addLine(to: CGPoint(x: 2, y: -8))
        
        let bubble = SKShapeNode(path: bubblePath)
        bubble.fillColor = .white
        bubble.strokeColor = .clear
        chatButton.addChild(bubble)
        
        self.addChild(chatButton)
    }
    
    private func createBackButton() -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: 25)
        button.fillColor = .white.withAlphaComponent(0.2)
        button.strokeColor = .white
        button.lineWidth = 2
        
        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: 5, y: 0))
        arrowPath.addLine(to: CGPoint(x: -5, y: -10))
        arrowPath.addLine(to: CGPoint(x: -5, y: -3))
        arrowPath.addLine(to: CGPoint(x: -10, y: -3))
        arrowPath.addLine(to: CGPoint(x: -10, y: 3))
        arrowPath.addLine(to: CGPoint(x: -5, y: 3))
        arrowPath.addLine(to: CGPoint(x: -5, y: 10))
        arrowPath.closeSubpath()
        
        let arrow = SKShapeNode(path: arrowPath)
        arrow.fillColor = .white
        arrow.strokeColor = .clear
        button.addChild(arrow)
        
        return button
    }
    
    private func updatePlayerDisplay() {
        // Update each player slot
        for (index, slot) in playerSlots.enumerated() {
            // Clear previous content (except background and P# label)
            slot.children.forEach { node in
                if let shapeNode = node as? SKShapeNode,
                   shapeNode != slot.children.first {
                    // Keep background
                } else if let labelNode = node as? SKLabelNode,
                          labelNode.text?.starts(with: "P") == false {
                    labelNode.removeFromParent()
                }
            }
            
            if index < players.count {
                let player = players[index]
                updatePlayerSlot(slot: slot, player: player, index: index)
            } else if isHost {
                // Show "Add Bot" button for empty slots
                addEmptySlotButton(to: slot, index: index)
            }
        }
    }
    
    private func updatePlayerSlot(slot: SKNode, player: LobbyPlayer, index: Int) {
        // Avatar
        let avatarColors: [UIColor] = [
            .systemRed, .systemBlue, .systemGreen, .systemOrange,
            .systemPurple, .systemPink, .systemYellow, .systemCyan
        ]
        let avatar = SKShapeNode(circleOfRadius: 25)
        avatar.fillColor = avatarColors[min(player.avatarIndex, avatarColors.count - 1)]
        avatar.strokeColor = .white
        avatar.lineWidth = 2
        avatar.position = CGPoint(x: -self.size.width * 0.25, y: 0)
        slot.addChild(avatar)
        
        // Username
        let usernameLabel = SKLabelNode(text: player.username)
        usernameLabel.fontName = "Helvetica-Bold"
        usernameLabel.fontSize = 18
        usernameLabel.fontColor = .white
        usernameLabel.horizontalAlignmentMode = .left
        usernameLabel.position = CGPoint(x: -self.size.width * 0.15, y: 10)
        slot.addChild(usernameLabel)
        
        // Bot/Host indicator
        let typeText = player.isHost ? "Host" : (player.isBot ? "Bot" : "Player")
        let typeLabel = SKLabelNode(text: typeText)
        typeLabel.fontName = "Helvetica"
        typeLabel.fontSize = 14
        typeLabel.fontColor = player.isHost ? .systemYellow : .lightGray
        typeLabel.horizontalAlignmentMode = .left
        typeLabel.position = CGPoint(x: -self.size.width * 0.15, y: -10)
        slot.addChild(typeLabel)
        
        // Color selector
        if isHost {
            let colorButton = SKShapeNode(rectOf: CGSize(width: 60, height: 30), cornerRadius: 5)
            colorButton.fillColor = getUIColor(for: player.colorName)
            colorButton.strokeColor = .white
            colorButton.position = CGPoint(x: self.size.width * 0.15, y: 0)
            colorButton.name = "colorSelect_\(index)"
            slot.addChild(colorButton)
        }
        
        // Ready indicator
        if player.isReady {
            let checkmark = SKLabelNode(text: "✓")
            checkmark.fontName = "Helvetica-Bold"
            checkmark.fontSize = 24
            checkmark.fontColor = .systemGreen
            checkmark.position = CGPoint(x: self.size.width * 0.3, y: 0)
            slot.addChild(checkmark)
        }
        
        // Remove button (for bots, if host)
        if isHost && player.isBot {
            let removeButton = SKShapeNode(circleOfRadius: 12)
            removeButton.fillColor = .systemRed
            removeButton.strokeColor = .clear
            removeButton.position = CGPoint(x: self.size.width * 0.38, y: 0)
            removeButton.name = "removePlayer_\(index)"
            
            let xLabel = SKLabelNode(text: "✕")
            xLabel.fontSize = 16
            xLabel.fontColor = .white
            xLabel.verticalAlignmentMode = .center
            xLabel.name = removeButton.name
            removeButton.addChild(xLabel)
            
            slot.addChild(removeButton)
        }
    }
    
    private func addEmptySlotButton(to slot: SKNode, index: Int) {
        let addBotButton = SKShapeNode(rectOf: CGSize(width: 100, height: 40), cornerRadius: 8)
        addBotButton.fillColor = .white.withAlphaComponent(0.2)
        addBotButton.strokeColor = .white
        addBotButton.position = CGPoint(x: 0, y: 0)
        addBotButton.name = "addBot_\(index)"
        
        let label = SKLabelNode(text: "+ Add Bot")
        label.fontName = "Helvetica"
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = addBotButton.name
        addBotButton.addChild(label)
        
        slot.addChild(addBotButton)
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
    
    private func addBotPlayer() {
        guard players.count < maxPlayers else { return }
        
        let botNames = ["Bot Alpha", "Bot Beta", "Bot Gamma", "Bot Delta"]
        let availableColors = colorOptions.filter { !takenColors.contains($0) }
        guard !availableColors.isEmpty else { return }
        
        let botPlayer = LobbyPlayer(
            id: UUID().uuidString,
            username: botNames[players.count - 1],
            avatarIndex: Int.random(in: 0..<8),
            isHost: false,
            isBot: true,
            isReady: true,
            colorName: availableColors[0]
        )
        
        players.append(botPlayer)
        takenColors.insert(availableColors[0])
        updatePlayerDisplay()
    }
    
    private func removePlayer(at index: Int) {
        guard index < players.count else { return }
        let player = players[index]
        takenColors.remove(player.colorName)
        players.remove(at: index)
        updatePlayerDisplay()
    }
    
    private func cyclePlayerColor(at index: Int) {
        guard index < players.count else { return }
        
        let availableColors = colorOptions.filter { !takenColors.contains($0) || $0 == players[index].colorName }
        guard !availableColors.isEmpty else { return }
        
        let currentIndex = availableColors.firstIndex(of: players[index].colorName) ?? 0
        let nextIndex = (currentIndex + 1) % availableColors.count
        
        takenColors.remove(players[index].colorName)
        players[index].colorName = availableColors[nextIndex]
        takenColors.insert(availableColors[nextIndex])
        
        updatePlayerDisplay()
    }
    
    private func startGame() {
        // Ensure we have at least 2 players
        guard players.count >= 2 else {
            showMessage("Need at least 2 players to start")
            return
        }
        
        // Navigate to complete multiplayer game scene
        let gameScene = MultiplayerGameSceneComplete(size: self.size)
        gameScene.scaleMode = .aspectFill
        gameScene.players = players
        gameScene.victoryPointGoal = victoryPoints
        gameScene.discardLimit = discardLimit
        gameScene.isHost = isHost
        gameScene.lobbyCode = lobbyCode
        
        self.view?.presentScene(gameScene, transition: SKTransition.fade(withDuration: 0.5))
    }
    
    private func showMessage(_ text: String) {
        let messageLabel = SKLabelNode(text: text)
        messageLabel.fontName = "Helvetica"
        messageLabel.fontSize = 18
        messageLabel.fontColor = .systemRed
        messageLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.05)
        self.addChild(messageLabel)
        
        messageLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = self.atPoint(location)
        
        if let nodeName = node.name {
            if nodeName == "backButton" {
                let multiplayerMenuScene = MultiplayerMenuScene(size: self.size)
                multiplayerMenuScene.scaleMode = .aspectFill
                self.view?.presentScene(multiplayerMenuScene, transition: SKTransition.fade(withDuration: 0.5))
                
            } else if nodeName == "copyCode" {
                UIPasteboard.general.string = lobbyCode
                showMessage("Code copied!")
                
            } else if nodeName == "startButton" {
                if isHost {
                    startGame()
                } else {
                    // Toggle ready status
                    if var firstPlayer = players.first {
                        firstPlayer.isReady.toggle()
                        players[0] = firstPlayer
                        updatePlayerDisplay()
                    }
                }
                
            } else if nodeName.starts(with: "addBot_") {
                addBotPlayer()
                
            } else if nodeName.starts(with: "removePlayer_") {
                if let indexStr = nodeName.split(separator: "_").last,
                   let index = Int(indexStr) {
                    removePlayer(at: index)
                }
                
            } else if nodeName.starts(with: "colorSelect_") {
                if let indexStr = nodeName.split(separator: "_").last,
                   let index = Int(indexStr) {
                    cyclePlayerColor(at: index)
                }
                
            } else if nodeName == "vpMinus" {
                victoryPoints = max(3, victoryPoints - 1)
                setupSettingsSection()
                
            } else if nodeName == "vpPlus" {
                victoryPoints = min(20, victoryPoints + 1)
                setupSettingsSection()
                
            } else if nodeName == "discardMinus" {
                discardLimit = max(3, discardLimit - 1)
                setupSettingsSection()
                
            } else if nodeName == "discardPlus" {
                discardLimit = min(20, discardLimit + 1)
                setupSettingsSection()
                
            } else if nodeName == "chatButton" {
                showMessage("Chat coming soon!")
            }
        }
    }
    
    // MARK: - Network Methods
    
    private func setupServerConnection() {
        // Create room on server via HTTP first
        createRoomOnServer { [weak self] success in
            if success {
                // Then establish WebSocket connection
                self?.connectWebSocket()
            } else {
                self?.showMessage("Failed to create room on server")
            }
        }
    }
    
    private func createRoomOnServer(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "http://localhost:3000/api/lobby/create") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let hostId = UserDefaults.standard.string(forKey: "multiplayerPlayerId") ?? UUID().uuidString
        UserDefaults.standard.set(hostId, forKey: "multiplayerPlayerId")
        
        let body: [String: Any] = [
            "hostId": hostId,
            "roomCode": lobbyCode,  // Use our generated code
            "settings": [
                "maxPlayers": maxPlayers,
                "victoryPoints": victoryPoints,
                "discardLimit": discardLimit,
                "isPrivate": false
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Failed to serialize request body: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Room creation error: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("Room created on server: \(json)")
                DispatchQueue.main.async {
                    // Update lobby code if server provided one
                    if let serverCode = json["roomCode"] as? String {
                        self?.lobbyCode = serverCode
                        self?.lobbyCodeLabel?.text = serverCode
                    }
                    completion(true)
                }
            } else {
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }.resume()
    }
    
    private func connectWebSocket() {
        // Initialize NetworkManager and connect
        networkManager = NetworkManager()
        networkManager?.delegate = self
        
        // Send join-room message
        let playerId = UserDefaults.standard.string(forKey: "multiplayerPlayerId") ?? ""
        let playerName = UserDefaults.standard.string(forKey: "playerUsername") ?? "Player"
        
        let joinData: [String: Any] = [
            "roomCode": lobbyCode,
            "playerId": playerId,
            "playerName": playerName,
            "isHost": isHost
        ]
        
        // Connect and join room
        if isHost {
            networkManager?.startHost()
        } else {
            networkManager?.joinGame(withCode: lobbyCode)
        }
        
        // Send join-room event through raw WebSocket
        // Note: In a real implementation, we'd need to modify NetworkManager to handle lobby events
        print("Connected to server WebSocket for room: \(lobbyCode)")
        isConnectedToServer = true
        
        // Show connection status
        showMessage("Connected to server")
    }
    
    private func joinServerRoom() {
        // For joining players, connect WebSocket and join the room
        connectWebSocket()
    }
    
    private func sendPlayerUpdate() {
        // Send current player list to server
        guard isConnectedToServer else { return }
        
        // In a real implementation, send player updates through NetworkManager
        // networkManager?.sendLobbyUpdate(players: players)
    }
    
    private func sendReadyStatus(playerId: String, isReady: Bool) {
        // Send ready status to server
        guard isConnectedToServer else { return }
        
        // In a real implementation:
        // networkManager?.sendReadyStatus(playerId: playerId, isReady: isReady)
    }
}

// MARK: - NetworkManagerDelegate Extension
extension LobbyScene: NetworkManagerDelegate {
    func networkManager(_ manager: NetworkManager, didReceiveGameAction action: GameAction) {
        // Handle lobby-related actions
        DispatchQueue.main.async {
            switch action.type {
            case .playerJoined:
                // Add new player to lobby
                if let playerData = action.data["player"] as? [String: Any],
                   let id = playerData["id"] as? String,
                   let name = playerData["name"] as? String {
                    // Check if player already exists
                    if !self.players.contains(where: { $0.id == id }) {
                        let newPlayer = LobbyPlayer(
                            id: id,
                            username: name,
                            avatarIndex: 0,
                            isHost: false,
                            isBot: false,
                            isReady: false,
                            colorName: self.colorOptions[self.players.count]
                        )
                        self.players.append(newPlayer)
                        self.updatePlayerDisplay()
                    }
                }
                
            case .playerLeft:
                // Remove player from lobby
                if let playerId = action.data["playerId"] as? String {
                    self.players.removeAll { $0.id == playerId }
                    self.updatePlayerDisplay()
                }
                
            default:
                break
            }
        }
    }
    
    func networkManager(_ manager: NetworkManager, didUpdateConnectionStatus connected: Bool) {
        DispatchQueue.main.async {
            self.isConnectedToServer = connected
            if connected {
                self.showMessage("Connected to server")
            } else {
                self.showMessage("Disconnected from server")
            }
        }
    }
    
    func networkManager(_ manager: NetworkManager, playerDidDisconnect playerId: String) {
        DispatchQueue.main.async {
            self.players.removeAll { $0.id == playerId }
            self.updatePlayerDisplay()
            self.showMessage("Player disconnected")
        }
    }
}