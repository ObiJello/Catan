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
        
        // Navigate to multiplayer game scene
        let gameScene = MultiplayerGameScene(size: self.size)
        gameScene.scaleMode = .aspectFill
        gameScene.players = players
        gameScene.victoryPointGoal = victoryPoints
        gameScene.discardLimit = discardLimit
        gameScene.isHost = isHost
        
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
}