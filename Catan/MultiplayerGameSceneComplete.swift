import SpriteKit
import GameplayKit

class MultiplayerGameSceneComplete: GameScene {
    
    // Multiplayer specific properties
    var players: [LobbyPlayer] = []
    var isHost: Bool = false
    var lobbyCode: String = ""
    private var networkManager: NetworkManager?
    private var localPlayerId: String = ""
    private var localPlayerIndex: Int = 0
    private var connectionStatusNode: SKLabelNode!
    private var playerStatusNodes: [SKNode] = []
    private var turnIndicatorNode: SKNode!
    private var isMyTurn: Bool = false
    
    // Track pending actions
    private var pendingTradeOffer: TradeOffer?
    private var awaitingDiscards: Set<String> = []
    private var awaitingRobberMove: Bool = false
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        setupMultiplayerUI()
        initializeMultiplayerGame()
        setupNetworkManager()
        
        // Determine local player info
        if let localPlayer = players.first(where: { !$0.isBot && ($0.isHost == isHost) }) {
            localPlayerId = localPlayer.id
            localPlayerIndex = players.firstIndex(where: { $0.id == localPlayerId }) ?? 0
        }
        
        // Start with turn management
        updateTurnState()
    }
    
    // MARK: - Network Setup
    
    private func setupNetworkManager() {
        networkManager = NetworkManager()
        networkManager?.delegate = self
        
        // Join the game room
        if isHost {
            networkManager?.startHost()
        } else {
            networkManager?.joinGame(withCode: lobbyCode)
        }
    }
    
    // MARK: - UI Setup
    
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
        
        // Turn indicator
        setupTurnIndicator()
        
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
    
    private func setupTurnIndicator() {
        turnIndicatorNode = SKNode()
        
        let background = SKShapeNode(rectOf: CGSize(width: 200, height: 40), cornerRadius: 10)
        background.fillColor = .black.withAlphaComponent(0.7)
        background.strokeColor = .white
        turnIndicatorNode.addChild(background)
        
        let label = SKLabelNode(text: "Your Turn!")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 20
        label.fontColor = .systemGreen
        label.name = "turnLabel"
        turnIndicatorNode.addChild(label)
        
        turnIndicatorNode.position = CGPoint(x: self.size.width/2, y: self.size.height - 100)
        turnIndicatorNode.zPosition = 1000
        turnIndicatorNode.isHidden = true
        self.addChild(turnIndicatorNode)
    }
    
    private func setupPlayerStatusIndicators() {
        let startY = self.size.height * 0.8
        let spacing: CGFloat = 30
        
        for (index, player) in players.enumerated() {
            let statusNode = createPlayerStatusNode(player: player, index: index)
            statusNode.position = CGPoint(x: 20, y: startY - CGFloat(index) * spacing)
            statusNode.zPosition = 1000
            playerStatusNodes.append(statusNode)
            self.addChild(statusNode)
        }
    }
    
    private func createPlayerStatusNode(player: LobbyPlayer, index: Int) -> SKNode {
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
        
        // Victory points
        let vpLabel = SKLabelNode(text: "0 VP")
        vpLabel.fontName = "Helvetica-Bold"
        vpLabel.fontSize = 10
        vpLabel.fontColor = .white
        vpLabel.position = CGPoint(x: 40, y: -4)
        vpLabel.name = "vp_\(player.id)"
        container.addChild(vpLabel)
        
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
        turnArrow.name = "turnIndicator_\(index)"
        container.addChild(turnArrow)
        
        return container
    }
    
    // MARK: - Game Initialization
    
    private func initializeMultiplayerGame() {
        // Clear existing players
        gameState.players.removeAll()
        
        // Create game players from lobby players
        for (index, lobbyPlayer) in players.enumerated() {
            let player = Player(id: index, isBot: lobbyPlayer.isBot)
            player.assetColor = lobbyPlayer.colorName
            
            // Set initial resources based on game phase
            if !gameState.isSetupPhase {
                // For testing, give some starting resources
                player.resources = [.wood: 2, .brick: 2, .sheep: 1, .wheat: 1, .ore: 0]
            }
            
            gameState.players.append(player)
        }
    }
    
    // MARK: - Turn Management
    
    private func updateTurnState() {
        isMyTurn = (gameState.currentPlayerIndex == localPlayerIndex)
        
        // Update turn indicator
        if let label = turnIndicatorNode.childNode(withName: "turnLabel") as? SKLabelNode {
            if isMyTurn {
                label.text = "Your Turn!"
                label.fontColor = .systemGreen
                turnIndicatorNode.isHidden = false
            } else {
                let currentPlayer = players[gameState.currentPlayerIndex]
                label.text = "\(currentPlayer.username)'s Turn"
                label.fontColor = .white
                turnIndicatorNode.isHidden = false
            }
        }
        
        // Update player turn indicators
        for (index, _) in players.enumerated() {
            if let indicator = self.childNode(withName: "//turnIndicator_\(index)") {
                indicator.isHidden = (index != gameState.currentPlayerIndex)
            }
        }
        
        // Enable/disable UI based on turn
        updateUIForTurn()
    }
    
    private func updateUIForTurn() {
        // Disable dice if not your turn or already rolled
        diceNodes.forEach { dice in
            dice.alpha = isMyTurn && !gameState.hasRolledDice ? 1.0 : 0.5
        }
        
        // Update building buttons
        updateBuildingButtons()
        
        // Update end turn button
        if let endTurnButton = self.childNode(withName: "endTurnButton") {
            endTurnButton.alpha = isMyTurn ? 1.0 : 0.5
        }
    }
    
    // MARK: - Override Game Actions for Network
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)
        
        // Check for multiplayer-specific buttons first
        for node in touchedNodes {
            if node.name == "multiplayerChatButton" {
                showChatOverlay()
                return
            }
        }
        
        // Only allow actions on your turn (with some exceptions)
        if !isMyTurn && !isSpecialPhase() {
            showMessage("Wait for your turn")
            return
        }
        
        // Handle dice roll
        for node in touchedNodes {
            if let dice = node as? SKSpriteNode, diceNodes.contains(dice) {
                if isMyTurn && !gameState.hasRolledDice {
                    performNetworkDiceRoll()
                    return
                }
            }
        }
        
        // Handle building placement
        if selectedBuildingType != nil {
            handleNetworkBuildingPlacement(at: location)
            return
        }
        
        // Handle robber movement
        if awaitingRobberMove {
            handleNetworkRobberMove(at: location)
            return
        }
        
        // Call parent for other interactions
        super.touchesBegan(touches, with: event)
    }
    
    // MARK: - Network Game Actions
    
    private func performNetworkDiceRoll() {
        guard isMyTurn && !gameState.hasRolledDice else { return }
        
        let roll1 = Int.random(in: 1...6)
        let roll2 = Int.random(in: 1...6)
        
        // Send dice roll to server
        networkManager?.sendDiceRoll(value1: roll1, value2: roll2)
        
        // Optimistic update (will be confirmed by server)
        animateDiceRoll(value1: roll1, value2: roll2)
        gameState.hasRolledDice = true
    }
    
    private func animateDiceRoll(value1: Int, value2: Int) {
        // Animate dice rolling
        let rollAction = SKAction.repeat(SKAction.sequence([
            SKAction.run {
                self.diceNodes[0].texture = SKTexture(imageNamed: "dice_\(Int.random(in: 1...6))")
                self.diceNodes[1].texture = SKTexture(imageNamed: "dice_\(Int.random(in: 1...6))")
            },
            SKAction.wait(forDuration: 0.1)
        ]), count: 5)
        
        let finalAction = SKAction.run {
            self.diceNodes[0].texture = SKTexture(imageNamed: "dice_\(value1)")
            self.diceNodes[1].texture = SKTexture(imageNamed: "dice_\(value2)")
            
            let total = value1 + value2
            self.gameState.currentDiceRoll = total
            
            if total == 7 {
                self.handleSevenRolled()
            } else {
                // Resources will be distributed by server
            }
        }
        
        diceNodes[0].run(SKAction.sequence([rollAction, finalAction]))
    }
    
    private func handleNetworkBuildingPlacement(at location: CGPoint) {
        guard let buildingType = selectedBuildingType else { return }
        
        // Find the nearest valid placement point
        var placementPoint: CGPoint?
        var placementData: [String: Any] = [:]
        
        switch buildingType {
        case .road:
            // Find nearest edge
            if let edge = findNearestEdge(to: location) {
                placementPoint = edge.midpoint
                placementData = [
                    "fromX": edge.start.x,
                    "fromY": edge.start.y,
                    "toX": edge.end.x,
                    "toY": edge.end.y
                ]
                networkManager?.sendBuildRoad(from: edge.start, to: edge.end)
            }
            
        case .settlement:
            // Find nearest vertex
            if let vertex = findNearestVertex(to: location) {
                placementPoint = vertex.position
                placementData = ["x": vertex.position.x, "y": vertex.position.y]
                networkManager?.sendBuildSettlement(at: vertex.position)
            }
            
        case .city:
            // Find nearest settlement to upgrade
            if let settlement = findNearestSettlement(to: location) {
                placementPoint = settlement.position
                placementData = ["x": settlement.position.x, "y": settlement.position.y]
                networkManager?.sendBuildCity(at: settlement.position)
            }
        }
        
        // Clear selection after sending
        selectedBuildingType = nil
        updateBuildingButtons()
    }
    
    private func handleNetworkRobberMove(at location: CGPoint) {
        guard awaitingRobberMove else { return }
        
        // Find nearest tile
        if let tile = findNearestTile(to: location) {
            // Find players to steal from at this tile
            let playersAtTile = getPlayersWithBuildingsAtTile(tile)
            
            if playersAtTile.isEmpty {
                // No one to steal from, just move robber
                networkManager?.sendAction(GameAction(
                    type: .moveRobber,
                    playerId: localPlayerId,
                    data: ["tileId": tile.id, "stealFrom": NSNull()]
                ))
            } else if playersAtTile.count == 1 {
                // Auto-steal from single player
                networkManager?.sendAction(GameAction(
                    type: .moveRobber,
                    playerId: localPlayerId,
                    data: ["tileId": tile.id, "stealFrom": playersAtTile[0]]
                ))
            } else {
                // Show player selection dialog
                showStealSelectionDialog(players: playersAtTile, tileId: tile.id)
            }
            
            awaitingRobberMove = false
        }
    }
    
    // MARK: - Trading System
    
    private func initiateNetworkTrade() {
        guard isMyTurn else { return }
        
        // Show trade UI
        showTradeInterface()
    }
    
    private func showTradeInterface() {
        // Create trade overlay
        let tradeOverlay = createTradeOverlay()
        tradeOverlay.name = "tradeOverlay"
        tradeOverlay.zPosition = 2000
        self.addChild(tradeOverlay)
    }
    
    private func createTradeOverlay() -> SKNode {
        let overlay = SKNode()
        
        // Background
        let background = SKShapeNode(rectOf: self.size)
        background.fillColor = .black.withAlphaComponent(0.8)
        overlay.addChild(background)
        
        // Trade window
        let window = SKShapeNode(rectOf: CGSize(width: 600, height: 400), cornerRadius: 15)
        window.fillColor = UIColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)
        window.strokeColor = .white
        window.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
        overlay.addChild(window)
        
        // Title
        let title = SKLabelNode(text: "Trade")
        title.fontName = "Helvetica-Bold"
        title.fontSize = 24
        title.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.7)
        overlay.addChild(title)
        
        // Add resource selection UI
        // ... (implement trade UI)
        
        return overlay
    }
    
    private func sendTradeOffer(offering: [ResourceType: Int], requesting: [ResourceType: Int], toPlayer: String?) {
        let offeringDict = offering.reduce(into: [String: Int]()) { dict, pair in
            dict[pair.key.rawValue] = pair.value
        }
        let requestingDict = requesting.reduce(into: [String: Int]()) { dict, pair in
            dict[pair.key.rawValue] = pair.value
        }
        
        networkManager?.sendTradeOffer(offering: offeringDict, requesting: requestingDict, toPlayer: toPlayer)
    }
    
    // MARK: - Development Cards
    
    private func playNetworkDevelopmentCard(_ cardType: DevelopmentCardType) {
        guard isMyTurn else { return }
        
        let action = GameAction(
            type: .playDevelopmentCard,
            playerId: localPlayerId,
            data: ["cardType": cardType.rawValue]
        )
        
        networkManager?.sendAction(action)
        
        // Handle special card effects
        switch cardType {
        case .knight:
            awaitingRobberMove = true
            showMessage("Move the robber")
            
        case .roadBuilding:
            // Enable free road building mode
            enableFreeRoadBuilding(count: 2)
            
        case .yearOfPlenty:
            showResourceSelectionDialog(count: 2)
            
        case .monopoly:
            showMonopolyResourceSelection()
            
        case .victoryPoint:
            // Victory points are automatic
            break
        }
    }
    
    // MARK: - Special Phases
    
    private func isSpecialPhase() -> Bool {
        return awaitingDiscards.contains(localPlayerId) || awaitingRobberMove
    }
    
    private func handleSevenRolled() {
        // Check who needs to discard
        for player in gameState.players {
            let totalCards = player.resources.values.reduce(0, +)
            if totalCards > 7 {
                awaitingDiscards.insert(players[player.id].id)
                
                if player.id == localPlayerIndex {
                    showDiscardDialog(cardsToDiscard: totalCards / 2)
                }
            }
        }
        
        // Robber will be moved after discards
        if awaitingDiscards.isEmpty {
            awaitingRobberMove = true
            showMessage("Move the robber")
        }
    }
    
    private func showDiscardDialog(cardsToDiscard: Int) {
        // Create discard UI
        let discardOverlay = createDiscardOverlay(count: cardsToDiscard)
        discardOverlay.name = "discardOverlay"
        discardOverlay.zPosition = 2000
        self.addChild(discardOverlay)
    }
    
    private func createDiscardOverlay(count: Int) -> SKNode {
        let overlay = SKNode()
        
        // Background
        let background = SKShapeNode(rectOf: self.size)
        background.fillColor = .black.withAlphaComponent(0.8)
        overlay.addChild(background)
        
        // Discard window
        let window = SKShapeNode(rectOf: CGSize(width: 500, height: 300), cornerRadius: 15)
        window.fillColor = UIColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)
        window.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
        overlay.addChild(window)
        
        // Title
        let title = SKLabelNode(text: "Discard \(count) cards")
        title.fontName = "Helvetica-Bold"
        title.fontSize = 20
        title.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.65)
        overlay.addChild(title)
        
        // Add resource selection UI
        // ... (implement discard UI)
        
        return overlay
    }
    
    // MARK: - End Turn
    
    private func endNetworkTurn() {
        guard isMyTurn else { return }
        
        networkManager?.sendEndTurn()
        gameState.hasRolledDice = false
    }
    
    // MARK: - Helper Methods
    
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
    
    private func showChatOverlay() {
        // Implement chat UI
        let chatOverlay = createChatOverlay()
        chatOverlay.name = "chatOverlay"
        chatOverlay.zPosition = 2000
        self.addChild(chatOverlay)
    }
    
    private func createChatOverlay() -> SKNode {
        let overlay = SKNode()
        
        // Background
        let background = SKShapeNode(rectOf: self.size)
        background.fillColor = .black.withAlphaComponent(0.8)
        background.name = "chatBackground"
        overlay.addChild(background)
        
        // Chat window
        let window = SKShapeNode(rectOf: CGSize(width: 400, height: 500), cornerRadius: 15)
        window.fillColor = UIColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)
        window.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
        overlay.addChild(window)
        
        // Close button
        let closeButton = SKShapeNode(circleOfRadius: 20)
        closeButton.fillColor = .systemRed
        closeButton.position = CGPoint(x: self.size.width * 0.7, y: self.size.height * 0.7)
        closeButton.name = "closeChatButton"
        overlay.addChild(closeButton)
        
        return overlay
    }
    
    // MARK: - Placeholder Methods (implement based on your game logic)
    
    private func findNearestEdge(to location: CGPoint) -> (start: CGPoint, end: CGPoint, midpoint: CGPoint)? {
        // Implement edge finding logic
        return nil
    }
    
    private func findNearestVertex(to location: CGPoint) -> (position: CGPoint, adjacentTiles: [Int])? {
        // Implement vertex finding logic
        return nil
    }
    
    private func findNearestSettlement(to location: CGPoint) -> (position: CGPoint, playerId: Int)? {
        // Implement settlement finding logic
        return nil
    }
    
    private func findNearestTile(to location: CGPoint) -> (id: Int, position: CGPoint)? {
        // Implement tile finding logic
        return nil
    }
    
    private func getPlayersWithBuildingsAtTile(_ tile: (id: Int, position: CGPoint)) -> [String] {
        // Implement logic to find players with buildings adjacent to tile
        return []
    }
    
    private func showStealSelectionDialog(players: [String], tileId: Int) {
        // Implement player selection UI for stealing
    }
    
    private func enableFreeRoadBuilding(count: Int) {
        // Enable free road building mode
        roadBuildingModeActive = true
        freeRoadsRemaining = count
    }
    
    private func showResourceSelectionDialog(count: Int) {
        // Show dialog to select resources
    }
    
    private func showMonopolyResourceSelection() {
        // Show dialog to select resource for monopoly
    }
    
    private func updateBuildingButtons() {
        // Update building button states based on resources and turn
    }
}

// MARK: - Trade Offer Structure
struct TradeOffer {
    let fromPlayer: String
    let toPlayer: String?
    let offering: [ResourceType: Int]
    let requesting: [ResourceType: Int]
}

// MARK: - Development Card Type
enum DevelopmentCardType: String {
    case knight = "knight"
    case roadBuilding = "roadBuilding"
    case yearOfPlenty = "yearOfPlenty"
    case monopoly = "monopoly"
    case victoryPoint = "victoryPoint"
}

// MARK: - NetworkManagerDelegate
extension MultiplayerGameSceneComplete: NetworkManagerDelegate {
    func networkManager(_ manager: NetworkManager, didReceiveGameAction action: GameAction) {
        // Process incoming game actions from other players
        DispatchQueue.main.async {
            self.processNetworkAction(action)
        }
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
        DispatchQueue.main.async {
            if let player = self.players.first(where: { $0.id == playerId }) {
                self.showMessage("\(player.username) disconnected")
                
                // Update connection indicator
                if let connectionDot = self.childNode(withName: "//connection_\(playerId)") as? SKShapeNode {
                    connectionDot.fillColor = .systemRed
                }
            }
        }
    }
    
    private func processNetworkAction(_ action: GameAction) {
        switch action.type {
        case .diceRoll:
            if let value1 = action.data["value1"] as? Int,
               let value2 = action.data["value2"] as? Int {
                animateDiceRoll(value1: value1, value2: value2)
                
                if value1 + value2 == 7 {
                    handleSevenRolled()
                }
            }
            
        case .buildRoad:
            if let fromX = action.data["fromX"] as? Double,
               let fromY = action.data["fromY"] as? Double,
               let toX = action.data["toX"] as? Double,
               let toY = action.data["toY"] as? Double {
                // Place road on board
                let from = CGPoint(x: fromX, y: fromY)
                let to = CGPoint(x: toX, y: toY)
                placeRoadOnBoard(from: from, to: to, playerId: action.playerId)
            }
            
        case .buildSettlement:
            if let x = action.data["x"] as? Double,
               let y = action.data["y"] as? Double {
                // Place settlement on board
                let position = CGPoint(x: x, y: y)
                placeSettlementOnBoard(at: position, playerId: action.playerId)
            }
            
        case .buildCity:
            if let x = action.data["x"] as? Double,
               let y = action.data["y"] as? Double {
                // Upgrade settlement to city
                let position = CGPoint(x: x, y: y)
                upgradeToCityOnBoard(at: position, playerId: action.playerId)
            }
            
        case .trade:
            // Handle trade offer/acceptance
            processTradeoffer(action)
            
        case .endTurn:
            // Move to next player
            gameState.nextPlayer()
            updateTurnState()
            
        case .chat:
            if let message = action.data["message"] as? String {
                // Display chat message
                displayChatMessage(from: action.playerId, message: message)
            }
            
        case .moveRobber:
            if let tileId = action.data["tileId"] as? Int {
                // Move robber on board
                moveRobberOnBoard(to: tileId)
            }
            
        default:
            break
        }
        
        // Update UI after processing action
        updatePlayerUISection()
        updateTurnState()
    }
    
    private func placeRoadOnBoard(from: CGPoint, to: CGPoint, playerId: String) {
        // Implement road placement visuals
    }
    
    private func placeSettlementOnBoard(at position: CGPoint, playerId: String) {
        // Implement settlement placement visuals
    }
    
    private func upgradeToCityOnBoard(at position: CGPoint, playerId: String) {
        // Implement city upgrade visuals
    }
    
    private func processTradeoffer(_ action: GameAction) {
        // Implement trade processing
    }
    
    private func moveRobberOnBoard(to tileId: Int) {
        // Implement robber movement visuals
    }
    
    private func displayChatMessage(from playerId: String, message: String) {
        // Implement chat message display
    }
}