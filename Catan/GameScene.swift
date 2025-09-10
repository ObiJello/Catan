import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    var gameBoard: GameBoard!
    var gameState: GameState!
    let hexRadius: CGFloat = 50.0
    
    private var bank: Bank!
    
    var victoryPointGoal: Int = 10
    var discardLimit: Int = 7
    
    var portIndex: Int = -1
        
    internal var selectedBuildingType: BuildingType?  // Add to class properties
    internal var vertices: [VertexPoint] = []  // Add to class properties
    internal var edges: [EdgePoint] = []  // Add to class properties
    internal var tilePoints: [TilePoint] = []
    
    internal var diceNodes: [SKSpriteNode] = []
    internal var diceRolled: Bool = false
    
    var roadBuildingModeActive: Bool = false
    var freeRoadsRemaining: Int = 0
    
    var selectedMonopolyResource: ResourceType?
    var selectedYearOfPlentyResources: [ResourceType] = []
    var selectedTradeCards: [SKSpriteNode] = []
    var selectedToDiscard: [SKSpriteNode] = []
    private var resourceCardsContainer: SKNode!
    private var developmentCardsContainer: SKNode!
    private var partitionNode: SKSpriteNode?
    
    private var isRobberMoveMode: Bool = false
    private var robberNode: SKSpriteNode?
    
    var portNodes: [(portName: String, position: CGPoint)] = []
    
    var blockedPorts: Set<Coordinate> = []

    let textBlackColor = UIColor(red: 50/255.0, green: 50/255.0, blue: 50/255.0, alpha: 1.0)
    let textRedColor = UIColor(red: 192/255.0, green: 0/255.0, blue: 7/255.0, alpha: 1.0)
    let textGreenColor = UIColor(red: 14/255.0, green: 176/255.0, blue: 2/255.0, alpha: 1.0)

    var halfOfCards: Int = 0

    
    // New camera node for zooming/panning
    private var cameraNode: SKCameraNode!
    
    // UI layer for fixed (non-zooming) UI elements
    private var uiLayer: SKNode!
    
    
    // MARK: - Lifecycle & Notifications
    
    
    override func didMove(to view: SKView) {
        self.backgroundColor = UIColor(red: 11/255.0, green: 102/255.0, blue: 165/255.0, alpha: 1.0)
        setupCamera()
        setupGame()
        setupGestures()
        
        // Listen for any victory point changes.
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleVictoryPointsChanged),
                                               name: .victoryPointsDidChange,
                                               object: nil)
    }
    
    
    @objc private func handleVictoryPointsChanged(_ notification: Notification) {
        updatePlayerUISection()
    }
    
    override func update(_ currentTime: TimeInterval) {
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)
        
        // If we're in robber move mode, check if a robber highlight node was touched.
        if isRobberMoveMode {
            for node in touchedNodes {
                if node.name == "robberHighlight" {
                    // Find the corresponding tile using the tilePoints list.
                    for tilePoint in tilePoints {
                        if hypot(tilePoint.position.x - node.position.x, tilePoint.position.y - node.position.y) < 20 {
                            moveRobber(to: tilePoint.tile)
                            return // Process only one placement.
                        }
                    }
                }
            }
            return // Exit early if in robber mode.
        }
        
        // Only allow dice tap if we're in play phase, it's your turn, and dice haven't been rolled.
        if gameState.currentPhase == .play && gameState.currentPlayerIndex == 0 && !gameState.hasRolledDice {
            for node in touchedNodes {
                if node.name == "dice1" || node.name == "dice2" || node.name == "diceButton" {
                    rollDiceTapped()
                    return
                }
            }
        }
        
        for node in touchedNodes {
            if node.name == "diceButton" {
                // Only allow dice roll if it's your turn.
                if gameState.currentPlayerIndex != 0 {
                    print("Not your turn to roll dice.")
                } else {
                    if gameState.currentPhase != .play {
                        print("Dice cannot be rolled until setup is complete.")
                        return
                    }
                    if gameState.hasRolledDice {
                        print("Dice already rolled this turn.")
                        return
                    }
                    let diceRoll = gameState.rollDice()
                    print("Dice rolled: \(diceRoll)")
                    if let diceLabel = uiLayer.childNode(withName: "diceResult") as? SKLabelNode {
                        diceLabel.text = "Dice: \(diceRoll)"
                    } else {
                        let label = SKLabelNode(text: "Dice: \(diceRoll)")
                        label.fontSize = 24
                        label.fontColor = .white
                        let margin: CGFloat = 20
                        let x = -size.width / 2 + 120/2 + margin
                        let y = (-size.height / 2 + 50/2 + margin) + 50 + margin
                        label.position = CGPoint(x: x, y: y)
                        label.name = "diceResult"
                        uiLayer.addChild(label)
                    }
                    distributeResources(for: diceRoll)
                }
            }
            else if node.name == "Road_Button" {
                if gameState.currentPlayerIndex != 0 {
                    print("Not your turn to build.")
                } else if !gameState.hasRolledDice {
                    print("Roll Dice First")
                } else {
                    selectedBuildingType = .road
                    highlightValidEdges()
                }
            }
            else if node.name == "Settlement_Button" {
                if gameState.currentPlayerIndex != 0 {
                    print("Not your turn to build.")
                } else if !gameState.hasRolledDice {
                    print("Roll Dice First")
                } else {
                    selectedBuildingType = .settlement
                    highlightValidVertices()
                }
            }
            else if node.name == "City_Button" {
                if gameState.currentPlayerIndex != 0 {
                    print("Not your turn to build.")
                } else if !gameState.hasRolledDice {
                    print("Roll Dice First")
                } else {
                    selectedBuildingType = .city
                    highlightValidCityUpgrades()
                }
            }
            else if node.name == "Devcard_Button" {
                if !gameState.hasRolledDice {
                    print("Roll Dice First")
                } else {
                    handleBuyDevelopmentCard()
                }
            }
            else if node.name == "End_Turn_Button" {
               if gameState.currentPhase == .setup {
                    print("Cannot end turn during initial settlement placement.")
                } else if gameState.currentPhase == .play && !gameState.hasRolledDice {
                    print("You must roll dice before ending your turn.")
                } else if gameState.currentPlayerIndex != 0 {
                    print("Not your turn to end turn.")
                } else {
                    endTurn()
                }
            }
            else if node.name == "Trade_Button" {
                if gameState.currentPlayerIndex != 0 {
                    print("Not your turn.")
                } else if !gameState.hasRolledDice {
                    print("Roll Dice First")
                } else {
                    toggleTradeUISection()
                }
            }
            else if node.name == "TradeXButton" {
                resetTradeSelection()
                toggleTradeUISection()
                returnCards()
                updateResourceCards()
                removeSelectedCards()
                removeSelectedBankCards()
            }
            else if node.name == "TradeBankButton" {
                if checkBankButtonOpacity() == true {
                    trade()
                }
            }
            else if node.name == "TradeOpponentsButton" {
                if let container = uiLayer.childNode(withName: "TradePopUp_UI_Container") {
                    if checkTradePlayersButtonOpacity() == true {
                        toggleTradePopUpUISection()
                        deleteTradePopUpCards()
                        createTradePopUpUISection()
                        botEvaluateTrade()
                    }
                } else {
                    if checkTradePlayersButtonOpacity() == true {
                        createTradePopUpUISection()
                        botEvaluateTrade()
                    }
                }
            }
            if node.name == "cancelTradeRequest" {
                toggleTradePopUpUISection()
                deleteTradePopUpCards()
            }
            if node.name == "botTradeButton_1" {
                if checkBotTradeButtonOpacity(1) {
                    performTrade(withBotIndex: 1)
                }
            }
            if node.name == "botTradeButton_2" {
                if checkBotTradeButtonOpacity(2) {
                    performTrade(withBotIndex: 2)
                }
            }
            if node.name == "botTradeButton_3" {
                if checkBotTradeButtonOpacity(3) {
                    performTrade(withBotIndex: 3)
                }
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("resourceCard_"),
               uiLayer.childNode(withName: "Trade_UI_Container") == nil,
               uiLayer.childNode(withName: "DiscardCards_UI_Container") == nil {
                if gameState.currentPlayerIndex != 0 {
                    print("Not your turn.")
                } else if !gameState.hasRolledDice {
                    print("Roll Dice First")
                } else if let card = node as? SKSpriteNode {
                    toggleTradeUISection()
                    selectTradeCard(card, 1)
                    updateResourceCards()
                    return
                }
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("resourceCard_"),
               uiLayer.childNode(withName: "Trade_UI_Container") != nil, uiLayer.childNode(withName: "DiscardCards_UI_Container") == nil {
                
                if let card = node as? SKSpriteNode {
                    selectTradeCard(card, 1)
                    updateResourceCards()
                    return
                }
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("selected"),
               uiLayer.childNode(withName: "Trade_UI_Container") != nil {
                
                if let card = node as? SKSpriteNode {
                    selectTradeCard(card, -1)
                    updateResourceCards()
                    return
                }
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("resourceCard_"),
               uiLayer.childNode(withName: "DiscardCards_UI_Container") != nil {
                if let card = node as? SKSpriteNode {
                    let player = gameState.players[0]
                    let numSelected = player.selectedToDiscard.values.reduce(0, +)
                    if numSelected < halfOfCards {
                        selectDiscardCard(card, 1)
                        updateDiscardCardsUISection()
                        updateResourceCards()
                        return
                    } else {
                        print("Can't select more")
                    }
                }
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("discard"),
               uiLayer.childNode(withName: "DiscardCards_UI_Container") != nil {
                
                if let card = node as? SKSpriteNode {
                    selectDiscardCard(card, -1)
                    updateDiscardCardsUISection()
                    updateResourceCards()
                    return
                }
            }
            if node.name == "DiscardCardsButton" {
                let player = gameState.players[0]
                let numSelected = player.selectedToDiscard.values.reduce(0, +)
                if numSelected == halfOfCards {
                    discardCards()
                    toggleDiscardCardsUISection()
                    gameState.currentPhase = .play
                    if gameState.currentPlayerIndex != 0 {
                        performBotTurnAfterRobber()
                    } else {
                        isRobberMoveMode = true
                        highlightValidRobberTiles()
                        updateEndTurnButtonIcon()
                    }
                } else {
                    print("Selected cards count (\(numSelected)) does not equal the required halfOfCards (\(halfOfCards)).")
                }
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("bank_"),
               uiLayer.childNode(withName: "Trade_UI_Container") != nil {
                
                if let card = node as? SKSpriteNode {
                    selectBankCard(card, 1)
                    updateResourceCards()
                    return
                }
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("bnkSelected_"),
               uiLayer.childNode(withName: "Trade_UI_Container") != nil {
                
                if let card = node as? SKSpriteNode {
                    selectBankCard(card, -1)
                    updateResourceCards()
                    return
                }
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("developmentCard_knight"),
               uiLayer.childNode(withName: "developmentCardsContainer") != nil {
                if gameState.currentPlayerIndex != 0 {
                    print("Not your turn.")
                } else {
                    toggleKnightUISection()
                    return
                }
            }
            if node.name == "CancelKnightButton" {
                toggleKnightUISection()
            }
            if node.name == "UseKnightButton" {
                useKnight()
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("developmentCard_road"),
               uiLayer.childNode(withName: "developmentCardsContainer") != nil {
                if gameState.currentPlayerIndex != 0 {
                    print("Not your turn.")
                } else {
                    toggleRoadBuildingUISection()
                    return
                }
            }
            if node.name == "CancelRoadBuildingButton" {
                toggleRoadBuildingUISection()
            }
            if node.name == "UseRoadBuildingButton" {
                selectedBuildingType = .road
                highlightValidEdges()
                toggleRoadBuildingUISection()
                roadBuildingModeActive = true
                freeRoadsRemaining = 2
                
                print("Road Building mode activated: Place two free roads.")
                return
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("developmentCard_victory"),
               uiLayer.childNode(withName: "developmentCardsContainer") != nil {
                if gameState.currentPlayerIndex != 0 {
                    print("Not your turn.")
                } else {
                    toggleVictoryPointUISection()
                    return
                }
            }
            if node.name == "UseVictoryPointButton" {
                toggleVictoryPointUISection()
                return
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("developmentCard_monopoly"),
               uiLayer.childNode(withName: "developmentCardsContainer") != nil {
                if gameState.currentPlayerIndex != 0 {
                    print("Not your turn.")
                } else {
                    toggleMonopolyUISection()
                    return
                }
            }
            if node.name == "CancelMonopolyButton" {
                toggleMonopolyUISection()
                self.selectedMonopolyResource = nil
            }
            if node.name == "UseMonopolyButton" {
                useMonopoly()
                toggleMonopolyUISection()
            }
            if let nodeName = node.name, nodeName.hasPrefix("monopolyResource_") {
                let resourceTypeStr = nodeName.replacingOccurrences(of: "monopolyResource_", with: "")
                if let resourceType = ResourceType(rawValue: resourceTypeStr) {
                    showSelectedResource(resource: resourceType)
                    return
                }
            }
            if let nodeName = node.name,
               nodeName.hasPrefix("developmentCard_year"),
               uiLayer.childNode(withName: "developmentCardsContainer") != nil {
                if gameState.currentPlayerIndex != 0 {
                    print("Not your turn.")
                } else {
                    toggleYearOfPlentyUISection()
                    return
                }
            }
            if node.name == "CancelYearOfPlentyButton" {
                toggleYearOfPlentyUISection()
                selectedYearOfPlentyResources.removeAll()
            }
            if node.name == "UseYearOfPlentyButton" {
                useYearOfPlenty()
                toggleYearOfPlentyUISection()
            }
            if let nodeName = node.name, nodeName.hasPrefix("yearOfPlentyResource_") {
                let resourceTypeStr = nodeName.replacingOccurrences(of: "yearOfPlentyResource_", with: "")
                if let resourceType = ResourceType(rawValue: resourceTypeStr) {
                    showSelectedResourceForYearOfPlenty(resource: resourceType)
                    return
                }
            }
            if let nodeName = node.name, nodeName.hasPrefix("YearOfPlentySelected_") {
                let indexString = nodeName.replacingOccurrences(of: "YearOfPlentySelected_", with: "")
                if let index = Int(indexString), index < selectedYearOfPlentyResources.count {
                    selectedYearOfPlentyResources.remove(at: index)
                    node.removeFromParent()
                }
            }
        }
        
        // Process building placement touches on the board.
        if let buildingType = selectedBuildingType {
            if gameState.currentPlayerIndex != 0 {
                print("Not your turn to place a building.")
                unhighlightAllPoints()
                return
            }
            switch buildingType {
            case .road:
                if roadBuildingModeActive {
                    handleFreeRoadPlacement(at: location)
                } else {
                    handleRoadPlacement(at: location)
                }
            case .settlement:
                handleSettlementPlacement(at: location)
            case .city:
                handleCityPlacement(at: location)
            }
        }
    }
    
    
    // MARK: - Initial Setup & Scene Configuration

    
    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2 + 20, y: size.height / 2)
        cameraNode.setScale(1.20)
        addChild(cameraNode)
        self.camera = cameraNode
        
        // Create a UI layer that will be fixed and always appear above the board.
        uiLayer = SKNode()
        uiLayer.zPosition = 1000  // Ensure a high zPosition so UI is drawn on top
        cameraNode.addChild(uiLayer)
    }
    
    private func setupGestures() {
        if let view = self.view {
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinchGesture.cancelsTouchesInView = true
            view.addGestureRecognizer(pinchGesture)
            
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            panGesture.cancelsTouchesInView = true
            view.addGestureRecognizer(panGesture)
        }
    }

    @objc private func handlePinch(_ sender: UIPinchGestureRecognizer) {
        guard let camera = self.camera else { return }
        if sender.state == .changed || sender.state == .ended {
            // Adjust scale (lower scale = zoom in, higher = zoom out)
            let newScale = camera.xScale * (1 / sender.scale)
            print(newScale)
            // Limit zoom level between 0.5 (max zoom in) and 2.0 (max zoom out)
            let clampedScale = max(0.5, min(newScale, 2.0))
            camera.setScale(clampedScale)
            sender.scale = 1.0
            clampCameraPosition()
        }
    }
    
    @objc private func handlePan(_ sender: UIPanGestureRecognizer) {
        guard let camera = self.camera, let view = self.view else { return }
        let translation = sender.translation(in: view)
        // Adjust camera position; note: flip the y axis because view coordinates are inverted
        camera.position = CGPoint(x: camera.position.x - translation.x * camera.xScale,
                                  y: camera.position.y + translation.y * camera.yScale)
        sender.setTranslation(.zero, in: view)
        clampCameraPosition()
    }
    
    // Clamp the camera's position so that the game board always stays (mostly) on screen.
    private func clampCameraPosition() {
        guard let camera = self.camera else { return }
        
        // Compute the board's bounding rectangle based on all tile positions.
        var boardRect = CGRect.null
        for tile in gameBoard.tiles {
            let tileRect = CGRect(
                x: tile.position.x - hexRadius,
                y: tile.position.y - hexRadius,
                width: 2 * hexRadius,
                height: 2 * hexRadius
            )
            boardRect = boardRect.union(tileRect)
        }
        
        // Determine the visible size (in scene coordinates) based on the camera's scale.
        let visibleWidth = size.width * camera.xScale
        let visibleHeight = size.height * camera.yScale
        let halfWidth = visibleWidth / 2
        let halfHeight = visibleHeight / 2
        
        // Board dimensions.
        let boardWidth = boardRect.width
        let boardHeight = boardRect.height
        
        // Calculate clamping bounds so that at least half the board remains visible.
        // This allows the camera's center to move further than before.
        let minCameraX = boardRect.minX + boardWidth / 2 - halfWidth
        let maxCameraX = boardRect.maxX - boardWidth / 2 + halfWidth
        let minCameraY = boardRect.minY + boardHeight / 2 - halfHeight
        let maxCameraY = boardRect.maxY - boardHeight / 2 + halfHeight
        
        var newX = camera.position.x
        var newY = camera.position.y
        
        newX = max(minCameraX, min(newX, maxCameraX))
        newY = max(minCameraY, min(newY, maxCameraY))
        
        camera.position = CGPoint(x: newX, y: newY)
    }

    private func setupGame() {
        print("Width: \(size.width), Height \(size.height)")
        gameBoard = GameBoard()
        gameState = GameState(playerCount: 4) // Standard Catan has 2-4 players
        
        // Read configuration values from GameConfigScene via userData.
        if let config = self.userData {
            // Configure the human player's color.
            if let playerColorString = config["playerColor"] as? String {
                gameState.players[0].assetColor = playerColorString
            }
            // Configure bot colors.
            if let botColorNames = config["botColors"] as? [String] {
                for (index, colorName) in botColorNames.enumerated() {
                    if index + 1 < gameState.players.count {
                        gameState.players[index + 1].assetColor = colorName
                    }
                }
            }
            // Set the victory point goal and discard limit.
            if let vpGoal = config["victoryPointGoal"] as? Int {
                victoryPointGoal = vpGoal
                gameState.victoryPointGoal = self.victoryPointGoal
            }
            if let dLimit = config["discardLimit"] as? Int {
                discardLimit = dLimit
            }
        }
        
        //Create bank
        bank = Bank()

        // Create the game board tiles
        createGameBoard()
        
        // Generate board points from the tiles
        let hexGrid = HexGrid(size: 2, hexRadius: hexRadius)
        let boardPoints = hexGrid.generateBoardPoints(from: gameBoard.tiles)
        vertices = boardPoints.vertices
        edges = boardPoints.edges
        tilePoints = hexGrid.generateTilePoints(from: gameBoard.tiles)
        
        // All UI related setup
        createInGameUI()
        
        // Start in setup phase
        startSetupPhase()
        
        // Begin with settlement placement
        selectedBuildingType = .settlement
        highlightValidVertices()
        
        createAllPortPiers()
        
        setupResourceCardsContainer()
        setupDevelopmentCardsContainer()
        
        updateResourceCards()
        updateDevelopmentCards()
    }
    
    func createInGameUI() {
        addBottomUISection()
        createBuildingButtons()
        updateBuildingButtonIcons()
        updatePlayerUISection()
        createPlayerUISection()
    }
    
    
    // MARK: - Board & Tile Creation
    
    
    private func createGameBoard() {
        let boardSize = 2
        let hexGrid = HexGrid(size: boardSize, hexRadius: hexRadius)
        
        let resourceDistribution: [ResourceType] = [
            .wood, .wood, .wood, .wood,
            .brick, .brick, .brick,
            .sheep, .sheep, .sheep, .sheep,
            .wheat, .wheat, .wheat, .wheat,
            .ore, .ore, .ore,
            .desert
        ]
        let numberTokens = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]
        let shuffledResources = resourceDistribution.shuffled()
        
        let centerX = size.width * 0.5
        let centerY = size.height * 0.5
        
        let hexCoords = hexGrid.generateHexCoords(for: boardSize)
        // Build tile information (only for the first 19 hexes)
        var tileInfos: [(coord: HexCoord, resource: ResourceType, position: CGPoint)] = []
        var coordToIndex: [HexCoord: Int] = [:]
        
        for (index, coord) in hexCoords.enumerated() {
            if index >= 19 { break }
            let hexPosition = hexGrid.hexToPixel(hex: coord)
            let position = CGPoint(x: centerX + hexPosition.x, y: centerY + hexPosition.y)
            let resource = shuffledResources[index]
            tileInfos.append((coord: coord, resource: resource, position: position))
            coordToIndex[coord] = index
        }
        
        // Backtracking token assignment for non-desert tiles
        var tokenAssignments = Array<Int?>(repeating: nil, count: tileInfos.count)
        var availableTokens = numberTokens.shuffled()
        
        // Helper: get neighbor indices using axial offsets
        func getNeighborIndices(for index: Int) -> [Int] {
            let tile = tileInfos[index]
            let neighborsAxial = [
                HexCoord(q: tile.coord.q + 1, r: tile.coord.r),
                HexCoord(q: tile.coord.q - 1, r: tile.coord.r),
                HexCoord(q: tile.coord.q, r: tile.coord.r + 1),
                HexCoord(q: tile.coord.q, r: tile.coord.r - 1),
                HexCoord(q: tile.coord.q + 1, r: tile.coord.r - 1),
                HexCoord(q: tile.coord.q - 1, r: tile.coord.r + 1)
            ]
            var indices: [Int] = []
            for neighbor in neighborsAxial {
                if let idx = coordToIndex[neighbor] {
                    indices.append(idx)
                }
            }
            return indices
        }
        
        // Backtracking function: assign a token for each tile (skip desert)
        func backtrack(_ index: Int) -> Bool {
            if index == tileInfos.count {
                return true
            }
            // If this tile is a desert, token remains nil
            if tileInfos[index].resource == .desert {
                tokenAssignments[index] = nil
                return backtrack(index + 1)
            }
            // Try each available token for non-desert tiles
            for i in 0..<availableTokens.count {
                let token = availableTokens[i]
                // If token is 6 or 8, ensure no neighbor (that is already assigned) has a 6 or 8
                if token == 6 || token == 8 {
                    let neighborIndices = getNeighborIndices(for: index)
                    var conflict = false
                    for n in neighborIndices {
                        if n < index, let neighborToken = tokenAssignments[n] {
                            if neighborToken == 6 || neighborToken == 8 {
                                conflict = true
                                break
                            }
                        }
                    }
                    if conflict { continue }
                }
                tokenAssignments[index] = token
                let removed = availableTokens.remove(at: i)
                if backtrack(index + 1) {
                    return true
                }
                // Backtrack if assignment leads to no solution
                tokenAssignments[index] = nil
                availableTokens.insert(removed, at: i)
            }
            return false
        }
        
        // Run the backtracking. In the unlikely event of failure, fallback to a simple assignment.
        if !backtrack(0) {
            var tokenIndex = 0
            for i in 0..<tileInfos.count {
                if tileInfos[i].resource != .desert {
                    tokenAssignments[i] = numberTokens[tokenIndex]
                    tokenIndex += 1
                } else {
                    tokenAssignments[i] = nil
                }
            }
        }
        
        // Create tiles using the computed token assignments
        for i in 0..<tileInfos.count {
            let info = tileInfos[i]
            let token = tokenAssignments[i]
            let tile = Tile(resourceType: info.resource, diceValue: token, position: info.position)
            gameBoard.tiles.append(tile)
            createTileSprite(for: tile)
        }
        
        // Create shore tiles as before
        createShoreTiles(hexGrid: hexGrid, boardSize: boardSize)
    }
    
    private func createTileSprite(for tile: Tile) {
        // Determine asset name based on the tile's resource type.
        let assetName: String
        switch tile.resourceType {
        case .brick:
            assetName = "tile_brick"
        case .ore:
            assetName = "tile_ore"
        case .wood:
            assetName = "tile_lumber"  // wood maps to lumber
        case .wheat:
            assetName = "tile_grain"
        case .sheep:
            assetName = "tile_wool"
        case .desert:
            assetName = "tile_desert"
        }
        
        // Load texture and create the tile node.
        let texture = SKTexture(imageNamed: assetName)
        let tileNode = SKSpriteNode(texture: texture)
        tileNode.size = CGSize(width: hexRadius * 1.75, height: hexRadius * 2)
        tileNode.position = tile.position
        tileNode.zPosition = 0
        tileNode.name = "tile_\(Int(tile.position.x))_\(Int(tile.position.y))"
        addChild(tileNode)
        
        // Optionally add the dice token if applicable.
        if let diceValue = tile.diceValue {
            let tokenAssetName = "prob_\(diceValue)"
            let tokenTexture = SKTexture(imageNamed: tokenAssetName)
            let tokenNode = SKSpriteNode(texture: tokenTexture)
            let scaleFactor: CGFloat = 0.7
            tokenNode.size = CGSize(width: hexRadius * scaleFactor, height: hexRadius * scaleFactor)
            let verticalOffset: CGFloat = 15.0
            tokenNode.position = CGPoint(x: tile.position.x, y: tile.position.y - verticalOffset)
            tokenNode.zPosition = 0.01
            addChild(tokenNode)
        }
        
        // For desert tiles, initialize the robber sprite if it hasn't been created.
        if tile.resourceType == .desert {
            let robberOffsetX: CGFloat = -25      // Horizontal offset
            let robberOffsetY: CGFloat = 10       // Vertical offset
            let robberScaleFactor: CGFloat = 0.7    // Scale factor relative to hexRadius
            if robberNode == nil {  // Only create once
                let robberTexture = SKTexture(imageNamed: "icon_robber")
                let newRobberNode = SKSpriteNode(texture: robberTexture)
                newRobberNode.size = CGSize(width: hexRadius * robberScaleFactor, height: hexRadius * robberScaleFactor)
                newRobberNode.position = CGPoint(x: tile.position.x + robberOffsetX, y: tile.position.y + robberOffsetY)
                newRobberNode.zPosition = 5
                newRobberNode.name = "robber"
                addChild(newRobberNode)
                robberNode = newRobberNode
            }
        }
    }
    
    private func createShoreTiles(hexGrid: HexGrid, boardSize: Int) {
        // Generate coordinates for the surrounding shore layer
        let shoreCoords = hexGrid.generateHexCoords(for: boardSize + 1)
            .filter { hex in
                !hexGrid.generateHexCoords(for: boardSize).contains(hex)
            }
        
        guard !shoreCoords.isEmpty else {
            print("No shore coordinates generated")
            return
        }
        
        let centerX = size.width * 0.5
        let centerY = size.height * 0.5
        
        // Define the 1-based indices of shore tiles that should have a port.
        // (Indices: 2, 3, 6, 7, 10, 13, 15, 16, 18)
        let portIndices: Set<Int> = [2, 4, 8, 5, 12, 13, 9, 16, 18]
        
        // Build an array with exactly 4 generic ports ("port.svg") and 5 resource-specific ports.
        var availablePorts: [String] = Array(repeating: "port.svg", count: 4) +
        ["port_wool.svg", "port_grain.svg", "port_brick.svg", "port_lumber.svg", "port_ore.svg"]
        availablePorts.shuffle()  // Randomize assignment
        
        // Test variables for port icon placement (adjust these as needed)
        let portIconOffset = CGPoint(x: -3, y: 10)  // Change offset to test different positions
        let portIconSize: CGFloat = 55.0          // Adjust icon size as desired
        
        // Loop over the shore coordinates (using 1-based indexing)
        for (i, coord) in shoreCoords.enumerated() {
            let currentIndex = i + 1
            
            let hexPosition = hexGrid.hexToPixel(hex: coord)
            let position = CGPoint(x: centerX + hexPosition.x, y: centerY + hexPosition.y)
            
            // Default asset name and rotation
            var assetName = "tile_shore_2_sswwww"
            var rotation: CGFloat = 0.0
            
            // Determine rotation based on the current index using a switch statement.
            switch currentIndex {
            case 1..<4:
                rotation = (CGFloat.pi / 3) * 11
            case 4, 6, 8:
                rotation = (CGFloat.pi / 3) * 10
            case 10, 12, 14:
                rotation = (CGFloat.pi / 3) * 9
            case 11, 13, 15:
                rotation = CGFloat.pi / 3
            case 16...18:
                rotation = (CGFloat.pi / 3) * 2
            default:
                rotation = 0.0
            }
            
            // Determine asset name (for example, some indices use a different tile asset)
            switch currentIndex {
            case 1, 4, 9, 10, 15, 18:
                assetName = "tile_shore_1"
            default:
                break
            }
            
            // Create the shore tile with the computed rotation.
            createShoreTile(position: position, assetName: assetName, rotation: rotation)
            
            // If this tile is designated to have a port and there are ports left to assign...
            if portIndices.contains(currentIndex), !availablePorts.isEmpty {
                let portIconName = availablePorts.removeFirst()
                print("\(portIconName) at \(currentIndex)")
                let portTexture = SKTexture(imageNamed: portIconName)
                let portNode = SKSpriteNode(texture: portTexture)
                portNode.size = CGSize(width: portIconSize, height: portIconSize)
                // Adjust the port icon's position using the offset variable
                portNode.position = CGPoint(x: position.x + portIconOffset.x, y: position.y + portIconOffset.y)
                // Ensure the port icon appears above the shore tile (zPosition higher than the tile)
                portNode.zPosition = 5  // you can define shoreTileZPosition as -1 or use a constant
                addChild(portNode)
                
                // Save the port's name and position for unlocking later.
                portNodes.append((portName: portIconName, position: portNode.position))
            }
        }
    }
    
    private func createShoreTile(position: CGPoint, assetName: String, rotation: CGFloat) {
        let texture = SKTexture(imageNamed: assetName)
        let shoreNode = SKSpriteNode(texture: texture)
        shoreNode.size = CGSize(width: hexRadius * 1.75, height: hexRadius * 2)
        shoreNode.position = position
        shoreNode.zPosition = -1 // Behind main tiles
        shoreNode.alpha = 1.0
        shoreNode.zRotation = rotation
        addChild(shoreNode)
    }
    
    
    // MARK: - Ports
    
    
    func unlockPorts(for vertex: VertexPoint, by player: Player) {
        // Define a threshold distance within which a vertex “touches” a port.
        let threshold: CGFloat = 70.0
        if !blockedPorts.contains(Coordinate(x: vertex.position.x, y: vertex.position.y)) {
            for port in portNodes {
                let distance = hypot(vertex.position.x - port.position.x, vertex.position.y - port.position.y)
                if distance <= threshold {
                    // Only add the port if it hasn't been unlocked already.
                    if !player.portsUnlocked.contains(port.portName) {
                        player.portsUnlocked.append(port.portName)
                        print("Player \(player.id) unlocked port: \(port.portName)")
                    }
                }
            }
        }
    }
        
    func createAllPortPiers() {
        // Define the threshold distance within which a vertex is considered "near" a port.
        let portThreshold: CGFloat = 70.0

        // Loop through every port stored in portNodes.
        for port in portNodes {
            // For each port, filter the board's vertices (assume these are stored in self.vertices)
            // to find those that are within the threshold distance.
            let nearbyVertices = vertices.filter { vertex in
                let distance = hypot(vertex.position.x - port.position.x,
                                     vertex.position.y - port.position.y)
                return distance <= portThreshold
            }
            
            // Place port piers for this port using the nearby vertices.
            placePortPiers(nearPort: port, fromVertices: nearbyVertices)
        }
    }

    func placePortPiers(nearPort port: (portName: String, position: CGPoint), fromVertices vertices: [VertexPoint]) {
        let threshold: CGFloat = 70.0
        
        // Sort vertices by x coordinate then y coordinate for a consistent order.
        let sortedVertices = vertices.sorted { (v1, v2) -> Bool in
            if v1.position.x == v2.position.x {
                return v1.position.y < v2.position.y
            }
            return v1.position.x < v2.position.x
        }
        
        // Loop through all vertices provided.
        for vertex in sortedVertices {
            portIndex += 1

            if !((portIndex == 0) || (portIndex == 5) || (portIndex == 10) || (portIndex == 14) || (portIndex == 18) || (portIndex == 19)) {
                // Check if this vertex is close enough to the port.
                let distance = hypot(vertex.position.x - port.position.x, vertex.position.y - port.position.y)
                if distance <= threshold {
                    // For this vertex, choose the edge whose direction best faces the port.
                    if let chosenEdge = findEdgeWithClosestAngle(toPort: port.position, fromVertex: vertex.position, maxDistance: 35) {
                        // Create the pier sprite.
                        let assetName = "port_pier"
                        let pierTexture = SKTexture(imageNamed: assetName)
                        let pierNode = SKSpriteNode(texture: pierTexture)
                        pierNode.size = CGSize(width: 10, height: 30)  // Height set to 30.
                        
                        // Determine the edge's direction.
                        let pos1 = chosenEdge.vertices[0].position
                        let pos2 = chosenEdge.vertices[1].position
                        let dx = pos2.x - pos1.x
                        let dy = pos2.y - pos1.y
                        let edgeAngle = atan2(dy, dx)
                        
                        // Offset the pier's position by 30 points along the edge's direction (continuing the line).
                        let offsetX = 40 * cos(edgeAngle)
                        let offsetY = 40 * sin(edgeAngle)
                        
                        switch portIndex {
                        case 1, 2, 4, 9, 11, 13, 15, 16, 22:
                            pierNode.position = CGPoint(x: chosenEdge.position.x + offsetX,
                                                        y: chosenEdge.position.y + offsetY)
                        case 3, 6, 7, 8, 12, 17, 20, 21, 23:
                            pierNode.position = CGPoint(x: chosenEdge.position.x - offsetX,
                                                        y: chosenEdge.position.y - offsetY)
                        default:
                            break
                        }
                        
                        // Align the pier's rotation so that its "up" (default) aligns with the edge.
                        // Assuming the pier asset is drawn facing upward.
                        pierNode.zRotation = edgeAngle - .pi/2
                        pierNode.zPosition = 1  // Adjust as needed.
                        pierNode.name = "pier_\(pierNode.position.x)_\(pierNode.position.y)"
                        
                        addChild(pierNode)
                    }
                }
            } else {
                blockedPorts.insert(Coordinate(x: vertex.position.x, y: vertex.position.y))
            }
        }
    }
    
    // Returns the minimal angular difference between two angles (in radians).
    func angleDifference(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let diff = abs(a - b).truncatingRemainder(dividingBy: 2 * .pi)
        return diff > .pi ? 2 * .pi - diff : diff
    }

    // Among all edges within maxDistance from vertexPosition, returns the one
    // whose (undirected) angle is closest to the angle from the edge's midpoint to portPosition.
    func findEdgeWithClosestAngle(toPort portPosition: CGPoint, fromVertex vertexPosition: CGPoint, maxDistance: CGFloat) -> EdgePoint? {
        // Filter edges that are within maxDistance from the vertex.
        let candidateEdges = edges.filter { edge in
            let dist = hypot(vertexPosition.x - edge.position.x, vertexPosition.y - edge.position.y)
            return dist <= maxDistance && edge.vertices.count >= 2
        }
        
        var bestEdge: EdgePoint?
        var bestAngleDiff: CGFloat = CGFloat.greatestFiniteMagnitude
        
        // For each candidate, calculate the edge's direction and compare with the port direction.
        for edge in candidateEdges {
            // Compute edge's direction using its two vertices.
            let pos1 = edge.vertices[0].position
            let pos2 = edge.vertices[1].position
            let dx = pos2.x - pos1.x
            let dy = pos2.y - pos1.y
            let edgeAngle = atan2(dy, dx)
            
            // Compute the direction from the edge's midpoint to the port.
            let portVector = CGPoint(x: portPosition.x - edge.position.x,
                                     y: portPosition.y - edge.position.y)
            let portAngle = atan2(portVector.y, portVector.x)
            
            // Because the edge is undirected, check both possibilities.
            let diff1 = angleDifference(edgeAngle, portAngle)
            let diff2 = angleDifference(edgeAngle + .pi, portAngle)
            let diff = min(diff1, diff2)
            
            if diff < bestAngleDiff {
                bestAngleDiff = diff
                bestEdge = edge
            }
        }
        
        return bestEdge
    }
    
    
    // MARK: - Dice Management

    
    private func createDiceNodes() {
        // Remove any existing dice nodes
        diceNodes.forEach { $0.removeFromParent() }
        diceNodes.removeAll()
        
        let diceSize = CGSize(width: 60, height: 60)
        let marginX: CGFloat = 15
        let marginY: CGFloat = 180
        let spacing: CGFloat = 10
        
        // Calculate total width for the two dice and spacing.
        let totalDiceWidth = diceSize.width * 2 + spacing
        
        // Determine the right edge of the screen (with a margin).
        let rightEdge = size.width / 2 - marginX
        
        // Calculate the starting x so that the row is right-aligned.
        // This is the center of the leftmost dice.
        let startX = rightEdge - totalDiceWidth + diceSize.width / 2
        let startY = -size.height / 2 + diceSize.height / 2 + marginY
        
        // Create two dice with random initial faces
        let initialValue1 = Int.random(in: 1...6)
        let initialValue2 = Int.random(in: 1...6)
        
        let dice1 = SKSpriteNode(imageNamed: "dice_\(initialValue1)")
        dice1.size = diceSize
        dice1.position = CGPoint(x: startX, y: startY)
        dice1.name = "dice1"
        dice1.zPosition = 5
        
        let dice2 = SKSpriteNode(imageNamed: "dice_\(initialValue2)")
        dice2.size = diceSize
        dice2.position = CGPoint(x: startX + diceSize.width + 10, y: startY)
        dice2.name = "dice2"
        dice2.zPosition = 5
        
        uiLayer.addChild(dice1)
        uiLayer.addChild(dice2)
        diceNodes.append(dice1)
        diceNodes.append(dice2)
        
        // Only enable dice animation (i.e. allow rolling) if we're in play phase and it's your turn.
        if gameState.currentPhase == .play && gameState.currentPlayerIndex == 0 && !gameState.hasRolledDice {
            startDiceAnimation()
        } else {
            stopDiceAnimation()
        }
    }
    
    private func startDiceAnimation() {
        for dice in diceNodes {
            dice.removeAction(forKey: "pulsate")
            // Remove any gray overlay by resetting the color blend factor.
            dice.colorBlendFactor = 0.0
            
            let scaleUp = SKAction.scale(to: 1.2, duration: 1.0)
            let scaleDown = SKAction.scale(to: 1.0, duration: 1.0)
            let pulseSequence = SKAction.sequence([scaleUp, scaleDown])
            let pulseForever = SKAction.repeatForever(pulseSequence)
            dice.run(pulseForever, withKey: "pulsate")
        }
    }
    
    private func stopDiceAnimation() {
        for dice in diceNodes {
            dice.removeAction(forKey: "pulsate")
            // Apply a gray overlay.
            dice.color = .gray
            dice.colorBlendFactor = 0.8
        }
    }
    
    // Called when the human taps the dice.
    private func rollDiceTapped() {
        guard gameState.currentPhase == .play,
              gameState.currentPlayerIndex == 0,
              !gameState.hasRolledDice else {
            print("Dice cannot be rolled at this time.")
            return
        }
        
        let roll1 = Int.random(in: 1...6)
        let roll2 = Int.random(in: 1...6)
        diceNodes[0].texture = SKTexture(imageNamed: "dice_\(roll1)")
        diceNodes[1].texture = SKTexture(imageNamed: "dice_\(roll2)")
        diceRolled = true
        gameState.hasRolledDice = true
        stopDiceAnimation()
        
        print("Player rolled: \(roll1) and \(roll2)")
        // Process dice roll (e.g. distribute resources)
        distributeResources(for: roll1 + roll2)
        
        updateEndTurnButtonIcon()
    }
    
    // Called automatically on a bot turn.
    private func rollDiceForBot() {
        let roll1 = Int.random(in: 1...6)
        let roll2 = Int.random(in: 1...6)
        diceNodes[0].texture = SKTexture(imageNamed: "dice_\(roll1)")
        diceNodes[1].texture = SKTexture(imageNamed: "dice_\(roll2)")
        
        gameState.currentDiceRoll = roll1 + roll2
        gameState.hasRolledDice = true
        stopDiceAnimation()
        
        print("Bot rolled: \(roll1) and \(roll2)")
        distributeResources(for: gameState.currentDiceRoll)
    }
    
    // Reset dice for your turn: clear roll flag and start pulsating.
    private func resetDiceForPlayerTurn() {
        gameState.hasRolledDice = false
        diceRolled = false
        startDiceAnimation()
        updateEndTurnButtonIcon()
    }
    
    private func distributeResources(for diceRoll: Int) {
        // Skip if 7 is rolled (that's when the robber moves)
        if diceRoll == 7 {
            print("Robber will move!")
            let resourceCount = gameState.players[0].resources.values.reduce(0, +)
            if resourceCount > discardLimit  {
                toggleDiscardCardsUISection()
            }
            if gameState.currentPlayerIndex == 0 {
                if gameState.currentPhase == .play {
                    isRobberMoveMode = true
                    highlightValidRobberTiles()
                    updateEndTurnButtonIcon()
                }
            } else {
                if gameState.currentPhase == .play {
                    botMoveRobber()
                }
            }
            return
        }
        
        // Find all tiles with the matching dice value and without the robber.
        let matchingTiles = gameBoard.tiles.filter { tile in
            return tile.diceValue == diceRoll && !tile.hasRobber
        }
        
        // Distribute resources for each matching tile.
        for tile in matchingTiles {
            let adjacentBuildings = getAdjacentBuildings(to: tile)
            for building in adjacentBuildings {
                let ownerId = building.ownerId
                let resourceType = tile.resourceType
                let resourceAmount = building.type == .city ? 2 : 1
                
                if var currentAmount = gameState.players[ownerId].resources[resourceType] {
                    gameState.players[ownerId].resources[resourceType] = currentAmount + resourceAmount
                }
                updateResourceCards()
                updateBuildingButtonIcons()
                updatePlayerUISection()
            }
            // Flash the tile to show resource distribution.
            flashTile(for: tile)
        }
    }
    
    // Updated flashTile function with a duration parameter.
    private func flashTile(for tile: Tile, duration: TimeInterval = 2.0) {
        let tileName = "tile_\(Int(tile.position.x))_\(Int(tile.position.y))"
        guard let tileNode = self.childNode(withName: tileName) as? SKSpriteNode else { return }
        
        let grayOut = SKAction.run {
            tileNode.color = .gray
            tileNode.colorBlendFactor = 0.8
        }
        let wait = SKAction.wait(forDuration: duration)
        let restore = SKAction.run {
            tileNode.colorBlendFactor = 0.0
        }
        let sequence = SKAction.sequence([grayOut, wait, restore])
        tileNode.run(sequence)
    }
    
    
    private func awardInitialResources(for vertex: VertexPoint) {
        let currentPlayer = gameState.players[gameState.currentPlayerIndex]
        
        // Award one resource for each adjacent tile (skip desert and tiles with the robber).
        for tile in vertex.adjacentHexes {
            if tile.resourceType == .desert || tile.hasRobber {
                continue
            }
            
            currentPlayer.resources[tile.resourceType, default: 0] += 1
            updateResourceCards()
            updateBuildingButtonIcons()
            updatePlayerUISection()
            
            // Flash the tile to indicate resource gain.
            flashTile(for: tile, duration: 0.5)
        }
    }
    
    // Helper function to find buildings adjacent to a tile
    private func getAdjacentBuildings(to tile: Tile) -> [Building] {
        // Find all vertices that are adjacent to this tile
        let adjacentVertices = vertices.filter { vertex in
            vertex.adjacentHexes.contains { $0 === tile }
        }
        
        // Get all buildings (settlements or cities) on these vertices
        return adjacentVertices.compactMap { $0.building }
    }
    
    
    // MARK: - Setup Phase Logic
    
    
    private func startSetupPhase() {
        gameState.currentPhase = .setup
        print("Starting setup phase")
    }
    
    private func handleSetupPhaseNextStep() {
        let totalPlayers = gameState.players.count
        let settlementsCount = gameBoard.buildings.filter { $0.type == .settlement }.count
        let roadsCount = gameBoard.buildings.filter { $0.type == .road }.count
        
        // If the current player hasn’t finished placing their road, wait.
        if roadsCount < settlementsCount {
            return
        }
        
        // First round: each player places one settlement (forward order)
        if settlementsCount < totalPlayers {
            gameState.nextPlayer() // increments normally
            if let instructionLabel = uiLayer.childNode(withName: "instructionLabel") as? SKLabelNode {
                instructionLabel.text = "Player \(gameState.currentPlayerIndex + 1): Place your first settlement"
            }
        }
        // Second round: reverse order for settlement placement
        else if settlementsCount < totalPlayers * 2 {
            // At the very start of the second round, set index to the last player
            if settlementsCount == totalPlayers && roadsCount == totalPlayers {
                gameState.currentPlayerIndex = totalPlayers - 1
            } else {
                // Decrement the index for subsequent turns
                gameState.currentPlayerIndex = max(0, gameState.currentPlayerIndex - 1)
            }
            if let instructionLabel = uiLayer.childNode(withName: "instructionLabel") as? SKLabelNode {
                instructionLabel.text = "Player \(gameState.currentPlayerIndex + 1): Place your second settlement"
            }
        }
        // End setup phase and begin normal gameplay
        else {
            gameState.currentPhase = .play
            uiLayer.childNode(withName: "instructionLabel")?.removeFromParent()
            print("Setup phase complete. Beginning regular gameplay.")
            gameState.currentPlayerIndex = 0
            createDiceNodes()
            return
        }
        
        // Highlight valid vertices for settlement placement
        selectedBuildingType = .settlement
        highlightValidVertices()
        
        // If the new current player is a bot (except your player), auto-place a settlement.
        if gameState.players[gameState.currentPlayerIndex].isBot {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.performBotInitialSettlementPlacement()
            }
        }
    }
    
    private func performBotInitialSettlementPlacement() {
        let currentPlayer = gameState.currentPlayerIndex
        let player = gameState.players[currentPlayer]
        
        // Instantiate the decision engine.
        let decisionEngine = BotDecisionEngine()
        
        // Score available vertices using the decision engine.
        let settlementScores = decisionEngine.scoreSettlementOptions(vertices: self.vertices,
                                                                       forPlayer: player,
                                                                       gameState: gameState,
                                                                       portNodes: self.portNodes,
                                                                     blockedPorts: blockedPorts)
        
        // Choose the best vertex for settlement placement.
        guard let chosenVertex = decisionEngine.chooseBestSettlement(from: settlementScores) else {
            print("Bot \(currentPlayer + 1) found no valid settlement placement.")
            return
        }
        
        // Check if the bot has settlements remaining.
        guard player.canBuild(buildingType: .settlement) else {
            print("Bot \(currentPlayer + 1) has no more settlements")
            return
        }
        
        // Display overlays.
        showSettlementScoreOverlays(vertexScores: settlementScores) {
            print("Settlement debug overlay removed – continuing decision processing.")
            // Continue with further decision processing here...
            
            // Build the settlement (skipping resource cost during initial setup)
            let settlement = Building(type: .settlement, ownerId: currentPlayer, position: chosenVertex.position)
            chosenVertex.building = settlement
            self.gameBoard.buildings.append(settlement)
            
            // Create the settlement sprite using the bot's asset color (inside createSettlementSprite)
            self.createSettlementSprite(for: settlement)
            
            // Award a victory point for the settlement.
            player.victoryPoints += 1
            
            // Add the vertex (location) of the newly built settlement to the player's settlements array.
            player.settlements.append(chosenVertex)
            
            // Award initial resources if this is the second settlement.
            let playerSettlements = self.gameBoard.buildings.filter { $0.ownerId == currentPlayer && $0.type == .settlement }
            if playerSettlements.count == 2 {
                self.awardInitialResources(for: chosenVertex)
            }
            
            // In the initial setup, after placing the settlement, auto-place the adjacent road.
            if self.gameState.currentPhase == .setup {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.performBotInitialRoadPlacement()
                }
            }
            
            self.updatePlayerUISection()
        }
        
       
    }

    /// Uses the BotDecisionEngine to choose and build a road during the initial setup phase.
    private func performBotInitialRoadPlacement() {
        let currentPlayer = gameState.currentPlayerIndex
        let isSetupPhase = gameState.currentPhase == .setup
        
        // Get the bot's settlements from the game board.
        let botSettlements = gameBoard.buildings.filter { $0.ownerId == currentPlayer && $0.type == .settlement }
        guard let latestSettlement = botSettlements.last else {
            print("Bot \(currentPlayer + 1) has no settlement to connect a road to")
            return
        }
        
        // Find the vertex for the latest settlement.
        guard let settlementVertex = vertices.first(where: { $0.building === latestSettlement }) else {
            print("Couldn't find vertex for bot's latest settlement")
            return
        }
        
        // Filter edges adjacent to the settlement vertex that are available for road placement.
        let adjacentEdges = settlementVertex.adjacentEdges.filter { $0.canBuildRoad(for: currentPlayer, isSetupPhase: isSetupPhase) }
        
        // Use the adjacent edges if available; otherwise, fallback to all valid edges.
        let validEdges: [EdgePoint]
        if !adjacentEdges.isEmpty {
            validEdges = adjacentEdges
        } else {
            validEdges = edges.filter { $0.canBuildRoad(for: currentPlayer, isSetupPhase: isSetupPhase) }
        }
        
        // Instantiate the decision engine.
        let decisionEngine = BotDecisionEngine()
        
        // Score the available roads, now passing along self.portNodes as well.
        let roadScores = decisionEngine.scoreRoadOptions(edges: validEdges,
                                                         forPlayer: gameState.players[currentPlayer],
                                                         gameState: gameState,
                                                         portNodes: self.portNodes,
                                                         blockedPorts: blockedPorts)
        // Select the best road based on the scores.
        guard let chosenEdge = decisionEngine.chooseBestRoad(from: roadScores) else {
            print("Bot \(currentPlayer + 1) found no valid road placement near its settlement")
            return
        }
        
        showRoadScoreOverlays(edgeScores: roadScores) {
            print("Road debug overlay removed – continuing decision processing.")
            // Continue with further decision processing here...
            
            // Build the road (skipping resource cost during setup)
            let road = Building(type: .road, ownerId: currentPlayer, position: chosenEdge.position)
            chosenEdge.road = road
            self.gameBoard.buildings.append(road)
            
            // Create the road sprite using the bot's asset color.
            self.createRoadSprite(for: road)
            
            // Update the road network for longest road calculations.
            self.updateRoadLengthsForPlayer(playerId: currentPlayer)
            self.updatePlayerUISection()
            
            // After placing the road, complete the setup phase (or move to the next step).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.handleSetupPhaseNextStep()
            }
        }
        
    
    }
    
    
    // MARK: - Bot Logic (Mid-Game)

    
    private func performBotTurn() {
        let botIndex = gameState.currentPlayerIndex
        let bot = gameState.players[botIndex]

        // 1. Roll dice first.
        rollDiceForBot()

        guard gameState.currentPhase == .play else {
            // Not in play phase? Nothing more to do.
            return
        }

        // 2. Create decision engine
        let engine = BotDecisionEngine()

        // 3. Settlement Placement
        let settlementScores = engine.scoreSettlementOptions(
            vertices: self.vertices,
            forPlayer: bot,
            gameState: gameState,
            portNodes: portNodes,
            blockedPorts: blockedPorts
        )
        if let bestSettlement = engine.chooseBestSettlement(from: settlementScores) {
            guard bot.canBuild(buildingType: .settlement) else {
                print("Bot \(botIndex+1) has no settlements left")
                return
            }
            let settlement = Building(type: .settlement, ownerId: bot.id, position: bestSettlement.position)
            bestSettlement.building = settlement
            gameBoard.buildings.append(settlement)
            createSettlementSprite(for: settlement)
            bot.victoryPoints += 1
            bot.settlements.append(bestSettlement)
        }
        // 4. Road Placement (if no settlement)
        else if bot.shouldBuildRoad(gameState: gameState) {
            let roadScores = engine.scoreRoadOptions(
                edges: edges,
                forPlayer: bot,
                gameState: gameState,
                portNodes: portNodes,
                blockedPorts: blockedPorts
            )
            if let bestRoad = engine.chooseBestRoad(from: roadScores) {
                buildRoad(at: bestRoad)
            }
        }

        // 5. City Upgrade
        if bot.shouldUpgradeCity(gameState: gameState) {
            performBotCityUpgrade()
        }

        // 6. Trade Decision
        let offers = generateBotTradeOffers(for: bot)
        if let bestOffer = engine.chooseBestTradeOffer(
            offers: offers,
            forPlayer: bot,
            gameState: gameState
        ) {
            applyBotTrade(bestOffer, from: botIndex)
            print("Bot \(botIndex+1) trades offered: \(bestOffer.offered) requested: \(bestOffer.requested)")  // debug
        }

        // 7. Development Card Usage
        if let card = engine.decideDevelopmentCardUsage(forPlayer: bot, gameState: gameState) {
            playDevelopmentCard(card, forPlayer: botIndex)
        }

        // 8. End turn after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.endTurn()
        }
    }

    private func playDevelopmentCard(_ card: DevelopmentCardType, forPlayer botIndex: Int) {
        let engine = BotDecisionEngine()
        let bot = gameState.players[botIndex]

        switch card {
        case .knight:
            // 1. Spend the card and update army
            bot.developmentCards[.knight]! -= 1
            bot.knightsUsed += 1
            checkLargestArmy()

            // 2. Pick a tile and move robber
            if let target = engine.chooseRobberDestination(from: gameBoard.tiles,
                                                           forPlayer: bot,
                                                           gameState: gameState) {
                moveRobber(to: target)  // :contentReference[oaicite:0]{index=0}&#8203;:contentReference[oaicite:1]{index=1}
                print("Bot \(bot.id) played Knight → robber to \(target.position)")
            }

            updateDevelopmentCards()
            updatePlayerUISection()

        case .roadBuilding:
            // Spend the card…
            bot.developmentCards[.roadBuilding]! -= 1

            // …then place two free roads
            for _ in 0..<2 {
                let scores = engine.scoreRoadOptions(edges: edges,
                                                     forPlayer: bot,
                                                     gameState: gameState,
                                                     portNodes: portNodes,
                                                     blockedPorts: blockedPorts)
                if let bestEdge = engine.chooseBestRoad(from: scores) {
                    buildRoad(at: bestEdge)  // :contentReference[oaicite:2]{index=2}&#8203;:contentReference[oaicite:3]{index=3}
                    print("Bot \(bot.id) placed free road at \(bestEdge.position)")
                }
            }

            updateDevelopmentCards()
            updatePlayerUISection()

        case .monopoly:
            // Spend card
            bot.developmentCards[.monopoly]! -= 1

            // Choose the resource you have the most of
            let choice = bot.resources
                .filter { $0.key != .desert }
                .max { $0.value < $1.value }?.key

            if let resource = choice {
                var stolen = 0
                for (idx, other) in gameState.players.enumerated() where idx != botIndex {
                    let amount = other.resources[resource] ?? 0
                    stolen += amount
                    other.resources[resource] = 0
                }
                bot.resources[resource] = (bot.resources[resource] ?? 0) + stolen
                print("Bot \(bot.id) played Monopoly → stole \(stolen) \(resource) cards")
            }

            updateResourceCards()
            updateDevelopmentCards()
            updatePlayerUISection()

        case .yearOfPlenty:
            bot.developmentCards[.yearOfPlenty]! -= 1

            // Pick two resources you’re short on
            let picks = ResourceType.allCases
                .filter { $0 != .desert }
                .sorted { (bot.resources[$0] ?? 0) < (bot.resources[$1] ?? 0) }
                .prefix(2)

            for res in picks {
                if bank.takeResources(resource: res, amount: 1) {
                    bot.resources[res] = (bot.resources[res] ?? 0) + 1
                }
            }
            print("Bot \(bot.id) played Year of Plenty → gained \(picks)")

            updateResourceCards()
            updateDevelopmentCards()
            updatePlayerUISection()

        case .victoryPoint:
            bot.developmentCards[.victoryPoint]! -= 1
            bot.victoryPoints += 1
            print("Bot \(bot.id) played Victory Point → now \(bot.victoryPoints) VP")

            updateDevelopmentCards()
            updatePlayerUISection()
        }
    }

    
    // Helper to build a small list of reasonable bank‐trade offers:
    private func generateBotTradeOffers(for bot: Player) -> [BotDecisionEngine.TradeOffer] {
        var offers = [BotDecisionEngine.TradeOffer]()
        let specificPorts: [ResourceType: String] = [
            .wood:  "port_lumber.svg",
            .brick: "port_brick.svg",
            .sheep: "port_wool.svg",
            .wheat: "port_grain.svg",
            .ore:   "port_ore.svg"
        ]

        for res in ResourceType.allCases where res != .desert {
            let have = bot.resources[res] ?? 0

            // 2:1 specific port
            if let portName = specificPorts[res],
               bot.portsUnlocked.contains(portName),
               have >= 2,
               // pick a different resource they’re low on
               let want = ResourceType.allCases.first(
                 where: { $0 != .desert && $0 != res && (bot.resources[$0] ?? 0) < 2 }
               )
            {
                offers.append(.init(offered: [res: 2], requested: [want: 1]))
            }
            // 3:1 generic port
            else if bot.portsUnlocked.contains("port.svg"),
                    have >= 3,
                    let want = ResourceType.allCases.first(
                      where: { $0 != .desert && $0 != res && (bot.resources[$0] ?? 0) < 2 }
                    )
            {
                offers.append(.init(offered: [res: 3], requested: [want: 1]))
            }
            // 4:1 bank trade
            else if have >= 4,
                    let want = ResourceType.allCases.first(
                      where: { $0 != .desert && $0 != res && (bot.resources[$0] ?? 0) < 2 }
                    )
            {
                offers.append(.init(offered: [res: 4], requested: [want: 1]))
            }
        }
        return offers
    }


    // Helper to actually swap cards with the bank
    private func applyBotTrade(_ offer: BotDecisionEngine.TradeOffer, from botIndex: Int) {
        let bot = gameState.players[botIndex]
        // Remove offered
        for (res, amt) in offer.offered {
            bot.resources[res, default:0] -= amt
            bank.takeResources(resource: res, amount: amt)
        }
        // Add requested
        for (res, amt) in offer.requested {
            if bank.takeResources(resource: res, amount: 0) { /* ensure exists */ }
            bot.resources[res, default:0] += amt
            // (You could also decrement bank.resourceCards here if desired)
        }
        updatePlayerUISection()  // Refresh resource counts on screen
    }
    
    private func performBotTurnAfterRobber() {
        let bot = gameState.players[gameState.currentPlayerIndex]

        botMoveRobber()
        
        // 3. Mid-game strategy
        if bot.shouldUpgradeCity(gameState: gameState) {
            performBotCityUpgrade()
        }
        
        if bot.shouldBuildSettlement() {
             ()
        }
        if bot.shouldBuildRoad(gameState: gameState) {
            performStrategicRoadPlacement()
        }
        
        // 4. Always end turn after actions
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.endTurn()
        }
    }
    
    private func performStrategicRoadPlacement() {
        let currentPlayer = gameState.currentPlayerIndex
        var bestLength = 0
        var bestEdge: EdgePoint?
        
        // Find road that extends longest potential path
        for edge in edges {
            guard edge.canBuildRoad(for: currentPlayer, isSetupPhase: false) else { continue }
            
            // Pass currentPlayer as playerId parameter
            let potentialLength = calculatePotentialRoadLength(from: edge, playerId: currentPlayer)
            if potentialLength > bestLength {
                bestLength = potentialLength
                bestEdge = edge
            }
        }
        
        guard let targetEdge = bestEdge else { return }
        
        // Build the road
        let road = Building(type: .road, ownerId: currentPlayer, position: targetEdge.position)
        targetEdge.road = road
        gameBoard.buildings.append(road)
        createRoadSprite(for: road)
        payForBuilding(type: .road)
        
        updateRoadLengthsForPlayer(playerId: currentPlayer)
        gameState.updateLongestRoad()
        checkLongestRoad()
        
        updatePlayerUISection()
    }
    
    private func performMidGameSettlement() {
        let currentPlayerIndex = gameState.currentPlayerIndex
        let bot = gameState.players[currentPlayerIndex]
        
        // 1. Check if bot can afford a settlement
        guard canAffordBuilding(type: .settlement) else {
            print("Bot \(currentPlayerIndex + 1) can't afford settlement")
            return
        }
        
        //Check if bot has anymore settlemnts
        guard bot.canBuild(buildingType: .settlement) else {
            print("Bot \(currentPlayerIndex + 1) has no more settlements")
            return
        }
        
        // 2. Find all buildable vertices with road access
        let validVertices = vertices.filter {
            $0.canBuildSettlement(for: currentPlayerIndex, checkConnectedRoad: true)
        }
        
        // 3. Score potential locations
        var bestScore = -1.0
        var bestVertex: VertexPoint?
        var bestConnectedRoad: EdgePoint?
        
        for vertex in validVertices {
            let score = calculateMidGameSettlementScore(for: vertex, player: currentPlayerIndex)
            
            if score > bestScore {
                bestScore = score
                bestVertex = vertex
                
                // Find best connected road for potential expansion
                // Update this section in performMidGameSettlement
                bestConnectedRoad = vertex.adjacentEdges.filter {
                    $0.road == nil && canBuildRoadFrom(vertex: vertex, edge: $0)
                }.max(by: {
                    calculatePotentialRoadLength(from: $0, playerId: currentPlayerIndex) <
                        calculatePotentialRoadLength(from: $1, playerId: currentPlayerIndex)
                })
            }
        }
        
        guard let targetVertex = bestVertex else {
            print("Bot \(currentPlayerIndex + 1) found no valid settlement locations")
            return
        }
        
        // 4. Build the settlement
        let settlement = Building(type: .settlement, ownerId: currentPlayerIndex, position: targetVertex.position)
        targetVertex.building = settlement
        gameBoard.buildings.append(settlement)
        createSettlementSprite(for: settlement)
        payForBuilding(type: .settlement)
        bot.victoryPoints += 1
        
        // 5. Build connecting road if possible
        if let roadEdge = bestConnectedRoad,
           canAffordBuilding(type: .road) {
            let road = Building(type: .road, ownerId: currentPlayerIndex, position: roadEdge.position)
            roadEdge.road = road
            gameBoard.buildings.append(road)
            createRoadSprite(for: road)
            payForBuilding(type: .road)
        }
        updatePlayerUISection()
        print("Bot \(currentPlayerIndex + 1) built strategic settlement at \(targetVertex.position)")
    }
    
    private func calculateMidGameSettlementScore(for vertex: VertexPoint, player: Int) -> Double {
        var score = 0.0
        var resourceTypes = Set<ResourceType>()
        var opponentProximity = 0
        
        // Resource and probability scoring
        for tile in vertex.adjacentHexes {
            guard tile.resourceType != .desert else { continue }
            
            // Base resource value
            let resourceValue: Double
            switch tile.resourceType {
            case .wheat, .ore: resourceValue = 1.2 // Higher value for city resources
            case .brick, .wood: resourceValue = 1.1 // Important for expansion
            default: resourceValue = 1.0
            }
            
            score += resourceValue * tile.tokenProbability * 100
            resourceTypes.insert(tile.resourceType)
        }
        
        // Resource diversity bonus
        score += Double(resourceTypes.count) * 15
        
        // Expansion potential
        let expansionScore = vertex.adjacentEdges.filter {
            $0.road == nil && canBuildRoadFrom(vertex: vertex, edge: $0)
        }.count * 10
        score += Double(expansionScore)
        
        // Opponent proximity analysis
        for edge in vertex.adjacentEdges {
            for connectedVertex in edge.vertices {
                if let building = connectedVertex.building, building.ownerId != player {
                    opponentProximity += 1
                }
            }
        }
        
        // Prefer some opponent proximity but not too much
        let proximityModifier: Double
        switch opponentProximity {
        case 0: proximityModifier = 0.8 // Prefer some competition
        case 1: proximityModifier = 1.0 // Ideal balance
        case 2: proximityModifier = 0.6
        default: proximityModifier = 0.4
        }
        score *= proximityModifier
        
        // Longest road potential
        if let longestRoadPath = calculatePotentialLongestRoad(from: vertex) {
            score += Double(longestRoadPath) * 5
        }
        
        return score
    }
    
    private func performBotCityUpgrade() {
        let currentPlayer = gameState.currentPlayerIndex
        let bot = gameState.players[currentPlayer]
        
        // Get all potential upgradable settlements
        let upgradableSettlements = vertices.compactMap { vertex -> (vertex: VertexPoint, score: Double)? in
            guard let building = vertex.building,
                  building.type == .settlement,
                  building.ownerId == currentPlayer,
                  canAffordBuilding(type: .city) else { return nil }
            
            // Calculate upgrade score based on adjacent resources
            let score = calculateCityUpgradeScore(for: vertex)
            return (vertex, score)
        }
        
        // Sort by highest score first
        let sortedOptions = upgradableSettlements.sorted { $0.score > $1.score }
        
        guard let bestOption = sortedOptions.first else { return }
        
        // Perform the upgrade
        let settlement = bestOption.vertex.building!
        if let node = childNode(withName: "building_settlement_\(settlement.position.x)_\(settlement.position.y)") {
            node.removeFromParent()
        }
        
        settlement.type = .city
        createCitySprite(for: settlement)
        payForBuilding(type: .city)
        
        // Update victory points
        bot.victoryPoints += 1
        updatePlayerUISection()
        
        print("Bot \(currentPlayer + 1) upgraded settlement to city at \(settlement.position)")
    }
    
    private func calculateCityUpgradeScore(for vertex: VertexPoint) -> Double {
        var score = 0.0
        var resourceCounts = [ResourceType: Int]()
        
        // Analyze adjacent tiles
        for tile in vertex.adjacentHexes {
            guard tile.resourceType != .desert else { continue }
            
            // Add resource value
            let resourceValue: Double
            switch tile.resourceType {
            case .wheat, .ore: resourceValue = 1.5 // Higher value for city resources
            default: resourceValue = 1.0
            }
            
            score += resourceValue * tile.tokenProbability * 100
            
            // Track resource diversity
            resourceCounts[tile.resourceType, default: 0] += 1
        }
        
        // Bonus for wheat/ore tiles (critical for cities)
        let wheatOreBonus = Double(resourceCounts[.wheat, default: 0] + resourceCounts[.ore, default: 0]) * 10
        score += wheatOreBonus
        
        // Penalize for desert adjacency
        let desertCount = vertex.adjacentHexes.filter { $0.resourceType == .desert }.count
        score -= Double(desertCount) * 20
        
        return score
    }
    
    
    // MARK: - Turn Flow & Ending Turns
    
    
    private func endTurn() {
        unhighlightAllPoints()
        gameState.nextPlayer()
        
        // Reset any turn-specific state
        selectedBuildingType = nil
        
        // Remove highlighting from all vertices and edges
        unhighlightAllPoints()
        
        // Reset dice based on whose turn it is.
        if gameState.currentPlayerIndex == 0 {
            // It's now your turn – allow rolling.
            resetDiceForPlayerTurn()
        }
        
        updateEndTurnButtonIcon()
        updatePlayerUISection()
        
        print("Turn ended. Player \(gameState.currentPlayerIndex + 1)'s turn")
        
        // If the next player is a bot, automatically perform their turn
        if gameState.players[gameState.currentPlayerIndex].isBot {
            performBotTurn()
        }
    }
    
    private func updateEndTurnButtonIcon() {
        guard let endTurnButton = uiLayer.childNode(withName: "End_Turn_Button") as? SKSpriteNode,
              let iconNode = endTurnButton.children.first as? SKSpriteNode
        else { return }

        // Determine if the end turn button is clickable.
        // Conditions: not in setup phase, it is the human's turn, and (if in play phase) the dice have been rolled.
        let clickable = (gameState.currentPlayerIndex == 0 &&
                         gameState.currentPhase != .setup &&
                         (gameState.currentPhase != .play || gameState.hasRolledDice) && !isRobberMoveMode)
        if clickable {
            // Change to the "pass turn" icon and remove transparency.
            iconNode.texture = SKTexture(imageNamed: "icon_pass_turn.svg")
            iconNode.alpha = 1.0
            iconNode.zPosition = 102
        } else {
            // Otherwise, show the default hourglass icon with inactive opacity.
            iconNode.texture = SKTexture(imageNamed: "icon_hourglass")
            iconNode.alpha = 0.5
            iconNode.zPosition = 102
        }
    }
    
    
    // MARK: - Building & Placement
    
    
    private func highlightValidEdges() {
        // Only show valid road placements if it's the human's turn.
        if gameState.currentPlayerIndex != 0 {
            return
        }
        
        // Remove any previous highlight nodes.
        unhighlightAllPoints()
        
        let currentPlayer = gameState.currentPlayerIndex
        let isSetupPhase = gameState.currentPhase == .setup
        
        for edge in edges {
            if edge.canBuildRoad(for: currentPlayer, isSetupPhase: isSetupPhase) {
                // Create a circular highlight node.
                let highlightNode = SKShapeNode(circleOfRadius: 10)
                // Fill with a very transparent yellow.
                highlightNode.fillColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.2)
                // Outline the node in black.
                highlightNode.strokeColor = .black
                highlightNode.lineWidth = 0.5
                
                highlightNode.position = edge.position
                highlightNode.name = "highlightNode"
                // Set zPosition so that it appears above the board.
                highlightNode.zPosition = 5
                addChild(highlightNode)
                
                // Create a pulsating action.
                let scaleUp = SKAction.scale(to: 1.2, duration: 1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 1)
                let pulseSequence = SKAction.sequence([scaleUp, scaleDown])
                let pulseForever = SKAction.repeatForever(pulseSequence)
                highlightNode.run(pulseForever)
            }
        }
    }
    
    
    private func highlightValidVertices() {
        // Only show valid settlement placements if it's the human's turn.
        if gameState.currentPlayerIndex != 0 {
            return
        }
        
        // Remove any previous highlight nodes.
        unhighlightAllPoints()
        
        let currentPlayer = gameState.currentPlayerIndex
        let checkConnectedRoad = gameState.currentPhase != .setup
        
        for vertex in vertices {
            if vertex.canBuildSettlement(for: currentPlayer, checkConnectedRoad: checkConnectedRoad) {
                // Create a circular highlight node.
                let highlightNode = SKShapeNode(circleOfRadius: 10)
                // Fill with a very transparent yellow.
                highlightNode.fillColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.2)
                // Outline the node in black.
                highlightNode.strokeColor = .black
                highlightNode.lineWidth = 0.5
                
                highlightNode.position = vertex.position
                highlightNode.name = "highlightNode"
                // Set zPosition so that it appears above the board.
                highlightNode.zPosition = 5
                addChild(highlightNode)
                
                // Create a pulsating action.
                let scaleUp = SKAction.scale(to: 1.2, duration: 1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 1)
                let pulseSequence = SKAction.sequence([scaleUp, scaleDown])
                let pulseForever = SKAction.repeatForever(pulseSequence)
                highlightNode.run(pulseForever)
            }
        }
    }
    
    private func highlightValidCityUpgrades() {
        // Only allow city upgrade highlights if it's the human's turn.
        if gameState.currentPlayerIndex != 0 {
            return
        }
        
        // Clear any previous highlight nodes.
        unhighlightAllPoints()
        
        let currentPlayer = gameState.currentPlayerIndex
        
        // Iterate over vertices that have a settlement belonging to the current player.
        for vertex in vertices {
            if let building = vertex.building,
               building.type == .settlement,
               building.ownerId == currentPlayer {
                
                // Create a circular highlight node with the same styling as the others.
                let highlightNode = SKShapeNode(circleOfRadius: 10)
                highlightNode.fillColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.2)  // Transparent yellow
                highlightNode.strokeColor = .black
                highlightNode.lineWidth = 0.5
                
                highlightNode.position = vertex.position
                highlightNode.name = "highlightNode"
                // Ensure it appears above the board.
                highlightNode.zPosition = 5
                addChild(highlightNode)
                
                // Create a pulsating action.
                let scaleUp = SKAction.scale(to: 1.2, duration: 1)
                let scaleDown = SKAction.scale(to: 1.0, duration: 1)
                let pulseSequence = SKAction.sequence([scaleUp, scaleDown])
                let pulseForever = SKAction.repeatForever(pulseSequence)
                highlightNode.run(pulseForever)
            }
        }
    }
    
    private func unhighlightAllPoints() {
        // Remove any highlight nodes
        self.children.filter { $0.name == "highlightNode" }.forEach { $0.removeFromParent() }
    }
    
    private func findClosestEdgePoint(to position: CGPoint, maxDistance: CGFloat) -> EdgePoint? {
        var closestEdge: EdgePoint? = nil
        var minDistance: CGFloat = maxDistance
        
        for edge in edges {
            let distance = hypot(position.x - edge.position.x, position.y - edge.position.y)
            if distance < minDistance {
                minDistance = distance
                closestEdge = edge
            }
        }
        
        return closestEdge
    }
    
    private func findClosestVertexPoint(to position: CGPoint, maxDistance: CGFloat) -> VertexPoint? {
        var closestVertex: VertexPoint? = nil
        var minDistance: CGFloat = maxDistance
        
        for vertex in vertices {
            let distance = hypot(position.x - vertex.position.x, position.y - vertex.position.y)
            if distance < minDistance {
                minDistance = distance
                closestVertex = vertex
            }
        }
        
        return closestVertex
    }
    
    private func handleRoadPlacement(at location: CGPoint) {
        // Find the closest edge point
        if let closestEdge = findClosestEdgePoint(to: location, maxDistance: 20) {
            let currentPlayerIndex = gameState.currentPlayerIndex
            let currentPlayer = gameState.players[currentPlayerIndex]
            
            // Check if the player can build here
            if closestEdge.canBuildRoad(for: currentPlayerIndex, isSetupPhase: gameState.currentPhase == .setup) {
                // Check if player has resources
                if canAffordBuilding(type: .road) {
                    // Deduct resources
                    payForBuilding(type: .road)
                    
                    // Create the road
                    let road = Building(type: .road, ownerId: currentPlayerIndex, position: closestEdge.position)
                    closestEdge.road = road
                    gameBoard.buildings.append(road)
                    
                    // Create visual representation
                    createRoadSprite(for: road)
                    
                    currentPlayer.roadsLeft -= 1
                    
                    // Reset building mode and highlighting
                    selectedBuildingType = nil
                    unhighlightAllPoints()
                    
                    updateRoadLengthsForPlayer(playerId: currentPlayerIndex)
                    gameState.updateLongestRoad()
                    checkLongestRoad()
                    checkWinCondition()
                    
                    // Update UI
                    updateResourceCards()
                    updateBuildingButtonIcons()
                    updatePlayerUISection()
                    
                    // Handle setup phase logic if needed
                    if gameState.currentPhase == .setup {
                        handleSetupPhaseNextStep()
                    }
                } else {
                    print("Not enough resources to build a road")
                }
            }
        }
    }
    
    private func handleSettlementPlacement(at location: CGPoint) {
        // Find the closest vertex point
        if let closestVertex = findClosestVertexPoint(to: location, maxDistance: 20) {
            let currentPlayer = gameState.currentPlayerIndex
            let player = gameState.players[currentPlayer]
            let checkConnectedRoad = gameState.currentPhase != .setup
            
            // Check if the player can build here
            if (closestVertex.canBuildSettlement(for: currentPlayer, checkConnectedRoad: checkConnectedRoad) && player.canBuild(buildingType: .settlement)) {
                // Check if player has resources
                if canAffordBuilding(type: .settlement) {
                    // Deduct resources
                    payForBuilding(type: .settlement)
                    
                    // Create the settlement
                    let settlement = Building(type: .settlement, ownerId: currentPlayer, position: closestVertex.position)
                    closestVertex.building = settlement
                    gameBoard.buildings.append(settlement)
                    
                    // Create visual representation
                    createSettlementSprite(for: settlement)
                    
                    // Deduct the settlement count and award victory point
                    player.settlementsLeft -= 1
                    player.victoryPoints += 1
                    
                    // NEW: Add the settlement's vertex to the player's settlements array.
                    player.settlements.append(closestVertex)
                    
                    // Reset building mode and highlighting
                    selectedBuildingType = nil
                    unhighlightAllPoints()
                    
                    // Check if this is the player's second settlement.
                    let playerSettlements = gameBoard.buildings.filter { $0.ownerId == currentPlayer && $0.type == .settlement }
                    if playerSettlements.count == 2 {
                        awardInitialResources(for: closestVertex)
                    }
                    
                    if gameState.currentPhase == .setup {
                        selectedBuildingType = .road
                        highlightValidEdges()
                    }
                    checkWinCondition()
                    
                    // Unlock any adjacent port trades for the current player.
                    unlockPorts(for: closestVertex, by: player)
                } else {
                    print("Not enough resources to build a settlement")
                }
            }
        }
        // Update UI
        updateResourceCards()
        updateBuildingButtonIcons()
        updatePlayerUISection()
    }

    
    private func handleCityPlacement(at location: CGPoint) {
        // Find the closest vertex point
        if let closestVertex = findClosestVertexPoint(to: location, maxDistance: 20) {
            let currentPlayer = gameState.currentPlayerIndex
            
            // Check if there's a settlement here that belongs to the player
            if let building = closestVertex.building,
               building.type == .settlement &&
                building.ownerId == currentPlayer {
                
                // Check if player has resources
                if canAffordBuilding(type: .city) {
                    // Deduct resources
                    payForBuilding(type: .city)
                    
                    // Remove the old settlement sprite
                    if let node = childNode(withName: "building_settlement_\(building.position.x)_\(building.position.y)") {
                        node.removeFromParent()
                    }
                    
                    // Update the building type
                    building.type = .city
                    
                    // Create visual representation
                    createCitySprite(for: building)
                    
                    gameState.players[currentPlayer].citiesLeft -= 1
                    
                    gameState.players[currentPlayer].settlementsLeft += 1
                    
                    // Award additional victory point (settlements = 1, cities = 2)
                    gameState.players[currentPlayer].victoryPoints += 1
                    
                    // Reset building mode and highlighting
                    selectedBuildingType = nil
                    unhighlightAllPoints()
                    
                    // Update UI
                    updateResourceCards()
                    updateBuildingButtonIcons()
                    updatePlayerUISection()
                    
                    // Check for win condition
                    checkWinCondition()
                    
                    // Unlock any adjacent port trades for the current player.
                    unlockPorts(for: closestVertex, by: gameState.players[currentPlayer])
                } else {
                    print("Not enough resources to build a city")
                }
            }
        }
    }
    
    
    // MARK: - Bot Building Functions

    
    /// Builds a settlement at the given VertexPoint using the current bot player's settings.
    func buildSettlement(at vertex: VertexPoint) {
        // Get the current bot player.
        let botPlayer = gameState.players[gameState.currentPlayerIndex]
        
        // Create a new settlement building.
        let settlement = Building(type: .settlement, ownerId: botPlayer.id, position: vertex.position)
        
        // Set the building at the vertex.
        vertex.building = settlement
        
        // Add the settlement to the game board.
        gameBoard.buildings.append(settlement)
        
        // Create the settlement's sprite (this function should use botPlayer.assetColor to choose the appropriate asset).
        createSettlementSprite(for: settlement)
        
        // Deduct resources from the bot (using your existing resource payment logic).
        payForBuilding(type: .settlement)
        
        // Increase the bot's victory points and update the UI.
        botPlayer.victoryPoints += 1
        updatePlayerUISection()
        
        // (Optional) Award initial resources if in the setup phase.
        // awardInitialResources(for: vertex)
    }

    /// Builds a road along the given EdgePoint for the current bot player.
    func buildRoad(at edge: EdgePoint) {
        // Get the current bot player.
        let botPlayer = gameState.players[gameState.currentPlayerIndex]
        
        // Create a new road building.
        let road = Building(type: .road, ownerId: botPlayer.id, position: edge.position)
        
        // Assign the road to the chosen edge.
        edge.road = road
        
        // Add the road building to the game board.
        gameBoard.buildings.append(road)
        
        // Create the road sprite (this should use the bot's asset color as needed).
        createRoadSprite(for: road)
        
        // Deduct the road building cost.
        payForBuilding(type: .road)
        
        // Update the bot's road lengths and check for longest road awards.
        updateRoadLengthsForPlayer(playerId: botPlayer.id)
        gameState.updateLongestRoad()
        checkLongestRoad()
        
        // Update the UI so the player sees the new road.
        updatePlayerUISection()
    }
    
    
    // MARK: - Road / Building Helpers
    
    
    private func canAffordBuilding(type: BuildingType) -> Bool {
        let player = gameState.players[gameState.currentPlayerIndex]
        
        // Skip resource check during setup phase
        if gameState.currentPhase == .setup {
            return true
        }
        
        if !(player.canBuild(buildingType: type)) {
            return false
        }
        
        switch type {
        case .road:
            return (player.resources[.wood] ?? 0) >= 1 && (player.resources[.brick] ?? 0) >= 1
        case .settlement:
            return (player.resources[.wood] ?? 0) >= 1 && (player.resources[.brick] ?? 0) >= 1 &&
            (player.resources[.sheep] ?? 0) >= 1 && (player.resources[.wheat] ?? 0) >= 1
        case .city:
            return (player.resources[.wheat] ?? 0) >= 2 && (player.resources[.ore] ?? 0) >= 3
        }
    }
    
    private func canPlayerAffordBuilding(type: BuildingType) -> Bool {
        let player = gameState.players[0]
        
        // Skip resource check during setup phase
        if gameState.currentPhase == .setup {
            return true
        }
        
        if !(player.canBuild(buildingType: type)) {
            return false
        }
        
        switch type {
        case .road:
            return (player.resources[.wood] ?? 0) >= 1 && (player.resources[.brick] ?? 0) >= 1
        case .settlement:
            return (player.resources[.wood] ?? 0) >= 1 && (player.resources[.brick] ?? 0) >= 1 &&
            (player.resources[.sheep] ?? 0) >= 1 && (player.resources[.wheat] ?? 0) >= 1
        case .city:
            return (player.resources[.wheat] ?? 0) >= 2 && (player.resources[.ore] ?? 0) >= 3
        }
    }
    
    private func payForBuilding(type: BuildingType) {
        // Skip resource payment during setup phase
        if gameState.currentPhase == .setup {
            return
        }
        
        let player = gameState.players[gameState.currentPlayerIndex]
        
        switch type {
        case .road:
            player.resources[.wood]! -= 1
            player.resources[.brick]! -= 1
        case .settlement:
            player.resources[.wood]! -= 1
            player.resources[.brick]! -= 1
            player.resources[.sheep]! -= 1
            player.resources[.wheat]! -= 1
        case .city:
            player.resources[.wheat]! -= 2
            player.resources[.ore]! -= 3
        }
        updateResourceCards()
        updateBuildingButtonIcons()
        updatePlayerUISection()
    }
    
    private func canPlayerAffordDevCard() -> Bool {
        let player = gameState.players[0]
        
        return (player.resources[.wheat] ?? 0) >= 1 && (player.resources[.sheep] ?? 0) >= 1 && (player.resources[.ore] ?? 0) >= 1
    }
    
    private func updateRoadLengthsForPlayer(playerId: Int) {
        var maxLength = 0
        let playerRoads = edges.filter { $0.road?.ownerId == playerId }
        
        for road in playerRoads {
            let length = calculatePotentialRoadLength(from: road, playerId: playerId)
            maxLength = max(maxLength, length)
        }
        
        gameState.players[playerId].longestRoadLength = maxLength
        updatePlayerUISection()
    }
    
    private func canBuildRoadFrom(vertex: VertexPoint, edge: EdgePoint) -> Bool {
        // Check if road can be built from this vertex along this edge
        return edge.vertices.contains { $0 === vertex } &&
        edge.canBuildRoad(for: vertex.building?.ownerId ?? -1, isSetupPhase: false)
    }
    
    private func calculatePotentialLongestRoad(from vertex: VertexPoint) -> Int? {
        guard let player = vertex.building?.ownerId else { return nil }
        
        var maxLength = 0
        for edge in vertex.adjacentEdges {
            let length = calculatePotentialRoadLength(from: edge, playerId: player)
            maxLength = max(maxLength, length)
        }
        return maxLength
    }
    
    private func calculatePotentialRoadLength(from edge: EdgePoint, playerId: Int) -> Int {
        var visitedEdges = Set<EdgePoint>()
        var queue = [(edge, 1)]
        var maxLength = 1
        
        while !queue.isEmpty {
            let (currentEdge, length) = queue.removeFirst()
            guard !visitedEdges.contains(currentEdge) else { continue }
            
            visitedEdges.insert(currentEdge)
            maxLength = max(maxLength, length)
            
            // Check connected edges for this player
            for vertex in currentEdge.vertices {
                for connectedEdge in vertex.adjacentEdges {
                    if connectedEdge.road?.ownerId == playerId {
                        queue.append((connectedEdge, length + 1))
                    }
                }
            }
        }
        
        return maxLength
    }
    
    
    // MARK: - Sprite Creation (Buildings)

    
    private func createRoadSprite(for road: Building) {
        // Determine asset suffix based on the player's color.
        let owner = gameState.players[road.ownerId]
        let colorName = owner.assetColor.lowercased()
        let assetName = "road_\(colorName)"
        
        let roadTexture = SKTexture(imageNamed: assetName)
        
        // Create a sprite node for the road.
        let roadNode = SKSpriteNode(texture: roadTexture)
        
        // Adjust the size (tweak these values to suit your design)
        roadNode.size = CGSize(width: 10, height: 50)
        
        // Position the road at the midpoint of the edge.
        roadNode.position = road.position
        
        // Set the zPosition: roads appear above the board (z = 0) but below settlements (z = 2).
        roadNode.zPosition = 2
        
        // Calculate the angle of the edge based on its two vertices.
        if let edgePoint = edges.first(where: { $0.position == road.position }),
           edgePoint.vertices.count >= 2 {
            let vertex1 = edgePoint.vertices[0].position
            let vertex2 = edgePoint.vertices[1].position
            let dx = vertex2.x - vertex1.x
            let dy = vertex2.y - vertex1.y
            let angle = atan2(dy, dx)
            
            // Set a tweakable rotation offset.
            // If your SVG asset is drawn with its long axis horizontal, then an offset of 0 may work.
            // Otherwise, try adjusting by adding/subtracting π/2 until it matches the preview.
            let roadRotationOffset: CGFloat = Double.pi / 2  // Try values like 0, π/2, or -π/2 if needed.
            roadNode.zRotation = angle + roadRotationOffset
        }
        
        roadNode.name = "building_road_\(road.position.x)_\(road.position.y)"
        addChild(roadNode)
    }
    
    private func createSettlementSprite(for settlement: Building) {
        // Determine asset suffix based on player id
        let owner = gameState.players[settlement.ownerId]
        let colorName = owner.assetColor.lowercased()  // e.g., "red"
        let assetName = "settlement_\(colorName)"       // This should match your SVG file name.
        
        let settlementTexture = SKTexture(imageNamed: assetName)
        
        // Create a sprite node with the texture.
        let settlementNode = SKSpriteNode(texture: settlementTexture)
        
        // Set a desired size (adjust as needed)
        settlementNode.size = CGSize(width: 40, height: 40)
        
        settlementNode.position = settlement.position
        settlementNode.name = "building_settlement_\(settlement.position.x)_\(settlement.position.y)"
        
        // Set zPosition so it appears above roads (roads are at z = 1, settlements at z = 2)
        settlementNode.zPosition = 3
        
        addChild(settlementNode)
    }
    
    private func createCitySprite(for city: Building) {
        // Determine asset suffix based on player id.
        let owner = gameState.players[city.ownerId]
        let colorName = owner.assetColor.lowercased()
        let assetName = "city_\(colorName)"
        
        let cityTexture = SKTexture(imageNamed: assetName)
        
        // Create a sprite node with the texture.
        let cityNode = SKSpriteNode(texture: cityTexture)
        
        // Set a desired size (adjust these values as needed)
        cityNode.size = CGSize(width: 40, height: 40)
        
        cityNode.position = city.position
        cityNode.name = "building_city_\(city.position.x)_\(city.position.y)"
        
        // Set zPosition so it appears above roads (roads at z = 1) and on the same level as settlements (z = 2)
        cityNode.zPosition = 3
        
        addChild(cityNode)
    }
    
    
    // MARK: - Robber Mechanics

    
    private func highlightValidRobberTiles() {
        let robberHighlightScale: CGFloat = 1.0    // Adjust to make the highlight larger or smaller.
        let robberHighlightXOffset: CGFloat = 0.0    // Horizontal offset for the highlight nodes.
        let robberHighlightYOffset: CGFloat = 17.0   // Vertical offset for the highlight nodes.
        
        // Only show valid robber placements if it's the human's turn.
        if gameState.currentPlayerIndex != 0 {
            return
        }
        
        // Remove any previous robber highlight nodes.
        self.children.filter { $0.name == "robberHighlight" }.forEach { $0.removeFromParent() }
        
        // Iterate through the tilePoints (each holds a tile and its center position).
        for tilePoint in tilePoints {
            let tile = tilePoint.tile
            
            // Only consider tiles that do NOT have the robber AND are NOT adjacent to any settlement.
            if !tile.hasRobber && !isTileAdjacentToSettlement(tile) {
                // Create a highlight node. We start with a base radius (e.g. 15 points) and apply the scale factor.
                let baseRadius: CGFloat = 15.0
                let highlightNode = SKShapeNode(circleOfRadius: baseRadius * robberHighlightScale)
                
                // Set styling: a very transparent yellow fill and a thin black outline.
                highlightNode.fillColor = UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 0.2)
                highlightNode.strokeColor = .black
                highlightNode.lineWidth = 0.5
                
                // Position the node at the tile's center, with added offsets.
                highlightNode.position = CGPoint(
                    x: tilePoint.position.x + robberHighlightXOffset,
                    y: tilePoint.position.y + robberHighlightYOffset
                )
                highlightNode.name = "robberHighlight"
                // Set zPosition so that it appears above the board.
                highlightNode.zPosition = 1.0
                
                // Create a pulsating action to draw attention.
                let scaleUp = SKAction.scale(to: 1.25, duration: 1.0)
                let scaleDown = SKAction.scale(to: 1.0, duration: 1.0)
                let pulseSequence = SKAction.sequence([scaleUp, scaleDown])
                let pulseForever = SKAction.repeatForever(pulseSequence)
                highlightNode.run(pulseForever)
                
                addChild(highlightNode)
            }
        }
    }
    
    private func moveRobber(to tile: Tile) {
        // Clear the robber from all tiles.
        for t in gameBoard.tiles {
            t.hasRobber = false
        }
        // Mark the selected tile as having the robber.
        tile.hasRobber = true
        
        // Remove all robber highlight nodes.
        self.children.filter { $0.name == "robberHighlight" }.forEach { $0.removeFromParent() }
        
        // Calculate the target position using the same offsets.
        let robberOffset = CGPoint(x: -25, y: 10)
        let targetPosition = CGPoint(x: tile.position.x + robberOffset.x, y: tile.position.y + robberOffset.y)
        
        // Animate the existing robber sprite to the new tile's position.
        if let robber = robberNode {
            let moveAction = SKAction.move(to: targetPosition, duration: 0.5)
            moveAction.timingMode = .easeInEaseOut
            robber.run(moveAction)
        }
        
        // Exit robber move mode.
        isRobberMoveMode = false
        updateEndTurnButtonIcon()
        print("Robber moved to tile at position \(tile.position)")
        
        // After the robber is placed, steal a resource from an adjacent opponent (if any).
        let delay = SKAction.wait(forDuration: 0.6)
        let stealAction = SKAction.run {
            self.stealResource(from: tile)
        }
        run(SKAction.sequence([delay, stealAction]))
    }
    
    private func stealResource(from tile: Tile) {
        let currentPlayerIndex = gameState.currentPlayerIndex
        // Get all adjacent buildings on the tile.
        let adjacentBuildings = getAdjacentBuildings(to: tile)
        
        // Gather distinct opponent IDs (exclude the current player).
        var opponentIds: Set<Int> = []
        for building in adjacentBuildings {
            if building.ownerId != currentPlayerIndex {
                opponentIds.insert(building.ownerId)
            }
        }
        
        if opponentIds.isEmpty {
            print("No opponents to steal from on this tile.")
            return
        }
        
        let opponents = Array(opponentIds)
        let randomOpponentIndex = Int.random(in: 0..<opponents.count)
        let opponentId = opponents[randomOpponentIndex]
        let opponent = gameState.players[opponentId]
        
        // Filter the opponent's resources to those that have at least 1 unit.
        let availableResources = opponent.resources.filter { $0.value > 0 }
        if availableResources.isEmpty {
            print("Opponent \(opponentId) has no resources to steal.")
            return
        }
        
        // Randomly choose one available resource type.
        let resourceTypes = Array(availableResources.keys)
        let randomResourceIndex = Int.random(in: 0..<resourceTypes.count)
        let stolenResource = resourceTypes[randomResourceIndex]
        
        // Transfer one unit from the opponent to the current player.
        opponent.resources[stolenResource]! -= 1
        gameState.players[currentPlayerIndex].resources[stolenResource, default: 0] += 1
        
        updateResourceCards()
        updateBuildingButtonIcons()
        updatePlayerUISection()
        
        print("Player \(currentPlayerIndex) stole 1 \(stolenResource.rawValue) from Player \(opponentId).")
    }
    
    private func botMoveRobber() {
        var bestTile: Tile?
        var bestScore = 0
        
        // Find tile that hurts opponents most while helping self
        for tile in gameBoard.tiles {
            guard !tile.hasRobber else { continue }
            
            var tileScore = 0
            var selfResources = 0
            
            for vertex in vertices {
                // Fix: Use contains(where:) with proper closure
                guard let building = vertex.building,
                      vertex.adjacentHexes.contains(where: { $0 === tile }) else { continue }
                
                if building.ownerId != gameState.currentPlayerIndex {
                    tileScore += 2
                    if tile.resourceType != .desert {
                        tileScore += 1
                    }
                } else {
                    selfResources += 1
                }
            }
            
            // Final scoring logic remains the same
            let finalScore = tileScore * 2 - selfResources
            if finalScore > bestScore {
                bestScore = finalScore
                bestTile = tile
            }
        }
        
        if let targetTile = bestTile {
            moveRobber(to: targetTile)
        }
    }
    
    private func isTileAdjacentToSettlement(_ tile: Tile) -> Bool {
        // Only exclude tiles adjacent to settlements owned by the current player.
        let currentPlayerId = gameState.currentPlayerIndex
        for vertex in vertices {
            if vertex.adjacentHexes.contains(where: { $0 === tile }) {
                if let building = vertex.building, building.ownerId == currentPlayerId {
                    return true
                }
            }
        }
        return false
    }
    
    private func isTileAdjacentToSettlementForPlayer(_ tile: Tile, playerId: Int) -> Bool {
        for vertex in vertices {
            if vertex.adjacentHexes.contains(where: { $0 === tile }) {
                if let building = vertex.building, building.ownerId == playerId {
                    return true
                }
            }
        }
        return false
    }
    
    
    // MARK: - Development Cards

    
    func handleBuyDevelopmentCard() {
        // Define the cost of a development card (1 Wheat, 1 Sheep, 1 Ore)
        let cost: [ResourceType: Int] = [.wheat: 1, .sheep: 1, .ore: 1]
        let currentPlayer = gameState.players[0]
        
        // Check if the player can afford the card
        guard canPlayerAffordDevCard() else {
            print("Not enough resources to buy a development card")
            return
        }
        
        if !gameState.isPlayersTurn(index: 0) {
            print("Not players turn, cant buy development card")
            return
        }
                                    
        // Deduct the cost from the player's resources
        for (resource, amount) in cost {
            currentPlayer.resources[resource]! -= amount
        }
        
        // Draw a random development card from the bank
        guard let card = bank.drawDevelopmentCard() else {
            print("No development cards left in the bank")
            return
        }
        
        currentPlayer.developmentCards[card.type, default: 0] += 1
        
        if card.type == .victoryPoint {
            currentPlayer.victoryPoints += 1
        }

        // Create a sprite node for the drawn card using the correct asset
        let cardSprite: SKSpriteNode
        switch card.type {
        case .knight:
            cardSprite = SKSpriteNode(imageNamed: "card_knight.svg")
        case .roadBuilding:
            cardSprite = SKSpriteNode(imageNamed: "card_roadbuilding.svg")
        case .yearOfPlenty:
            cardSprite = SKSpriteNode(imageNamed: "card_yearofplenty.svg")
        case .monopoly:
            cardSprite = SKSpriteNode(imageNamed: "card_monopoly.svg")
        case .victoryPoint:
            cardSprite = SKSpriteNode(imageNamed: "card_vp.svg")
        }
        
        // Standardize the card size
        let cardSize = CGSize(width: 42, height: 60)
        cardSprite.size = cardSize
        
        // Calculate the new card's position in the container
        // Each new card is placed to the right of existing cards with a slight overlap
        let cardSpacing: Int = 0  // Less than the card width for overlap
        let cardCount = developmentCardsContainer.children.count
        cardSprite.position = CGPoint(
            x: ((cardCount * cardSpacing) + (cardCount * 42)),
            y: 0
        )
        cardSprite.zPosition = 1
        cardSprite.name = "devCard_\(card.type)_\(cardCount)"
        developmentCardsContainer.addChild(cardSprite)
        
        // Update the resource cards display to reflect the spent resources
        updateResourceCards()
        updateBuildingButtonIcons()
        updatePlayerUISection()
        
        print("Development card purchased: \(card.type)")
    }
    
    private func setupDevelopmentCardsContainer() {
        developmentCardsContainer = SKNode()
        developmentCardsContainer.name = "developmentCardsContainer"
        developmentCardsContainer.position = CGPoint(
            x: resourceCardsContainer.frame.maxX + 10,
            y: resourceCardsContainer.position.y
        )
        uiLayer.addChild(developmentCardsContainer)
    }
    
    private func updateDevelopmentCards() {
        // Remove any existing development card nodes from the container
        developmentCardsContainer.removeAllChildren()
        
        // Calculate the width of the resourceCardsContainer by finding the rightmost card
        var rightEdge: CGFloat = 0
        
        // Check if resourceCardsContainer has any children
        if resourceCardsContainer.children.count > 0 {
            // Find the rightmost point of all resource cards
            for child in resourceCardsContainer.children {
                let childRightEdge = child.position.x + child.frame.width/2
                rightEdge = max(rightEdge, childRightEdge)
            }
        }
        
        // Position the development cards container to the right of the resource cards
        let margin: CGFloat = 42
        developmentCardsContainer.position = CGPoint(
            x: resourceCardsContainer.position.x + rightEdge + margin,
            y: resourceCardsContainer.position.y
        )
        
        // Adjustable layout variables for development cards
        let cardSize = CGSize(width: 42, height: 60)      // Size of each development card
        let sameTypeSpacing: CGFloat = -32                // Spacing for cards of the same type (negative for overlap)
        let groupSpacing: CGFloat = 42                    // Spacing between different development card groups
        
        // Badge settings
        let badgeSize = CGSize(width: 20, height: 20)     // Size of the badge
        // Position relative to the card's center (for fine-tuning the badge location)
        let badgeOffset = CGPoint(x: cardSize.width/2 - (badgeSize.width/2 + 2),
                                 y: cardSize.height/2 - badgeSize.height/2)
        
        // Starting x position (in the container's coordinate system)
        var currentX: CGFloat = 0
        // Y position for the cards
        let posY: CGFloat = 0
        
        // Get the current player
        let player = gameState.players[0]
        
        // Mapping from DevelopmentCardType to the corresponding card image name
        let developmentCardMapping: [DevelopmentCardType: String] = [
            .knight: "card_knight",
            .victoryPoint: "card_vp",
            .roadBuilding: "card_roadbuilding",
            .yearOfPlenty: "card_yearofplenty",
            .monopoly: "card_monopoly"
        ]
        
        // Iterate through each type of development card
        for (cardType, count) in player.developmentCards {
            if count > 0, let cardKey = developmentCardMapping[cardType] {
                // For each card of this type, create a sprite
                var lastCardNode: SKSpriteNode?
                for i in 0..<count {
                    let cardNode = SKSpriteNode(imageNamed: "\(cardKey).svg")
                    cardNode.size = cardSize
                    cardNode.position = CGPoint(x: currentX, y: posY)
                    cardNode.name = "developmentCard_\(cardType)_\(i)"
                    developmentCardsContainer.addChild(cardNode)
                    
                    lastCardNode = cardNode
                    
                    // For cards of the same type, update currentX using the negative spacing
                    if i < count - 1 {
                        currentX += cardSize.width + sameTypeSpacing
                    }
                }
                
                // Add a badge to the last card in the group ONLY if there is more than one card
                if let lastCard = lastCardNode, count > 1 {
                    let badgeNode = SKSpriteNode(imageNamed: "card_badge_background.svg")
                    badgeNode.size = badgeSize
                    badgeNode.position = badgeOffset
                    badgeNode.zPosition = 1
                    badgeNode.name = "badge_\(cardType)"
                    lastCard.addChild(badgeNode)
                    
                    // Add a label to display the count
                    let countLabel = SKLabelNode(text: "\(count)")
                    countLabel.fontName = "Helvetica-Bold"
                    countLabel.fontSize = 16
                    countLabel.fontColor = UIColor(red: 1.0, green: 253.0/255.0, blue: 225.0/255.0, alpha: 1.0)
                    countLabel.verticalAlignmentMode = .center
                    countLabel.horizontalAlignmentMode = .center
                    let number_offset: CGFloat = 3
                    countLabel.position = CGPoint.zero
                    countLabel.position.x = number_offset
                    countLabel.position.y = 1
                    countLabel.zPosition = 2
                    badgeNode.addChild(countLabel)
                }
                
                // After finishing one development card group, add the group spacing
                currentX += groupSpacing
            }
        }
        
        // Update partition visibility and position
        if !resourceCardsContainer.children.isEmpty && !developmentCardsContainer.children.isEmpty {
            let partitionX = resourceCardsContainer.position.x + rightEdge + ((margin - 21) / 2)
            
            if partitionNode == nil {
                partitionNode = SKSpriteNode(imageNamed: "partition.svg")
                partitionNode!.size = CGSize(width: 2, height: 50)
                partitionNode!.zPosition = 1
                partitionNode!.alpha = 0.3
                uiLayer.addChild(partitionNode!)
            }
            
            partitionNode!.position = CGPoint(
                x: partitionX,
                y: resourceCardsContainer.position.y
            )
            partitionNode!.isHidden = false
        } else {
            partitionNode?.isHidden = true
        }
    }
    
    private func useKnight() {
        toggleKnightUISection()
        gameState.players[0].developmentCards[.knight]! -= 1
        gameState.players[0].knightsUsed += 1
        checkLargestArmy()
        isRobberMoveMode = true
        updateEndTurnButtonIcon()
        highlightValidRobberTiles()
        updateDevelopmentCards()
        updatePlayerUISection()
    }
    
    func useMonopoly() {
        // Ensure a resource was selected.
        guard let selectedResource = self.selectedMonopolyResource else {
            print("No resource selected for Monopoly.")
            return
        }
        
        let currentPlayer = gameState.players[gameState.currentPlayerIndex]
        var stolenAmount = 0
        
        // Loop over every player except the current one.
        for (index, player) in gameState.players.enumerated() {
            if index != gameState.currentPlayerIndex {
                let amount = player.resources[selectedResource] ?? 0
                stolenAmount += amount
                player.resources[selectedResource] = 0
            }
        }
        
        // Add all stolen cards to the current player's resources.
        currentPlayer.resources[selectedResource] = (currentPlayer.resources[selectedResource] ?? 0) + stolenAmount
        print("Monopoly used: Stolen \(stolenAmount) \(selectedResource.rawValue) cards.")
        
        // Optionally, remove the selected resource card from the UI.
        if let monopolyUIContainer = uiLayer.childNode(withName: "Monopoly_UI_Container"),
           let mainSection = monopolyUIContainer.childNode(withName: "Monopoly_MainSection") {
            mainSection.childNode(withName: "selectedResource")?.removeFromParent()
        }
        
        updateResourceCards()
        // Clear the selected resource.
        self.selectedMonopolyResource = nil
        
        gameState.players[0].developmentCards[.monopoly]! -= 1
        updateDevelopmentCards()
        updateBuildingButtonIcons()
        updatePlayerUISection()
    }
    
    func useYearOfPlenty() {
        guard selectedYearOfPlentyResources.count == 2 else {
            print("Please select 2 resources for Year Of Plenty.")
            selectedYearOfPlentyResources.removeAll()
            return
        }
        
        let currentPlayer = gameState.players[gameState.currentPlayerIndex]

        // For each selected resource, subtract one card from the bank and add one to the player.
        for resource in selectedYearOfPlentyResources {
            if bank.takeResources(resource: resource, amount: 1) {
                currentPlayer.resources[resource] = (currentPlayer.resources[resource] ?? 0) + 1
            } else {
                print("Bank does not have enough \(resource.rawValue) cards.")
            }
        }

        // Remove the selected resources UI from the YearOfPlenty main section.
        if let yopContainer = uiLayer.childNode(withName: "YearOfPlenty_UI_Container"),
           let mainSection = yopContainer.childNode(withName: "YearOfPlenty_MainSection") {
            mainSection.childNode(withName: "selectedResources")?.removeFromParent()
        }

        updateResourceCards()
        // Clear the selection.
        selectedYearOfPlentyResources.removeAll()
        
        gameState.players[0].developmentCards[.yearOfPlenty]! -= 1
        updateDevelopmentCards()
        updateBuildingButtonIcons()
        updatePlayerUISection()
    }
    
    private func showSelectedResourceForYearOfPlenty(resource: ResourceType) {
        // Limit selection to 2 resources.
        if selectedYearOfPlentyResources.count < 2 { selectedYearOfPlentyResources.append(resource)
        } else {
            print("Already selected 2 resources.")
            return
        }
        // Update the UI: Find the YearOfPlenty UI container and main section.
        if let yopContainer = uiLayer.childNode(withName: "YearOfPlenty_UI_Container"),
           let mainSection = yopContainer.childNode(withName: "YearOfPlenty_MainSection") as? SKShapeNode {
            
            // Remove any existing selected resources display.
            mainSection.childNode(withName: "selectedResources")?.removeFromParent()
            
            // Create a container node to hold the selected cards.
            let selectedContainer = SKNode()
            selectedContainer.name = "selectedResources"
            
            let cardSize = CGSize(width: 32.2, height: 46)
            let marginX: CGFloat = 10.0
            let marginY: CGFloat = 8.0
            let spacing: CGFloat = 5.0
            let startX = -mainSection.frame.size.width/2 + marginX + cardSize.width/2
            let posY = -mainSection.frame.size.height/2 + marginY + cardSize.height/2
            
            // For each selected resource, create the corresponding card sprite.
            for (index, res) in selectedYearOfPlentyResources.enumerated() {
                var textureName: String
                switch res {
                case .wood:
                    textureName = "card_lumber.svg"
                case .brick:
                    textureName = "card_brick.svg"
                case .sheep:
                    textureName = "card_wool.svg"
                case .wheat:
                    textureName = "card_grain.svg"
                case .ore:
                    textureName = "card_ore.svg"
                default:
                    continue
                }
                let texture = SKTexture(imageNamed: textureName)
                let cardNode = SKSpriteNode(texture: texture)
                cardNode.size = cardSize
                let xPos = startX + CGFloat(index) * (cardSize.width + spacing)
                cardNode.position = CGPoint(x: xPos, y: posY)
                cardNode.zPosition = mainSection.zPosition + 1
                cardNode.name = "YearOfPlentySelected_\(index)"
                selectedContainer.addChild(cardNode)
            }
            mainSection.addChild(selectedContainer)
        }
    }
    
    private func showSelectedResource(resource: ResourceType) {
        // Determine the texture for the resource.
        var textureName: String
        switch resource {
        case .wood:
            textureName = "card_lumber.svg"
        case .brick:
            textureName = "card_brick.svg"
        case .sheep:
            textureName = "card_wool.svg"
        case .wheat:
            textureName = "card_grain.svg"
        case .ore:
            textureName = "card_ore.svg"
        default:
            return
        }
        
        let texture = SKTexture(imageNamed: textureName)
        let selectedCard = SKSpriteNode(texture: texture)
        let cardSize = CGSize(width: 32.2, height: 46)
        selectedCard.size = cardSize
        
        // Define the margin from the bottom and left edges of the main section.
        let marginX: CGFloat = 10.0
        let marginY: CGFloat = 8.0
        
        // Retrieve the main section from the UI layer.
        if let monopolyUIContainer = uiLayer.childNode(withName: "Monopoly_UI_Container"),
               let mainSection = monopolyUIContainer.childNode(withName: "Monopoly_MainSection") as? SKShapeNode,
               let path = mainSection.path {
            
            let boundingBox = path.boundingBox
            let bottomLeft = CGPoint(x: -mainSection.frame.size.width / 2 + marginX + cardSize.width/2,
                                     y: -mainSection.frame.size.height / 2 + marginY + cardSize.height/2)
            selectedCard.position = bottomLeft
            selectedCard.zPosition = mainSection.zPosition + 1
            
            // Optionally, remove any previously selected resource card before adding the new one.
            mainSection.childNode(withName: "selectedResource")?.removeFromParent()
            selectedCard.name = "selectedResource"
            
            mainSection.addChild(selectedCard)
        }
        // Save the selected resource for later use.
        self.selectedMonopolyResource = resource
    }
    
    
    // MARK: - UI: Trade & Discard

    
    private func toggleTradeUISection() {
        if let container = uiLayer.childNode(withName: "VictoryPoint_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "Road_Building_UI_Container") {
            container.removeFromParent()
        } else if let container = uiLayer.childNode(withName: "Monopoly_UI_Container") {
            container.removeFromParent()
        }
        // Check if the trade UI section is already open.
        if let container = uiLayer.childNode(withName: "Knight_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "YearOfPlenty_UI_Container") {
            container.removeFromParent()
        }
        // Check if the trade UI section is already open.
        if let container = uiLayer.childNode(withName: "Trade_UI_Container") {
            container.removeFromParent()
            setBuildingButtonsVisible(true)
        } else {
            // Otherwise, create and display the trade UI section.
            createTradeUISection()
            setBuildingButtonsVisible(false)
        }
    }
    
    private func toggleTradePopUpUISection() {
        if let container = uiLayer.childNode(withName: "VictoryPoint_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "Road_Building_UI_Container") {
            container.removeFromParent()
        } else if let container = uiLayer.childNode(withName: "Monopoly_UI_Container") {
            container.removeFromParent()
        }
        // Check if the trade UI section is already open.
        if let container = uiLayer.childNode(withName: "Knight_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "YearOfPlenty_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "TradePopUp_UI_Container") {
            container.removeFromParent()
        } else {
            // Otherwise, create and display the trade UI section.
            createTradeUISection()
            setBuildingButtonsVisible(false)
        }
    }
    
    private func toggleDiscardCardsUISection() {
        if let container = uiLayer.childNode(withName: "Trade_UI_Container") {
            resetTradeSelection()
            toggleTradeUISection()
            returnCards()
            updateResourceCards()
            removeSelectedCards()
            removeSelectedBankCards()
        }
        if let container = uiLayer.childNode(withName: "VictoryPoint_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "Road_Building_UI_Container") {
            container.removeFromParent()
        } else if let container = uiLayer.childNode(withName: "Monopoly_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "YearOfPlenty_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "Knight_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "DiscardCards_UI_Container") {
            container.removeFromParent()
            setBuildingButtonsVisible(true)
        } else {
            // Otherwise, create and display the trade UI section.
            createDiscardCardsUISection()
            setBuildingButtonsVisible(false)
        }
    }
    
    private func toggleKnightUISection() {
        if let container = uiLayer.childNode(withName: "Trade_UI_Container") {
            resetTradeSelection()
            toggleTradeUISection()
            returnCards()
            updateResourceCards()
            removeSelectedCards()
            removeSelectedBankCards()
        }
        if let container = uiLayer.childNode(withName: "VictoryPoint_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "Road_Building_UI_Container") {
            container.removeFromParent()
        } else if let container = uiLayer.childNode(withName: "Monopoly_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "YearOfPlenty_UI_Container") {
            container.removeFromParent()
        }
        
        // Check if the trade UI section is already open.
        if let container = uiLayer.childNode(withName: "Knight_UI_Container") {
            container.removeFromParent()
            setBuildingButtonsVisible(true)
        } else {
            // Otherwise, create and display the trade UI section.
            createKnightUISection()
            setBuildingButtonsVisible(false)
        }
    }
    
    private func toggleRoadBuildingUISection() {
        if let container = uiLayer.childNode(withName: "Trade_UI_Container") {
            resetTradeSelection()
            toggleTradeUISection()
            returnCards()
            updateResourceCards()
            removeSelectedCards()
            removeSelectedBankCards()
        }
        if let container = uiLayer.childNode(withName: "VictoryPoint_UI_Container") {
            container.removeFromParent()
        }
       if let container = uiLayer.childNode(withName: "Knight_UI_Container") {
            container.removeFromParent()
        }
        // Check if the trade UI section is already open.
        if let container = uiLayer.childNode(withName: "Monopoly_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "YearOfPlenty_UI_Container") {
            container.removeFromParent()
        }
        // Check if the trade UI section is already open.
        if let container = uiLayer.childNode(withName: "Road_Building_UI_Container") {
            container.removeFromParent()
            setBuildingButtonsVisible(true)
        } else {
            // Otherwise, create and display the trade UI section.
            createRoadBuildingUISection()
            setBuildingButtonsVisible(false)
        }
    }
    
    private func toggleVictoryPointUISection() {
        if let container = uiLayer.childNode(withName: "Trade_UI_Container") {
            resetTradeSelection()
            toggleTradeUISection()
            returnCards()
            updateResourceCards()
            removeSelectedCards()
            removeSelectedBankCards()
        }
       if let container = uiLayer.childNode(withName: "Knight_UI_Container") {
            container.removeFromParent()
        }
        // Check if the trade UI section is already open.
        if let container = uiLayer.childNode(withName: "Monopoly_UI_Container") {
            container.removeFromParent()
        }
        // Check if the trade UI section is already open.
        if let container = uiLayer.childNode(withName: "Road_Building_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "YearOfPlenty_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "VictoryPoint_UI_Container") {
            container.removeFromParent()
            setBuildingButtonsVisible(true)
        } else {
            createVictoryPointUISection()
            setBuildingButtonsVisible(false)
        }
    }
    
    private func toggleMonopolyUISection() {
        if let container = uiLayer.childNode(withName: "Trade_UI_Container") {
            resetTradeSelection()
            toggleTradeUISection()
            returnCards()
            updateResourceCards()
            removeSelectedCards()
            removeSelectedBankCards()
        }
        if let container = uiLayer.childNode(withName: "Road_Building_UI_Container") {
            container.removeFromParent()
        } else if let container = uiLayer.childNode(withName: "Knight_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "VictoryPoint_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "YearOfPlenty_UI_Container") {
            container.removeFromParent()
        }
        // Check if the trade UI section is already open.
        if let container = uiLayer.childNode(withName: "Monopoly_UI_Container") {
            container.removeFromParent()
            setBuildingButtonsVisible(true)
        } else {
            // Otherwise, create and display the trade UI section.
            createMonopolyUISection()
            setBuildingButtonsVisible(false)
        }
    }
    
    private func toggleYearOfPlentyUISection() {
        if let container = uiLayer.childNode(withName: "Trade_UI_Container") {
            resetTradeSelection()
            toggleTradeUISection()
            returnCards()
            updateResourceCards()
            removeSelectedCards()
            removeSelectedBankCards()
        }
        if let container = uiLayer.childNode(withName: "Road_Building_UI_Container") {
            container.removeFromParent()
        } else if let container = uiLayer.childNode(withName: "Knight_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "VictoryPoint_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "Monopoly_UI_Container") {
            container.removeFromParent()
        }
        if let container = uiLayer.childNode(withName: "YearOfPlenty_UI_Container") {
            container.removeFromParent()
            setBuildingButtonsVisible(true)
        } else {
            // Otherwise, create and display the trade UI section.
            createYearOfPlentyUISection()
            setBuildingButtonsVisible(false)
        }
    }
    
    private func setBuildingButtonsVisible(_ visible: Bool) {
        let buildingButtonNames = ["End_Turn_Button", "City_Button", "Settlement_Button", "Road_Button", "Devcard_Button", "Trade_Button"]
        for name in buildingButtonNames {
            // This assumes that each button has been added as a child of uiLayer.
            uiLayer.childNode(withName: name)?.isHidden = !visible
        }
    }
    
    func returnCards() {
        let player = gameState.players[0]
        
        for resource in ResourceType.allCases {
            if resource == .desert { continue }
            let count = player.selectedForTrade[resource] ?? 0
            
            for i in 0..<count {
                if let currentAmount = player.resources[resource] {
                    player.resources[resource] = currentAmount + 1
                }
                if let currentSelectedAmount = player.selectedForTrade[resource] {
                    player.selectedForTrade[resource] = currentSelectedAmount - 1
                }
            }
        }
        updateBuildingButtonIcons()
        updatePlayerUISection()
    }
    
    func removeSelectedCards() {
        // Remove any existing resource card nodes from the uiLayer.
        uiLayer.children.filter { $0.name?.hasPrefix("selected_") ?? false }.forEach { $0.removeFromParent() }
    }
    
    func removeDiscardCards() {
        // Remove any existing resource card nodes from the uiLayer.
        uiLayer.children.filter { $0.name?.hasPrefix("discard_") ?? false }.forEach { $0.removeFromParent() }
    }
    
    func removeSelectedBankCards() {
        // Remove any existing resource card nodes from the uiLayer.
        uiLayer.children.filter { $0.name?.hasPrefix("bnkSelected_") ?? false }.forEach { $0.removeFromParent() }
        gameState.players[0].selectedBankCards = [.wood: 0, .brick: 0, .sheep: 0, .wheat: 0, .ore: 0]
    }

    private func selectTradeCard(_ card: SKSpriteNode,_ add: Int) {
        // Remove any existing resource card nodes from the uiLayer.
        uiLayer.children.filter { $0.name?.hasPrefix("selected_") ?? false }.forEach { $0.removeFromParent() }
        // Adjustable layout variables.
        let cardSize = CGSize(width: 42, height: 60)       // Size of each resource card.
        let sameTypeSpacing: CGFloat = -32                // Spacing for cards of the same type (negative for overlap).
        let groupSpacing: CGFloat = 43                     // Spacing between different resource groups.
        // Horizontal spacing between cards.
        let cardMargin: CGFloat = 30                        // Margin from the left and bottom edges.
        
        // Badge settings.
        let badgeSize = CGSize(width: 20, height: 20)      // Size of the badge.
        // Position relative to the card's center (adjust these to fine-tune the badge location).
        let badgeOffset = CGPoint(x: cardSize.width/2 - (badgeSize.width/2 + 2), y: cardSize.height/2 - badgeSize.height/2)
        
        
        // Starting x position so that cards begin at the left side of the bottom UI section.
        var currentX = -size.width / 2 + (cardMargin + 65) + cardSize.width / 2
        // Y position for the cards (adjust as needed).
        let posY = -size.height / 2 + cardMargin + 80 + cardSize.height / 2
        
        guard let cardName = card.name else { return }
        let components = cardName.components(separatedBy: "_")
        guard components.count >= 2 else { return }
        var resourceType: String = components[1]
        
        // Mapping from ResourceType to the corresponding card image key.
        // For example: wood maps to "lumber" (i.e. "card_lumber.svg") and wheat maps to "grain" (i.e. "card_grain.svg")
        let resourceCardMapping: [String: ResourceType] = [
            "Wood": .wood,
            "Brick": .brick,
            "Sheep": .sheep,
            "Wheat": .wheat,
            "Ore": .ore
        ]
        
        let resourceCardMapping1: [ResourceType: String] = [
            .wood: "lumber",
            .brick: "brick",
            .sheep: "wool",
            .wheat: "grain",
            .ore: "ore"
        ]
        
        // Safely unwrap the resource type.
        guard let resourceType1 = resourceCardMapping[resourceType] else {
            print("Invalid resource type: \(resourceType)")
            return
        }
        
        // Get the current player.
        let player = gameState.players[0]
        
        if let currentSelectedAmount = player.selectedForTrade[resourceType1] {
            player.selectedForTrade[resourceType1] = currentSelectedAmount + add
        }
        
        if let currentAmount = player.resources[resourceType1] {
            player.resources[resourceType1] = currentAmount - add
        }
        
        // Iterate over each resource type (skip desert as it doesn't have a resource card).
        for resource in ResourceType.allCases {
            if resource == .desert { continue }
            let count = player.selectedForTrade[resource] ?? 0
            
            if count > 0, let cardKey = resourceCardMapping1[resource] {
                // For each unit of the resource, create a card.
                var lastCardNode: SKSpriteNode?
                for i in 0..<count {
                    let texture = SKTexture(imageNamed: "card_\(cardKey).svg")
                    let cardNode = SKSpriteNode(texture: texture)
                    cardNode.size = cardSize
                    cardNode.position = CGPoint(x: currentX, y: posY)
                    // Name the card to later identify it for interaction if needed.
                    cardNode.name = "selected_\(resource.rawValue)_\(i)"
                    cardNode.zPosition = 3000
                    uiLayer.addChild(cardNode)
                    
                    lastCardNode = cardNode
                    
                    // For cards of the same type, update currentX using the negative spacing.
                    if i < count - 1 {
                        currentX += cardSize.width + sameTypeSpacing
                    }
                }
                // Add a badge to the last card in the group.
                if let lastCard = lastCardNode {
                    let badgeTexture = SKTexture(imageNamed: "card_badge_background.svg")
                    let badgeNode = SKSpriteNode(texture: badgeTexture)
                    badgeNode.size = badgeSize
                    badgeNode.position = badgeOffset
                    badgeNode.zPosition = lastCard.zPosition + 1
                    badgeNode.name = "badge_\(resource.rawValue)"
                    lastCard.addChild(badgeNode)
                    
                    // Add a label to display the count.
                    let countLabel = SKLabelNode(text: "\(count)")
                    countLabel.fontName = "Helvetica-Bold"
                    countLabel.fontSize = 16
                    countLabel.fontColor = .white
                    countLabel.verticalAlignmentMode = .center
                    countLabel.horizontalAlignmentMode = .center
                    let number_offset: CGFloat = 3
                    countLabel.position = CGPoint.zero
                    countLabel.position.x = number_offset
                    countLabel.position.y = 1
                    countLabel.zPosition = lastCard.zPosition + 2
                    badgeNode.addChild(countLabel)
                }
                // After finishing one resource group, add a small positive spacing.
                currentX += groupSpacing
                
                updateBankCheckIconOpacity()
                updateTradeWithPlayersIconOpacity()
            }
        }
    }
    
    private func resetTradeSelection() {
        // Clear current selection
        for card in selectedTradeCards {
            card.removeFromParent()
        }
        
        selectedTradeCards.removeAll()
        
        // Refresh UI
        updateResourceCards()
    }
    
    private func selectDiscardCard(_ card: SKSpriteNode,_ add: Int) {
        // Remove any existing resource card nodes from the uiLayer.
        uiLayer.children.filter { $0.name?.hasPrefix("discard_") ?? false }.forEach { $0.removeFromParent() }
        // Adjustable layout variables.
        let cardSize = CGSize(width: 40, height: 58)       // Size of each resource card.
        let sameTypeSpacing: CGFloat = -32                // Spacing for cards of the same type (negative for overlap).
        let groupSpacing: CGFloat = 43                     // Spacing between different resource groups.
        // Horizontal spacing between cards.
        let cardMargin: CGFloat = 30                        // Margin from the left and bottom edges.
        
        // Badge settings.
        let badgeSize = CGSize(width: 20, height: 20)      // Size of the badge.
        // Position relative to the card's center (adjust these to fine-tune the badge location).
        let badgeOffset = CGPoint(x: cardSize.width/2 - (badgeSize.width/2 + 2), y: cardSize.height/2 - badgeSize.height/2)
        
        
        // Starting x position so that cards begin at the left side of the bottom UI section.
        var currentX = -size.width / 2 + (15) + cardSize.width / 2
        // Y position for the cards (adjust as needed).
        let posY = -size.height / 2 + cardMargin + 135 + cardSize.height / 2
        
        guard let cardName = card.name else { return }
        let components = cardName.components(separatedBy: "_")
        guard components.count >= 2 else { return }
        var resourceType: String = components[1]
        
        // Mapping from ResourceType to the corresponding card image key.
        // For example: wood maps to "lumber" (i.e. "card_lumber.svg") and wheat maps to "grain" (i.e. "card_grain.svg")
        let resourceCardMapping: [String: ResourceType] = [
            "Wood": .wood,
            "Brick": .brick,
            "Sheep": .sheep,
            "Wheat": .wheat,
            "Ore": .ore
        ]
        
        let resourceCardMapping1: [ResourceType: String] = [
            .wood: "lumber",
            .brick: "brick",
            .sheep: "wool",
            .wheat: "grain",
            .ore: "ore"
        ]
        
        // Safely unwrap the resource type.
        guard let resourceType1 = resourceCardMapping[resourceType] else {
            print("Invalid resource type: \(resourceType)")
            return
        }
        
        // Get the current player.
        let player = gameState.players[0]
        
        if let currentSelectedAmount = player.selectedToDiscard[resourceType1] {
            player.selectedToDiscard[resourceType1] = currentSelectedAmount + add
        }
        
        if let currentAmount = player.resources[resourceType1] {
            player.resources[resourceType1] = currentAmount - add
        }
        
        // Iterate over each resource type (skip desert as it doesn't have a resource card).
        for resource in ResourceType.allCases {
            if resource == .desert { continue }
            let count = player.selectedToDiscard[resource] ?? 0
            
            if count > 0, let cardKey = resourceCardMapping1[resource] {
                // For each unit of the resource, create a card.
                var lastCardNode: SKSpriteNode?
                for i in 0..<count {
                    let texture = SKTexture(imageNamed: "card_\(cardKey).svg")
                    let cardNode = SKSpriteNode(texture: texture)
                    cardNode.size = cardSize
                    cardNode.position = CGPoint(x: currentX, y: posY)
                    // Name the card to later identify it for interaction if needed.
                    cardNode.name = "discard_\(resource.rawValue)_\(i)"
                    cardNode.zPosition = 3000
                    uiLayer.addChild(cardNode)
                    
                    lastCardNode = cardNode
                    
                    // For cards of the same type, update currentX using the negative spacing.
                    if i < count - 1 {
                        currentX += cardSize.width + sameTypeSpacing
                    }
                }
                // Add a badge to the last card in the group.
                if let lastCard = lastCardNode {
                    let badgeTexture = SKTexture(imageNamed: "card_badge_background.svg")
                    let badgeNode = SKSpriteNode(texture: badgeTexture)
                    badgeNode.size = badgeSize
                    badgeNode.position = badgeOffset
                    badgeNode.zPosition = lastCard.zPosition + 1
                    badgeNode.name = "badge_\(resource.rawValue)"
                    lastCard.addChild(badgeNode)
                    
                    // Add a label to display the count.
                    let countLabel = SKLabelNode(text: "\(count)")
                    countLabel.fontName = "Helvetica-Bold"
                    countLabel.fontSize = 12
                    countLabel.fontColor = .white
                    countLabel.verticalAlignmentMode = .center
                    countLabel.horizontalAlignmentMode = .center
                    let number_offset: CGFloat = 2
                    countLabel.position = CGPoint.zero
                    countLabel.position.x = number_offset
                    countLabel.zPosition = lastCard.zPosition + 2
                    badgeNode.addChild(countLabel)
                }
                // After finishing one resource group, add a small positive spacing.
                currentX += groupSpacing
            }
        }
    }
    
    private func selectBankCard(_ card: SKSpriteNode,_ add: Int) {
        // Remove any existing resource card nodes from the uiLayer.
        uiLayer.children.filter { $0.name?.hasPrefix("bnkSelected_") ?? false }.forEach { $0.removeFromParent() }
        // Adjustable layout variables.
        let cardSize = CGSize(width: 42, height: 60)       // Size of each resource card.
        let sameTypeSpacing: CGFloat = -32                // Spacing for cards of the same type (negative for overlap).
        let groupSpacing: CGFloat = 43                     // Spacing between different resource groups.
        // Horizontal spacing between cards.
        let cardMargin: CGFloat = 30                        // Margin from the left and bottom edges.
        
        // Badge settings.
        let badgeSize = CGSize(width: 20, height: 20)      // Size of the badge.
        // Position relative to the card's center (adjust these to fine-tune the badge location).
        let badgeOffset = CGPoint(x: cardSize.width/2 - (badgeSize.width/2 + 2), y: cardSize.height/2 - badgeSize.height/2)
        
        
        // Starting x position so that cards begin at the left side of the bottom UI section.
        var currentX = -size.width / 2 + (cardMargin + 65) + cardSize.width / 2
        // Y position for the cards (adjust as needed).
        let posY = -size.height / 2 + cardMargin + 189 + cardSize.height / 2
        
        guard let cardName = card.name else { return }
        let components = cardName.components(separatedBy: "_")
        guard components.count >= 2 else { return }
        var resourceType: String = components[1]
        
        // Mapping from ResourceType to the corresponding card image key.
        // For example: wood maps to "lumber" (i.e. "card_lumber.svg") and wheat maps to "grain" (i.e. "card_grain.svg")
        let resourceCardMapping: [String: ResourceType] = [
            "Wood": .wood,
            "Brick": .brick,
            "Sheep": .sheep,
            "Wheat": .wheat,
            "Ore": .ore
        ]
        
        let resourceCardMapping1: [ResourceType: String] = [
            .wood: "lumber",
            .brick: "brick",
            .sheep: "wool",
            .wheat: "grain",
            .ore: "ore"
        ]
        
        // Safely unwrap the resource type.
        guard let resourceType1 = resourceCardMapping[resourceType] else {
            print("Invalid resource type: \(resourceType)")
            return
        }
        
        // Get the current player.
        let player = gameState.players[0]
        
        if let currentSelectedAmount = player.selectedBankCards[resourceType1] {
            player.selectedBankCards[resourceType1] = currentSelectedAmount + add
        }
        
        // Iterate over each resource type (skip desert as it doesn't have a resource card).
        for resource in ResourceType.allCases {
            if resource == .desert { continue }
            let count = player.selectedBankCards[resource] ?? 0
            
            if count > 0, let cardKey = resourceCardMapping1[resource] {
                // For each unit of the resource, create a card.
                var lastCardNode: SKSpriteNode?
                for i in 0..<count {
                    let texture = SKTexture(imageNamed: "card_\(cardKey).svg")
                    let cardNode = SKSpriteNode(texture: texture)
                    cardNode.size = cardSize
                    cardNode.position = CGPoint(x: currentX, y: posY)
                    // Name the card to later identify it for interaction if needed.
                    cardNode.name = "bnkSelected_\(resource.rawValue)_\(i)"
                    cardNode.zPosition = 3000
                    uiLayer.addChild(cardNode)
                    
                    lastCardNode = cardNode
                    
                    // For cards of the same type, update currentX using the negative spacing.
                    if i < count - 1 {
                        currentX += cardSize.width + sameTypeSpacing
                    }
                }
                // Add a badge to the last card in the group.
                if let lastCard = lastCardNode {
                    let badgeTexture = SKTexture(imageNamed: "card_badge_background.svg")
                    let badgeNode = SKSpriteNode(texture: badgeTexture)
                    badgeNode.size = badgeSize
                    badgeNode.position = badgeOffset
                    badgeNode.zPosition = lastCard.zPosition + 1
                    badgeNode.name = "badge_\(resource.rawValue)"
                    lastCard.addChild(badgeNode)
                    
                    // Add a label to display the count.
                    let countLabel = SKLabelNode(text: "\(count)")
                    countLabel.fontName = "Helvetica-Bold"
                    countLabel.fontSize = 16
                    countLabel.fontColor = .white
                    countLabel.verticalAlignmentMode = .center
                    countLabel.horizontalAlignmentMode = .center
                    let number_offset: CGFloat = 3
                    countLabel.position = CGPoint.zero
                    countLabel.position.x = number_offset
                    countLabel.position.y = 1
                    countLabel.zPosition = lastCard.zPosition + 2
                    badgeNode.addChild(countLabel)
                }
                // After finishing one resource group, add a small positive spacing.
                currentX += groupSpacing
            }
        }
        updateBankCheckIconOpacity()
        updateTradeWithPlayersIconOpacity()
    }
    
    func isAggregatedTradeValid(for player: Player) -> Bool {
        // Mapping from each resource type to its specific port asset name.
        let specificPortMapping: [ResourceType: String] = [
            .wood: "port_lumber.svg",
            .brick: "port_brick.svg",
            .sheep: "port_wool.svg",
            .wheat: "port_grain.svg",
            .ore: "port_ore.svg"
        ]
        
        // 1. Calculate total trade groups available using the appropriate conversion ratio.
        var totalInputGroups = 0
        for resource in ResourceType.allCases {
            let inputCount = player.selectedForTrade[resource] ?? 0
            
            // Determine the conversion ratio for this resource:
            // If a specific port for this resource is unlocked, ratio = 2.
            // Else if a generic port ("port.svg") is unlocked, ratio = 3.
            // Otherwise, ratio = 4.
            let tradeRatio: Int
            if let specificPort = specificPortMapping[resource], player.portsUnlocked.contains(specificPort) {
                tradeRatio = 2
            } else if player.portsUnlocked.contains("port.svg") {
                tradeRatio = 3
            } else {
                tradeRatio = 4
            }
            
            // Each input count must be exactly divisible by the applicable trade ratio.
            if inputCount % tradeRatio != 0 {
                return false
            }
            
            totalInputGroups += inputCount / tradeRatio
        }
        
        // 2. Calculate the total number of output cards requested.
        let totalRequestedOutputs = ResourceType.allCases.reduce(0) { total, resource in
            total + (player.selectedBankCards[resource] ?? 0)
        }
        
        // The trade is only valid if there is at least one trade group,
        // and the total outputs exactly match the total input groups.
        if totalInputGroups == 0 || totalRequestedOutputs != totalInputGroups {
            return false
        }
        
        // 3. Ensure that for each resource, if any input is provided, that same resource is not requested as output.
        for resource in ResourceType.allCases {
            let inputCount = player.selectedForTrade[resource] ?? 0
            let outputCount = player.selectedBankCards[resource] ?? 0
            if inputCount > 0 && outputCount > 0 {
                return false
            }
        }
        
        return true
    }

    private func isPlayerTradeValid(for player: Player) -> Bool {
        // 1. Check if at least one resource is selected for trade
        let totalInput = player.selectedForTrade.values.reduce(0, +)
        guard totalInput >= 1 else {
            return false
        }
        
        // 2. Check if exactly one resource is selected from the bank
        let totalOutput = player.selectedBankCards.values.reduce(0, +)
        guard totalOutput >= 1 else {
            return false
        }
        
        // 3. Check that traded resources and received resource aren't the same type
        for resource in ResourceType.allCases {
            let inputCount = player.selectedForTrade[resource] ?? 0
            let outputCount = player.selectedBankCards[resource] ?? 0
            
            if inputCount > 0 && outputCount > 0 {
                return false
            }
        }
        
        return true
    }
    
    private func checkBankButtonOpacity() -> Bool {
        if let tradeUI = uiLayer.childNode(withName: "Trade_UI_Container"),
           let tradeBankButton = tradeUI.childNode(withName: "TradeBankButton"),
           let bankIcon = tradeBankButton.childNode(withName: "bankCheckIcon") as? SKSpriteNode {
            if bankIcon.alpha == 1.0 {
                return true
            } else {
                return false
            }
        }
        return false
    }
    
    private func checkBotTradeButtonOpacity(_ index: Int) -> Bool {
        if let tradePopUI = uiLayer.childNode(withName: "TradePopUp_UI_Container"),
           let tradeBotButton = tradePopUI.childNode(withName: "botTradeButton_\(index)") {
            if tradeBotButton.alpha == 1.0 {
                return true
            } else {
                return false
            }
        }
        return false
    }
    
    private func checkTradePlayersButtonOpacity() -> Bool {
        if let tradeUI = uiLayer.childNode(withName: "Trade_UI_Container"),
           let tradeBankButton = tradeUI.childNode(withName: "TradeOpponentsButton"),
           let bankIcon = tradeBankButton.childNode(withName: "tradeOpponentsCheckIcon") as? SKSpriteNode {
            if bankIcon.alpha == 1.0 {
                return true
            } else {
                return false
            }
        }
        return false
    }
    
    private func trade() {
        let player = gameState.players[0]
        
        // Add selected bank cards to player's resources
        for (resource, count) in player.selectedBankCards {
            player.resources[resource, default: 0] += count
        }
        
        // Clear both selections
        for resource in ResourceType.allCases {
            player.selectedForTrade[resource] = 0
            player.selectedBankCards[resource] = 0
        }
        
        // Update UI elements
        updateResourceCards()
        removeSelectedCards()
        removeSelectedBankCards()
        
        // Reset trade UI state
        updateBankCheckIconOpacity()
        updateTradeWithPlayersIconOpacity()
        
        updateBuildingButtonIcons()
        updatePlayerUISection()
    }
    
    private func updateBankCheckIconOpacity() {
        let player = gameState.players[0]
        
        let isValid = isAggregatedTradeValid(for: player)
        
        // 3. Update icon opacity based on conditions
        if let tradeUI = uiLayer.childNode(withName: "Trade_UI_Container"),
           let tradeBankButton = tradeUI.childNode(withName: "TradeBankButton"),
           let bankIcon = tradeBankButton.childNode(withName: "bankCheckIcon") as? SKSpriteNode {
            
            bankIcon.alpha = (isValid) ? 1.0 : 0.5
        }
    }
    
    private func updateTradeWithPlayersIconOpacity() {
        let player = gameState.players[0]
        
        let isValid = isPlayerTradeValid(for: player)
        
        // 3. Update icon opacity based on conditions
        if let tradeUI = uiLayer.childNode(withName: "Trade_UI_Container"),
           let tradeBankButton = tradeUI.childNode(withName: "TradeOpponentsButton"),
           let bankIcon = tradeBankButton.childNode(withName: "tradeOpponentsCheckIcon") as? SKSpriteNode {
            
            bankIcon.alpha = (isValid) ? 1.0 : 0.5
        }
    }
    
    private func botEvaluateTrade() {
        guard let tradePopup = uiLayer.childNode(withName: "TradePopUp_UI_Container") else { return }
        
        var botButtons: [SKSpriteNode] = []
        for botIndex in 1...3 {
            if let button = tradePopup.childNode(withName: "botTradeButton_\(botIndex)") as? SKSpriteNode {
                botButtons.append(button)
            } else {
                print("Button botTradeButton_\(botIndex) not found")
            }
        }
        
        for (index, button) in botButtons.enumerated() {
            let botIndex = index + 1 // Players 1, 2, 3
            guard botIndex < gameState.players.count else { continue }
            let bot = gameState.players[botIndex]
            
            // Check if the bot has all resources the player is requesting
            var hasEnoughResources = true
            for (resource, requestedAmount) in gameState.players[0].selectedBankCards {
                if bot.resources[resource] ?? 0 < requestedAmount {
                    hasEnoughResources = false
                    break
                }
            }
            
          
            if hasEnoughResources {
                // Replace hourglass icon with checkmark
                if let hourglassNode = button.childNode(withName: "//HourglassIcon\(botIndex)") as? SKSpriteNode {
                    let delayAction = SKAction.wait(forDuration: 0.5)
                    let updateAction = SKAction.run {
                        button.alpha = 1.0
                        hourglassNode.texture = SKTexture(imageNamed: "icon_check.svg")
                        hourglassNode.size = CGSize(width: 25, height: 25)
                        hourglassNode.alpha = 1.0
                    }
                    button.run(SKAction.sequence([delayAction, updateAction]))
                }
            } else {
                if let hourglassNode = button.childNode(withName: "//HourglassIcon\(botIndex)") as? SKSpriteNode {
                    let delayAction = SKAction.wait(forDuration: 0.5)
                    let updateAction = SKAction.run {
                        hourglassNode.texture = SKTexture(imageNamed: "icon_x.svg")
                        hourglassNode.size = CGSize(width: 25, height: 25)
                    }
                    button.run(SKAction.sequence([delayAction, updateAction]))
                }
            }
        }
    }
    
    private func deleteTradePopUpCards() {
    // Filter uiLayer's children with names starting with "tradePopUp_"
       let cardNodes = uiLayer.children.filter { node in
           return node.name?.hasPrefix("tradePopUp_") ?? false
       }
       
       // Remove each identified node from its parent
       cardNodes.forEach { $0.removeFromParent() }
    }
    
    private func performTrade(withBotIndex botIndex: Int) {
        // Get the human player (assumed to be at index 0)
        let humanPlayer = gameState.players[0]
        
        // Validate that the bot index is in range and fetch the bot
        guard botIndex < gameState.players.count else {
            print("Invalid bot index: \(botIndex)")
            return
        }
        let bot = gameState.players[botIndex]
        
        // --- 1. Transfer Resources from Human to Bot ---
        // Resources being offered by the player (selectedForTrade) go to the bot.
        for (resource, amount) in humanPlayer.selectedForTrade {
            // Ensure the human has enough of this resource.
            guard let humanAmount = humanPlayer.selectedForTrade[resource], humanAmount >= amount else {
                print("Trade error: human player does not have enough \(resource)")
                return
            }
            // Deduct the resources from the human player's inventory.
            humanPlayer.selectedForTrade[resource] = humanAmount - amount
            // Add these resources to the bot.
            bot.resources[resource] = (bot.resources[resource] ?? 0) + amount
        }
        
        // --- 2. Transfer Resources from Bot to Human ---
        // Resources requested by the human (selectedBankCards) come from the bot.
        for (resource, amount) in humanPlayer.selectedBankCards {
            // Ensure the bot has enough resources.
            guard let botAmount = bot.resources[resource], botAmount >= amount else {
                print("Trade error: Bot \(botIndex) does not have enough \(resource)")
                return
            }
            // Deduct the resources from the bot.
            bot.resources[resource] = botAmount - amount
            // Add these resources to the human player's inventory.
            humanPlayer.resources[resource] = (humanPlayer.resources[resource] ?? 0) + amount
        }
        returnCards()
        removeSelectedCards()
        removeSelectedBankCards()
        updateResourceCards()
        toggleTradePopUpUISection()
        deleteTradePopUpCards()
    }
    
    
    // MARK: - UI: Resource & Building Buttons

    
    private func createBuildingButtons() {
        // Number of buttons to create.
        let buttonCount = 6

        // Load the button texture.
        let buttonTexture = SKTexture(imageNamed: "bg_button.svg")

        // Adjustable variables for button appearance.
        let buttonWidth: CGFloat = 60.0       // Width of each button.
        let buttonHeight: CGFloat = 60.0      // Height of each button.
        let buttonSpacing: CGFloat = 10.0     // Horizontal space between buttons.
        //let rightMargin: CGFloat = 20.0       // Space from the right edge of the screen.

        // These values must match the ones you use in addBottomUISection().
        let bottomSectionHeight: CGFloat = 80.0  // Height of the bottom section.
        let bottomSectionMargin: CGFloat = 20.0   // Margin from the bottom edge for the section.

        // Compute the top edge of the bottom section.
        // uiLayer is centered at (0,0); the bottom edge is at -size.height/2.
        let bottomSectionTop = (-size.height / 2) + bottomSectionMargin + bottomSectionHeight

        // Define the vertical margin between the bottom section and the buttons.
        let buttonVerticalMargin: CGFloat = 10.0

        // The buttons' y-position is such that their bottom edge sits at:
        // bottomSectionTop + buttonVerticalMargin.
        // Since the button’s position is its center, add half the button height.
        let yPosition = bottomSectionTop + buttonVerticalMargin + (buttonHeight / 2)

        // Compute the right edge in uiLayer coordinates.
        //let rightEdgeX = size.width / 2 - rightMargin
        
        // Compute the total width taken up by the row of buttons.
        let totalRowWidth = CGFloat(buttonCount) * buttonWidth + CGFloat(buttonCount - 1) * buttonSpacing
        
        // To center horizontally, calculate the starting x position such that the row's center is 0.
        let startX = -totalRowWidth / 2 + buttonWidth / 2

        // The leftmost button's center x-position so that the row ends at rightEdgeX.
        //let startX = rightEdgeX - totalRowWidth + buttonWidth / 2

        // Get the current player's color from gameState.
        let playerColor = gameState.players[gameState.currentPlayerIndex].assetColor
        
        // Define icon specifications as an array of tuples:
        // Each tuple contains the icon's filename and its desired size (width and height).
        // For the icons that depend on the player's color, we interpolate the color into the filename.
        let iconSpecs: [(filename: String, size: CGSize)] = [
            ("icon_trade.svg", CGSize(width: 35, height: 35)), // Leftmost button.
            ("card_devcardback.svg", CGSize(width: 25, height: 35)),
            ("road_\(playerColor).svg", CGSize(width: 7, height: 35)),
            ("settlement_\(playerColor).svg", CGSize(width: 35, height: 35)),
            ("city_\(playerColor).svg", CGSize(width: 35, height: 35)),
            ("icon_hourglass", CGSize(width: 35, height: 35))   // Rightmost button.
        ]
        
        // Define the desired alpha (opacity) for inactive icons.
       let inactiveIconAlpha: CGFloat = 0.5  // Adjust this value as needed (0 = fully transparent, 1 = opaque)
       
        // Define badge properties for settlement, city, and road buttons.
        let badgeSize = CGSize(width: 20, height: 20)
        // Position the badge at the top-right of the button (offset slightly inward).
        let badgeOffset = CGPoint(x: buttonWidth/2 - badgeSize.width/2 - 4,
                                  y: buttonHeight/2 - badgeSize.height/2 - 2)

        // Loop to create each button.
        for i in 0..<buttonCount {
            // Create the button background.
            let button = SKSpriteNode(texture: buttonTexture)
            button.size = CGSize(width: buttonWidth, height: buttonHeight)
            let xPosition = startX + CGFloat(i) * (buttonWidth + buttonSpacing)
            button.position = CGPoint(x: xPosition, y: yPosition)
            button.zPosition = 101  // Ensure buttons appear above other UI elements.
            //button.name = "centeredButton_\(i)"  // Unique name for each button.
            
            print(i)
            
            if i == 5 {
                button.name = "End_Turn_Button"
            } else if i == 4 {
                button.name = "City_Button"
            } else if i == 3 {
                button.name = "Settlement_Button"
            } else if i == 2 {
                button.name = "Road_Button"
            } else if i == 1 {
                button.name = "Devcard_Button"
            } else if i == 0 {
                button.name = "Trade_Button"
            }
            
            // Add the icon as a child node of the button.
            if i < iconSpecs.count {
                let spec = iconSpecs[i]
                let iconTexture = SKTexture(imageNamed: spec.filename)
                let iconNode = SKSpriteNode(texture: iconTexture)
                iconNode.size = spec.size
                // Position the icon at the center of the button; adjust if needed.
                iconNode.position = CGPoint.zero
                iconNode.zPosition = 102  // Ensure the icon is above the button background.
                
                // Instead of tinting, change the opacity to show inactivity.
                iconNode.alpha = (i == 5) ? inactiveIconAlpha : 1.0

                button.addChild(iconNode)
                
                // For settlement, city, and road buttons, add an extra badge icon.
                if button.name == "Settlement_Button" || button.name == "City_Button" || button.name == "Road_Button" {
                    // Construct the badge asset name by interpolating the player's color.
                    let badgeFilename = "button_badge_background_\(playerColor).svg"
                    let badgeTexture = SKTexture(imageNamed: badgeFilename)
                    let badgeNode = SKSpriteNode(texture: badgeTexture)
                    badgeNode.size = badgeSize
                    badgeNode.position = badgeOffset
                    badgeNode.zPosition = 103  // Ensure it appears above the main icon.
                    // Initially set the badge's opacity to match the main icon.
                    badgeNode.alpha = iconNode.alpha
                    
                    var countt = 0
                    // Give the badge a name so it can be easily referenced later.
                    if button.name == "Settlement_Button" {
                        badgeNode.name = "badge_Settlement"
                        countt = gameState.players[gameState.currentPlayerIndex].settlementsLeft
                    } else if button.name == "City_Button" {
                        badgeNode.name = "badge_City"
                        countt = gameState.players[gameState.currentPlayerIndex].citiesLeft
                    } else if button.name == "Road_Button" {
                        badgeNode.name = "badge_Road"
                        countt = gameState.players[gameState.currentPlayerIndex].roadsLeft
                    }

                    // Add a count label on top of the badge.
                    let countLabel = SKLabelNode(text: "\(countt)")
                    countLabel.fontName = "Helvetica-Bold"
                    countLabel.fontSize = 12
                    countLabel.fontColor = .white
                    countLabel.verticalAlignmentMode = .center
                    countLabel.horizontalAlignmentMode = .center
                    countLabel.position = CGPoint.zero
                    countLabel.position.x = 2
                    countLabel.position.y = 1
                    countLabel.zPosition = badgeNode.zPosition + 1
                    countLabel.name = "Count_Left"
                    badgeNode.addChild(countLabel)

                    // Add the badge as a child of the button.
                    button.addChild(badgeNode)
                }
            }
            
            uiLayer.addChild(button)
        }
    }
    
    private func updateBuildingButtonIcons() {
        let playerIndex = 0
        let player = gameState.players[0]
        let isPlayersTurn = gameState.isPlayersTurn(index: playerIndex)
        let hasRolledDice = gameState.hasRolledDice
        
        // Road Button update
        if let roadButton = uiLayer.childNode(withName: "Road_Button") as? SKSpriteNode,
           let roadIcon = roadButton.children.first as? SKSpriteNode {
            let canBuildRoad = (canPlayerAffordBuilding(type: .road) && player.canBuild(buildingType: .road) && isPlayersTurn && hasRolledDice && !roadBuildingModeActive)
            roadIcon.alpha = canBuildRoad ? 1.0 : 0.5
            // Update badge alpha for the Road_Button.
            if let badge = roadButton.childNode(withName: "badge_Road") as? SKSpriteNode {
                badge.alpha = roadIcon.alpha
                
                if let countLabel = badge.childNode(withName: "Count_Left") as? SKLabelNode {
                    countLabel.text = "\(gameState.players[0].roadsLeft)"
                }
            }
        }

        // Settlement Button update
        if let settlementButton = uiLayer.childNode(withName: "Settlement_Button") as? SKSpriteNode,
           let settlementIcon = settlementButton.children.first as? SKSpriteNode {
            let canBuildSettlement = (canPlayerAffordBuilding(type: .settlement) && player.canBuild(buildingType: .settlement) && isPlayersTurn && hasRolledDice && !roadBuildingModeActive)
            settlementIcon.alpha = canBuildSettlement ? 1.0 : 0.5
            // Update badge alpha for the Settlement_Button.
            if let badge = settlementButton.childNode(withName: "badge_Settlement") as? SKSpriteNode {
                badge.alpha = settlementIcon.alpha
                
                if let countLabel = badge.childNode(withName: "Count_Left") as? SKLabelNode {
                    countLabel.text = "\(gameState.players[0].settlementsLeft)"
                }
            }
        }

        // City Button update
        if let cityButton = uiLayer.childNode(withName: "City_Button") as? SKSpriteNode,
           let cityIcon = cityButton.children.first as? SKSpriteNode {
            let canBuildCity = (canPlayerAffordBuilding(type: .city) && player.canBuild(buildingType: .city) && isPlayersTurn && hasRolledDice && !roadBuildingModeActive)
            cityIcon.alpha = canBuildCity ? 1.0 : 0.5
            // Update badge alpha for the City_Button.
            if let badge = cityButton.childNode(withName: "badge_City") as? SKSpriteNode {
                badge.alpha = cityIcon.alpha
                
                if let countLabel = badge.childNode(withName: "Count_Left") as? SKLabelNode {
                    countLabel.text = "\(gameState.players[0].citiesLeft)"
                }
            }
        }
        
        // Buy Development Card Button Update
        if let developmentButton = uiLayer.childNode(withName: "Devcard_Button") as? SKSpriteNode,
           let devCardIcon = developmentButton.children.first as? SKSpriteNode {
            devCardIcon
            let canBuyDevCard = (canPlayerAffordDevCard() && isPlayersTurn && hasRolledDice && !roadBuildingModeActive)
            devCardIcon.alpha = canBuyDevCard ? 1.0 : 0.5
        }
        
        //Trade Button Update
        if let tradeButton = uiLayer.childNode(withName: "Trade_Button") as? SKSpriteNode,
           let tradeIcon = tradeButton.children.first as? SKSpriteNode {
            let canTrade = (isPlayersTurn && hasRolledDice && !roadBuildingModeActive)
            tradeIcon.alpha = canTrade ? 1.0 : 0.5
        }
    }
    
    private func setupResourceCardsContainer() {
        resourceCardsContainer = SKNode()
        resourceCardsContainer.name = "resourceCardsContainer"
        resourceCardsContainer.position = CGPoint(x: -size.width / 2 + 39, y: -size.height / 2 + 60)
        uiLayer.addChild(resourceCardsContainer)
    }
    
    private func updateResourceCards() {
        // Remove any existing resource card nodes from the container
        resourceCardsContainer.removeAllChildren()
        
        // Adjustable layout variables
        let cardSize = CGSize(width: 42, height: 60)      // Size of each resource card
        let sameTypeSpacing: CGFloat = -32                // Spacing for cards of the same type (negative for overlap)
        let groupSpacing: CGFloat = 42                    // Spacing between different resource groups
        let cardMargin: CGFloat = 30                      // Margin from the edges
        
        // Badge settings
        let badgeSize = CGSize(width: 20, height: 20)     // Size of the badge
        // Position relative to the card's center (for fine-tuning the badge location)
        let badgeOffset = CGPoint(x: cardSize.width/2 - (badgeSize.width/2 + 2),
                                 y: cardSize.height/2 - badgeSize.height/2)
        
        // Starting x position (in the container's coordinate system)
        var currentX: CGFloat = 0
        // Y position for the cards
        let posY: CGFloat = 0
        
        // Mapping from ResourceType to the corresponding card image key
        let resourceCardMapping: [ResourceType: String] = [
            .wood: "lumber",
            .brick: "brick",
            .sheep: "wool",
            .wheat: "grain",
            .ore: "ore"
        ]
        
        // Get the current player
        let player = gameState.players[0]
        
        // Iterate over each resource type (skip desert as it doesn't have a resource card)
        for resource in ResourceType.allCases where resource != .desert {
            let count = player.resources[resource] ?? 0
            if count > 0, let cardKey = resourceCardMapping[resource] {
                // For each unit of the resource, create a card
                var lastCardNode: SKSpriteNode?
                for i in 0..<count {
                    let cardNode = SKSpriteNode(imageNamed: "card_\(cardKey).svg")
                    cardNode.size = cardSize
                    cardNode.position = CGPoint(x: currentX, y: posY)
                    // Name the card to later identify it for interaction if needed
                    cardNode.name = "resourceCard_\(resource.rawValue)_\(i)"
                    resourceCardsContainer.addChild(cardNode)
                    
                    lastCardNode = cardNode
                    
                    // For cards of the same type, update currentX using the negative spacing
                    if i < count - 1 {
                        currentX += cardSize.width + sameTypeSpacing
                    }
                }
                
                // Add a badge to the last card in the group
                if let lastCard = lastCardNode {
                    let badgeNode = SKSpriteNode(imageNamed: "card_badge_background.svg")
                    badgeNode.size = badgeSize
                    badgeNode.position = badgeOffset
                    badgeNode.zPosition = 1
                    badgeNode.name = "badge_\(resource.rawValue)"
                    lastCard.addChild(badgeNode)
                    
                    // Add a label to display the count
                    let countLabel = SKLabelNode(text: "\(count)")
                    countLabel.fontName = "Helvetica-Bold"
                    countLabel.fontSize = 16
                    countLabel.fontColor = UIColor(red: 1.0, green: 253.0/255.0, blue: 225.0/255.0, alpha: 1.0)
                    countLabel.verticalAlignmentMode = .center
                    countLabel.horizontalAlignmentMode = .center
                    let number_offset: CGFloat = 3
                    countLabel.position = CGPoint.zero
                    countLabel.position.x = number_offset
                    countLabel.position.y = 1
                    countLabel.zPosition = 2
                    badgeNode.addChild(countLabel)
                }
                
                // After finishing one resource group, add the group spacing
                currentX += groupSpacing
            }
        }
        
        // Update development cards position after resource cards update
        updateDevelopmentCards()
    }
    
    
    // MARK: - Discard Mechanics

    
    private func discardCards() {
        let player = gameState.players[0]
        
        for resource in ResourceType.allCases {
            player.selectedToDiscard[resource] = 0
            player.selectedToDiscard[resource] = 0
        }
        
        removeDiscardCards()
        updatePlayerUISection()
    }
    
    func updateDiscardCardsUISection() {
        let player = gameState.players[0]

        let numSelected = player.selectedToDiscard.values.reduce(0, +)
        
        let font = UIFont.systemFont(ofSize: 20, weight: .bold - 0.1)
        
        if let titleLabel = uiLayer.childNode(withName: "//Discard_Title") as? SKLabelNode {
            if numSelected == halfOfCards {
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textGreenColor]
                titleLabel.attributedText = NSAttributedString(string: "Discard Cards (\(numSelected)/\(halfOfCards))", attributes: attributes)
            } else {
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textRedColor]
                titleLabel.attributedText = NSAttributedString(string: "Discard Cards (\(numSelected)/\(halfOfCards))", attributes: attributes)
            }
        }
    }
    
    
    // MARK: - Victory & Special Checks

    
    private func checkWinCondition() {
        // Update longest road status before checking victory
        gameState.updateLongestRoad()
        checkLongestRoad()

        
        for player in gameState.players {
            if player.victoryPoints >= victoryPointGoal {
                endGameWithWinner(playerID: player.id)
                print("Player \(player.id + 1) wins with \(player.victoryPoints) points!")
            }
        }
    }
    
    private func endGameWithWinner(playerID: Int) {
        gameState.currentPhase = .end
        
        // Create victory announcement
        let victoryNode = SKLabelNode(text: "Player \(playerID + 1) wins!")
        victoryNode.fontSize = 36
        victoryNode.fontColor = .white
        victoryNode.position = CGPoint(x: size.width/2, y: size.height/2)
        victoryNode.name = "victoryMessage"
        victoryNode.zPosition = 100
        addChild(victoryNode)
        
        // Disable further interaction
        // Remove all buttons
        self.children.filter { $0.name?.contains("Button") ?? false }.forEach { $0.removeFromParent() }
    }
    
    func checkLongestRoad() {
        // Find the maximum longest road among all players.
        let maxRoadLength = gameState.players.map { $0.longestRoadLength }.max() ?? 0
        
        // Get the current holder of the Longest Road, if any.
        let currentHolder = gameState.players.first { $0.hasLongestRoad }
        
        // If no one has a longest road of at least 5, remove the honor.
        if maxRoadLength < 5 {
            if let holder = currentHolder {
                holder.hasLongestRoad = false
                holder.victoryPoints -= 2
            }
            return
        }
        
        // Identify candidates with the maximum longest road length.
        let candidates = gameState.players.filter { $0.longestRoadLength == maxRoadLength }
        
        if candidates.count == 1 {
            // We have a unique candidate.
            let candidate = candidates.first!
            if currentHolder === candidate {
                // Candidate already has the honor.
            } else {
                // Remove the honor from the previous holder (if any) and update points.
                if let holder = currentHolder {
                    holder.hasLongestRoad = false
                    holder.victoryPoints -= 2
                }
                candidate.hasLongestRoad = true
                candidate.victoryPoints += 2
            }
        } else {
            // There's a tie.
            // If the current holder is among the tied candidates, they keep the honor.
            if let holder = currentHolder, candidates.contains(where: { $0 === holder }) {
                // No changes.
            } else {
                // Otherwise, remove the honor from any current holder.
                if let holder = currentHolder {
                    holder.hasLongestRoad = false
                    holder.victoryPoints -= 2
                }
            }
        }
    }

    func checkLargestArmy() {
        // Compute the maximum knights used among all players.
        let maxKnights = gameState.players.map { $0.knightsUsed }.max() ?? 0
        
        // Find the current holder of Largest Army, if any.
        let currentHolder = gameState.players.first { $0.hasLargestArmy }
        
        // If no one has used at least 3 knights, clear the honor.
        if maxKnights < 3 {
            if let holder = currentHolder {
                holder.hasLargestArmy = false
                holder.victoryPoints -= 2
            }
            return
        }
        
        // Get all players with knightsUsed equal to maxKnights.
        let candidates = gameState.players.filter { $0.knightsUsed == maxKnights }
        
        if candidates.count == 1 {
            // Unique candidate qualifies.
            let candidate = candidates.first!
            if currentHolder === candidate {
                // They already have the honor; nothing to change.
            } else {
                // Remove the honor from the previous holder, if any.
                if let holder = currentHolder {
                    holder.hasLargestArmy = false
                    holder.victoryPoints -= 2
                }
                // Award the honor to the candidate.
                candidate.hasLargestArmy = true
                candidate.victoryPoints += 2
            }
        } else {
            // There's a tie.
            // If the current holder is among the candidates, they keep it.
            if let holder = currentHolder, candidates.contains(where: { $0 === holder }) {
                // Do nothing; the honor stays with the current holder.
            } else {
                // No one qualifies.
                if let holder = currentHolder {
                    holder.hasLargestArmy = false
                    holder.victoryPoints -= 2
                }
            }
        }
    }
    
    
    // MARK: - Road Building Dev Card (Free Roads)


    func handleFreeRoadPlacement(at location: CGPoint) {
        // Find the closest edge point
        if let closestEdge = findClosestEdgePoint(to: location, maxDistance: 20) {
            let currentPlayerIndex = gameState.currentPlayerIndex
            let currentPlayer = gameState.players[currentPlayerIndex]
            
            // Check if the player can build here
            if !(freeRoadsRemaining == 0) {
                if closestEdge.canBuildRoad(for: currentPlayerIndex, isSetupPhase: gameState.currentPhase == .setup) {
                    // Create the road
                    let road = Building(type: .road, ownerId: currentPlayerIndex, position: closestEdge.position)
                    closestEdge.road = road
                    gameBoard.buildings.append(road)
                    
                    // Create visual representation
                    createRoadSprite(for: road)
                    
                    unhighlightAllPoints()
                    if freeRoadsRemaining == 1 {
                        roadBuildingModeActive = false
                        selectedBuildingType = nil
                        currentPlayer.developmentCards[.roadBuilding]! -= 1
                    }
                    
                    currentPlayer.roadsLeft -= 1
                    freeRoadsRemaining -= 1
                                        
                    updateRoadLengthsForPlayer(playerId: currentPlayerIndex)
                    gameState.updateLongestRoad()
                    checkLongestRoad()
                    checkWinCondition()
                    
                    // Update UI
                    updateResourceCards()
                    updatePlayerUISection()
                    
                    // Handle setup phase logic if needed
                    if gameState.currentPhase == .setup {
                        handleSetupPhaseNextStep()
                    }
                    
                    if freeRoadsRemaining == 1 {
                        highlightValidEdges()
                    }
                }
            }
        }
    }
    
    
    //MARK: Create UI Sections
    
    
    private func addBottomUISection() {
        // Adjustable variables for testing placement:
        let sectionHeight: CGFloat = 80.0      // Change this to adjust the strip's height.
        let bottomMargin: CGFloat = 20.0        // Change this to move the strip closer/farther from the bottom edge.
        
        let leftMargin: CGFloat = 0.0 // Margin from the left edge.
        let rightMargin: CGFloat = 0.0
        
        // The section should span the full width of the scene.
        let sectionWidth = size.width - leftMargin - rightMargin
        
        // Create a rounded rectangle path for the bottom UI section.
        let cornerRadius: CGFloat = 5.0  // Adjust this value to control the rounding.
        // Create a rectangle centered at (0,0) in the local coordinate system.
        let rect = CGRect(x: -sectionWidth/2, y: -sectionHeight/2, width: sectionWidth, height: sectionHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        
        let bgSection = SKShapeNode(path: path)
        bgSection.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        bgSection.fillColor = .white
        bgSection.strokeColor = .clear
        bgSection.zPosition = -5
        bgSection.name = "BottomUISection"
        
        // Compute the center position based on the margins.
        let centerX = -size.width/2 + leftMargin + sectionWidth/2
        let centerY = -size.height/2 + bottomMargin + sectionHeight/2
        bgSection.position = CGPoint(x: centerX, y: centerY)
        
        // Add the section to the uiLayer.
        uiLayer.addChild(bgSection)
    }
    
    func createPlayerUISection() {
        guard let view = self.view else {
            return
        }
        // Retrieve safe area insets from the view.
        let safeAreaInsets = view.safeAreaInsets

        // Convert safe area edges to scene coordinates.
        // In a scene with origin at center:
        let safeLeft = -size.width / 2 + safeAreaInsets.left
        let safeTop = size.height / 2 - safeAreaInsets.top

        // Define the section size.
        let sectionSize = CGSize(width: size.width / 2 - 5, height: 60)

        // Calculate the centers of each section.
        // The top edge of the sections will align with safeTop.
        // Player 1 (top left) center:
        let player1Center = CGPoint(x: safeLeft + sectionSize.width / 2,
                                    y: safeTop - sectionSize.height / 2)
        // Player 2 (top right) center:
        let player2Center = CGPoint(x: safeLeft + sectionSize.width / 2 + sectionSize.width + 10,
                                    y: safeTop - sectionSize.height / 2)
        // Player 3 (bottom left) center – directly below player 1:
        let player3Center = CGPoint(x: safeLeft + sectionSize.width / 2,
                                    y: safeTop - sectionSize.height / 2 - sectionSize.height - 10)
        // Player 4 (bottom right) center – directly below player 2:
        let player4Center = CGPoint(x: safeLeft + sectionSize.width / 2 + sectionSize.width + 10,
                                    y: safeTop - sectionSize.height / 2 - sectionSize.height - 10)

        // Create a rounded rectangle path for the background.
        let cornerRadius: CGFloat = 5.0
        let rect = CGRect(x: -sectionSize.width / 2, y: -sectionSize.height / 2, width: sectionSize.width, height: sectionSize.height)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath

        // Constant offset from the inner edge (closest to the center) for the player background.
        let bgOffset: CGFloat = 30.0
        // Variable to control the offset between cards.
        let cardOffset: CGFloat = 10.0
        // Variables to control the x and y offset for the badge labels on cards.
        let labelXOffset: CGFloat = -5.0  // Adjust as needed
        let labelYOffset: CGFloat = -7.0  // Adjust as needed
        // Variable for the ribbon vertical offset.
        let ribbonYOffset: CGFloat = -20.0   // Adjust as needed

        // Variables for largest army icon.
        let largestArmyIconSize = CGSize(width: 21, height: 21)
        let largestArmyIconYOffset: CGFloat = 5.0  // Adjust vertical offset

        // Variables for longest road icon.
        let longestRoadIconSize = CGSize(width: 30, height: 30)
        let longestRoadIconYOffset: CGFloat = 5.0  // Adjust vertical offset

        // Define fixed sizes.
        let playerBGSize = CGSize(width: 40, height: 40)
        let cardSize = CGSize(width: 28, height: 40)
        let badgeSize = CGSize(width: 15, height: 15)
        let ribbonSize = CGSize(width: 40, height: 17)

        // Helper function to create a section with:
        // - a player background sprite with an icon and a ribbon (with label),
        // - a resource card with badge and counter,
        // - a developer card with badge and counter,
        // - a largest army icon with counter label,
        // - and a longest road icon with counter label.
        func createSection(withCenter center: CGPoint, playerIndex: Int, isLeftSide: Bool) -> SKShapeNode {
            let section = SKShapeNode(path: path)
            section.fillTexture = SKTexture(imageNamed: "bg_section.svg")
            section.fillColor = .white
            section.strokeColor = .clear
            section.position = center
            section.name = "player\(playerIndex + 1)Section"

            // Get the player's asset color and bot status (assumes gameState.players is available)
            let player = gameState.players[playerIndex]
            let playerColor = player.assetColor.lowercased()
            let bgTextureName = "player_bg_\(playerColor).svg"
            let bgTexture = SKTexture(imageNamed: bgTextureName)

            // Create the player background sprite.
            let bgSprite = SKSpriteNode(texture: bgTexture)
            bgSprite.size = playerBGSize

            // Position the bgSprite relative to the section edge.
            if isLeftSide {
                bgSprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                bgSprite.position = CGPoint(x: sectionSize.width / 2 - bgOffset, y: 0)
            } else {
                bgSprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                bgSprite.position = CGPoint(x: -sectionSize.width / 2 + bgOffset, y: 0)
            }

            // Add the icon to the bgSprite.
            let iconTextureName = player.isBot ? "icon_bot.svg" : "icon_player.svg"
            let iconTexture = SKTexture(imageNamed: iconTextureName)
            let iconSprite = SKSpriteNode(texture: iconTexture)
            iconSprite.size = CGSize(width: 25, height: 25)
            iconSprite.position = .zero
            iconSprite.zPosition = 1
            bgSprite.addChild(iconSprite)
            
            // Add a ribbon on top of the player background.
            // Use ribbon_long.svg for player 1; otherwise, use ribbon_small.svg.
            let ribbonImageName = "ribbon_small.svg"
            let ribbonTexture = SKTexture(imageNamed: ribbonImageName)
            let ribbonSprite = SKSpriteNode(texture: ribbonTexture)
            ribbonSprite.size = ribbonSize
            ribbonSprite.zPosition = 2
            // Position the ribbon at the top of bgSprite with the specified y offset.
            ribbonSprite.position = CGPoint(x: 0, y: ribbonYOffset)
            bgSprite.addChild(ribbonSprite)
            
            // Add a label on the ribbon.
            let ribbonLabel = SKLabelNode(text: "0")
            ribbonLabel.fontName = "Helvetica"
            ribbonLabel.fontSize = 10
            ribbonLabel.fontColor = textBlackColor
            ribbonLabel.verticalAlignmentMode = .center
            ribbonLabel.horizontalAlignmentMode = .center
            ribbonLabel.zPosition = 3
            ribbonLabel.position = CGPoint(x: 0, y: 0)
            ribbonLabel.name = "ribbonLabel_player\(playerIndex)"
            ribbonSprite.addChild(ribbonLabel)

            section.addChild(bgSprite)

            // Create the resource card sprite.
            let resCardTexture = SKTexture(imageNamed: "card_rescardback.svg")
            let resCardSprite = SKSpriteNode(texture: resCardTexture)
            resCardSprite.size = cardSize

            if isLeftSide {
                let bgLeftEdge = bgSprite.position.x - (playerBGSize.width / 2)
                let cardX = bgLeftEdge - cardOffset - (cardSize.width / 2)
                resCardSprite.position = CGPoint(x: cardX, y: 0)
            } else {
                let bgRightEdge = bgSprite.position.x + (playerBGSize.width / 2)
                let cardX = bgRightEdge + cardOffset + (cardSize.width / 2)
                resCardSprite.position = CGPoint(x: cardX, y: 0)
            }
            resCardSprite.name = "resCard_player\(playerIndex)"
            section.addChild(resCardSprite)

            // Add a badge on the resource card.
            let resBadgeTexture = SKTexture(imageNamed: "card_badge_background")
            let resBadgeSprite = SKSpriteNode(texture: resBadgeTexture)
            resBadgeSprite.size = badgeSize
            resBadgeSprite.anchorPoint = CGPoint(x: 1, y: 1)
            resBadgeSprite.position = CGPoint(x: cardSize.width / 2, y: cardSize.height / 2)
            resBadgeSprite.zPosition = 1
            resCardSprite.addChild(resBadgeSprite)

            let resBadgeLabel = SKLabelNode(text: "0")
            resBadgeLabel.fontName = "Helvetica-Bold"
            resBadgeLabel.fontSize = 10
            resBadgeLabel.fontColor = .white
            resBadgeLabel.verticalAlignmentMode = .center
            resBadgeLabel.horizontalAlignmentMode = .center
            resBadgeLabel.zPosition = 2
            resBadgeLabel.position = CGPoint(x: labelXOffset, y: labelYOffset)
            resBadgeLabel.name = "resBadgeLabel_player\(playerIndex)"
            resBadgeSprite.addChild(resBadgeLabel)

            // Create the developer card sprite.
            let devCardTexture = SKTexture(imageNamed: "card_devcardback.svg")
            let devCardSprite = SKSpriteNode(texture: devCardTexture)
            devCardSprite.size = cardSize

            if isLeftSide {
                let resCardLeftEdge = resCardSprite.position.x - (cardSize.width / 2)
                let devCardX = resCardLeftEdge - cardOffset - (cardSize.width / 2)
                devCardSprite.position = CGPoint(x: devCardX, y: 0)
            } else {
                let resCardRightEdge = resCardSprite.position.x + (cardSize.width / 2)
                let devCardX = resCardRightEdge + cardOffset + (cardSize.width / 2)
                devCardSprite.position = CGPoint(x: devCardX, y: 0)
            }
            section.addChild(devCardSprite)

            // Add a badge on the developer card.
            let devBadgeTexture = SKTexture(imageNamed: "card_badge_background")
            let devBadgeSprite = SKSpriteNode(texture: devBadgeTexture)
            devBadgeSprite.size = badgeSize
            devBadgeSprite.anchorPoint = CGPoint(x: 1, y: 1)
            devBadgeSprite.position = CGPoint(x: cardSize.width / 2, y: cardSize.height / 2)
            devBadgeSprite.zPosition = 1
            devCardSprite.addChild(devBadgeSprite)

            let devBadgeLabel = SKLabelNode(text: "0")
            devBadgeLabel.fontName = "Helvetica-Bold"
            devBadgeLabel.fontSize = 10
            devBadgeLabel.fontColor = .white
            devBadgeLabel.verticalAlignmentMode = .center
            devBadgeLabel.horizontalAlignmentMode = .center
            devBadgeLabel.zPosition = 2
            devBadgeLabel.position = CGPoint(x: labelXOffset, y: labelYOffset)
            devBadgeLabel.name = "devBadgeLabel_player\(playerIndex)"
            devBadgeSprite.addChild(devBadgeLabel)

            // Create the largest army icon.
            let armyIconTexture = SKTexture(imageNamed: "icon_largest_army.svg")
            let armyIconSprite = SKSpriteNode(texture: armyIconTexture)
            armyIconSprite.size = largestArmyIconSize

            if isLeftSide {
                let devCardLeftEdge = devCardSprite.position.x - (cardSize.width / 2)
                let armyIconX = devCardLeftEdge - cardOffset - (largestArmyIconSize.width / 2)
                armyIconSprite.position = CGPoint(x: armyIconX, y: largestArmyIconYOffset)
            } else {
                let devCardRightEdge = devCardSprite.position.x + (cardSize.width / 2)
                let armyIconX = devCardRightEdge + cardOffset + (largestArmyIconSize.width / 2)
                armyIconSprite.position = CGPoint(x: armyIconX, y: largestArmyIconYOffset)
            }
            armyIconSprite.name = "armyIcon_player\(playerIndex)"
            section.addChild(armyIconSprite)

            // Add a label under the largest army icon.
            let armyBadgeLabel = SKLabelNode(text: "0")
            armyBadgeLabel.fontName = "Helvetica"
            armyBadgeLabel.fontSize = 15
            armyBadgeLabel.fontColor = .black
            armyBadgeLabel.verticalAlignmentMode = .center
            armyBadgeLabel.horizontalAlignmentMode = .center
            armyBadgeLabel.zPosition = 2
            armyBadgeLabel.position = CGPoint(x: 0, y: -(largestArmyIconSize.height / 2 + abs(largestArmyIconYOffset)) - 5)
            armyBadgeLabel.name = "armyBadgeLabel_player\(playerIndex)"
            armyIconSprite.addChild(armyBadgeLabel)

            // Create the longest road icon.
            let roadIconTexture = SKTexture(imageNamed: "icon_longest_road.svg")
            let roadIconSprite = SKSpriteNode(texture: roadIconTexture)
            roadIconSprite.size = longestRoadIconSize

            if isLeftSide {
                let armyLeftEdge = armyIconSprite.position.x - (largestArmyIconSize.width / 2)
                let roadIconX = armyLeftEdge - cardOffset - (longestRoadIconSize.width / 2)
                roadIconSprite.position = CGPoint(x: roadIconX, y: longestRoadIconYOffset)
            } else {
                let armyRightEdge = armyIconSprite.position.x + (largestArmyIconSize.width / 2)
                let roadIconX = armyRightEdge + cardOffset + (longestRoadIconSize.width / 2)
                roadIconSprite.position = CGPoint(x: roadIconX, y: longestRoadIconYOffset)
            }
            roadIconSprite.name = "roadIcon_player\(playerIndex)"
            section.addChild(roadIconSprite)

            // Add a label under the longest road icon.
            let roadBadgeLabel = SKLabelNode(text: "0")
            roadBadgeLabel.fontName = "Helvetica"
            roadBadgeLabel.fontSize = 15
            roadBadgeLabel.fontColor = .black
            roadBadgeLabel.verticalAlignmentMode = .center
            roadBadgeLabel.horizontalAlignmentMode = .center
            roadBadgeLabel.zPosition = 2
            roadBadgeLabel.position = CGPoint(x: 0, y: -(longestRoadIconSize.height / 2 + abs(longestRoadIconYOffset)) - 0.5)
            roadBadgeLabel.name = "roadBadgeLabel_player\(playerIndex)"
            roadIconSprite.addChild(roadBadgeLabel)

            return section
        }

        // Create and add each player's section.
        let player1Section = createSection(withCenter: player1Center, playerIndex: 0, isLeftSide: true)
        uiLayer.addChild(player1Section)

        let player3Section = createSection(withCenter: player3Center, playerIndex: 2, isLeftSide: true)
        uiLayer.addChild(player3Section)

        let player2Section = createSection(withCenter: player2Center, playerIndex: 1, isLeftSide: false)
        uiLayer.addChild(player2Section)

        let player4Section = createSection(withCenter: player4Center, playerIndex: 3, isLeftSide: false)
        uiLayer.addChild(player4Section)
    }
    
    private func createDiscardCardsUISection() {
        // Create a container for the entire knight UI.
        let container = SKNode()
        container.name = "DiscardCards_UI_Container"
        
        // Define dimensions for the knight UI section.
        let sectionHeight: CGFloat = 215.0
        let leftMargin: CGFloat = 5.0   // Margin from the left edge.
        let rightMargin: CGFloat = 85.0 // Margin from the right edge.
        let bottomMargin: CGFloat = 103.0 // Margin from the bottom edge.
        
        let sectionWidth = size.width - leftMargin - rightMargin
        let centerX = (-size.width / 2 + leftMargin + size.width / 2 - rightMargin) / 2
        
        // Create a rounded rectangle path for the background.
        let cornerRadius: CGFloat = 5.0
        let rect = CGRect(x: -sectionWidth / 2, y: -sectionHeight / 2, width: sectionWidth, height: sectionHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        
        // Create the background shape node.
        let section = SKShapeNode(path: path)
        section.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        section.fillColor = .white
        section.strokeColor = .clear
        section.zPosition = 500
        section.name = "DiscardCards_MainSection"
        
        let centerY = -size.height / 2 + sectionHeight / 2 + bottomMargin
        section.position = CGPoint(x: centerX, y: centerY)
        container.addChild(section)
        
        
        // Define dimensions for the knight UI section.
        let middleSectionHeight: CGFloat = 68.0
        let middleBottomMargin: CGFloat = 160.0 // Margin from the bottom edge.
        
        // Create a rounded rectangle path for the background.
        let middleRect = CGRect(x: -sectionWidth / 2, y: -middleSectionHeight / 2, width: sectionWidth, height: middleSectionHeight)
        let middlePath = UIBezierPath(roundedRect: middleRect, cornerRadius: cornerRadius).cgPath
        
        // Create the background shape node.
        let middleSection = SKShapeNode(path: middlePath)
        middleSection.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        middleSection.fillColor = .white
        middleSection.strokeColor = .clear
        middleSection.zPosition = 501
        middleSection.name = "Middle_DiscardCards_UI_Container"
        
        let middleCenterY = -size.height / 2 + middleSectionHeight / 2 + middleBottomMargin
        middleSection.position = CGPoint(x: centerX, y: middleCenterY)
        container.addChild(middleSection)
        
        // Add the top left res card icon
        let topLeftMarginX: CGFloat = 10.0
        let topLeftMarginY: CGFloat = 5.0
        let cardSize = CGSize(width: 45.5, height: 80)
        let cardTexture = SKTexture(imageNamed: "icon_discard_resource_cards.svg")
        let cardNode = SKSpriteNode(texture: cardTexture)
        cardNode.size = cardSize
        cardNode.position = CGPoint(
            x: -sectionWidth/2 + topLeftMarginX + cardSize.width/2,
            y: sectionHeight/2 - topLeftMarginY - cardSize.height/2
        )
        cardNode.zPosition = section.zPosition + 1
        section.addChild(cardNode)
        
        
        // Add text to the right of the res card ---
        // Calculate the starting x position (to the right of the development card) and a base y position.
        let textStartX = cardNode.position.x + cardSize.width/2 + 10
        let resourceCount = gameState.players[0].resources.values.reduce(0, +)
        halfOfCards = resourceCount / 2
        let titleLabel = SKLabelNode()
        let font = UIFont.systemFont(ofSize: 20, weight: .bold - 0.1)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textRedColor]
        titleLabel.attributedText = NSAttributedString(string: "Discard Cards (0/\(halfOfCards))", attributes: attributes)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        // Align the title label near the top of the knight card.
        titleLabel.position = CGPoint(x: textStartX, y: cardNode.position.y + cardSize.height/2 - 18)
        titleLabel.name = "Discard_Title"
        section.addChild(titleLabel)
        
        // Add the description labels below the title.
        let descriptionTexts = [
            "7 was rolled! You have more than 7 cards.",
            "You need to discard \(halfOfCards) of them."
        ]
        
        let lineSpacing: CGFloat = 15
        
        for (index, text) in descriptionTexts.enumerated() {
            let descriptionLabel = SKLabelNode(fontNamed: "Helvetica")
            descriptionLabel.text = text
            descriptionLabel.fontSize = 14  // A little smaller than the title.
            descriptionLabel.fontColor = textBlackColor
            descriptionLabel.horizontalAlignmentMode = .left
            descriptionLabel.verticalAlignmentMode = .center
            
            let baseY = titleLabel.position.y - titleLabel.fontSize + 9
            let offset = CGFloat(index) * lineSpacing
            let newY = baseY - offset
            descriptionLabel.position = CGPoint(x: textStartX, y: newY)
            descriptionLabel.name = "line_\(index)"
            
            section.addChild(descriptionLabel)
        }
        
        
        //Buttons
        let useButtonSize = CGSize(width: 35, height: 35)
        let useButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        useButton.size = useButtonSize
        useButton.name = "DiscardCardsButton"
        let button1Margin: CGFloat = 5.0
        
        useButton.position = CGPoint(
            x: sectionWidth/2 - useButtonSize.width/2 - button1Margin,
            y: -sectionHeight/2 + useButtonSize.height/2 + button1Margin
        )
        useButton.zPosition = section.zPosition + 1
        
        section.addChild(useButton)
        
        let checkIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_check.svg"))
        checkIcon.size = CGSize(width: 23, height: 23)
        checkIcon.position = CGPoint.zero
        checkIcon.zPosition = 502
        checkIcon.name = "CheckIcon"
        useButton.addChild(checkIcon)
        
        // Finally, add the entire container to the UI layer.
        uiLayer.addChild(container)
        
        gameState.currentPhase = .discardCards
    }
    
    private func createKnightUISection() {
        // Create a container for the entire knight UI.
        let container = SKNode()
        container.name = "Knight_UI_Container"
        
        // Define dimensions for the knight UI section.
        let sectionHeight: CGFloat = 120.0
        let leftMargin: CGFloat = 5.0   // Margin from the left edge.
        let rightMargin: CGFloat = 85.0 // Margin from the right edge.
        let bottomMargin: CGFloat = 103.0 // Margin from the bottom edge.
        
        let sectionWidth = size.width - leftMargin - rightMargin
        let centerX = (-size.width / 2 + leftMargin + size.width / 2 - rightMargin) / 2
        
        // Create a rounded rectangle path for the background.
        let cornerRadius: CGFloat = 5.0
        let rect = CGRect(x: -sectionWidth / 2, y: -sectionHeight / 2, width: sectionWidth, height: sectionHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        
        // Create the background shape node.
        let section = SKShapeNode(path: path)
        section.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        section.fillColor = .white
        section.strokeColor = .clear
        section.zPosition = 500
        section.name = "Knight_UI_Container"
        
        let centerY = -size.height / 2 + sectionHeight / 2 + bottomMargin
        section.position = CGPoint(x: centerX, y: centerY)
        container.addChild(section)
        
        // Existing element: Add the top left icon (e.g., the knight card).
        let topLeftMarginX: CGFloat = 10.0
        let topLeftMarginY: CGFloat = 13.0
        let knightCardSize = CGSize(width: 56, height: 80)
        let knightCardTexture = SKTexture(imageNamed: "card_knight.svg")
        let knightCardNode = SKSpriteNode(texture: knightCardTexture)
        knightCardNode.size = knightCardSize
        knightCardNode.position = CGPoint(
            x: -sectionWidth/2 + topLeftMarginX + knightCardSize.width/2,
            y: sectionHeight/2 - topLeftMarginY - knightCardSize.height/2
        )
        knightCardNode.zPosition = section.zPosition + 1
        section.addChild(knightCardNode)
        
        // Add text to the right of the knight card ---
        // Calculate the starting x position (to the right of the knight card) and a base y position.
        let textStartX = knightCardNode.position.x + knightCardSize.width/2 + 10
        // Position the title label near the top of the knight card.
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = "Knight"
        titleLabel.fontSize = 20  // Slightly bigger font for emphasis.
        let textColor = UIColor(red: 50/255.0, green: 50/255.0, blue: 50/255.0, alpha: 1.0)
        titleLabel.fontColor = textColor
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        // Align the title label near the top of the knight card.
        titleLabel.position = CGPoint(x: textStartX, y: knightCardNode.position.y + knightCardSize.height/2 - 10)
        section.addChild(titleLabel)
        
        // Add the description labels below the title.
        let descriptionTexts = [
            "Place the Robber anywhere on the",
            "board and steal a random",
            "card from a player with a",
            "settlement or city on that tile."
        ]
        
        var lineSpacing: CGFloat = 0

        for (index, text) in descriptionTexts.enumerated() {
            let descriptionLabel = SKLabelNode(fontNamed: "Helvetica")
            descriptionLabel.text = text
            descriptionLabel.fontSize = 14  // A little smaller than the title.
            descriptionLabel.fontColor = textColor
            descriptionLabel.horizontalAlignmentMode = .left
            descriptionLabel.verticalAlignmentMode = .center
            // Position each label below the title, offset by its line height plus additional spacing.
            if (index == 0 ) {
                lineSpacing = 14
            } else if index == 1 {
                lineSpacing = 13
            } else if index == 2 {
                lineSpacing = 15
            } else if index == 3 {
                lineSpacing = 15
            }
           
            // Break the position calculation into smaller sub-expressions.
            let baseY = titleLabel.position.y - titleLabel.fontSize - 5
            let offset = CGFloat(index) * lineSpacing
            let newY = baseY - offset
            descriptionLabel.position = CGPoint(x: textStartX, y: newY)
            
            section.addChild(descriptionLabel)
        }

        
        //Buttons
        let useKnightButtonSize = CGSize(width: 35, height: 35)
        let useKnightButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        useKnightButton.size = useKnightButtonSize
        useKnightButton.name = "UseKnightButton"
        let button1Margin: CGFloat = 5.0
        
        useKnightButton.position = CGPoint(
            x: sectionWidth/2 - useKnightButtonSize.width/2 - button1Margin,
            y: -sectionHeight/2 + useKnightButtonSize.height/2 + button1Margin
        )
        useKnightButton.zPosition = section.zPosition + 1
        
        section.addChild(useKnightButton)
        
        let checkIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_check.svg"))
        checkIcon.size = CGSize(width: 23, height: 23)
        checkIcon.position = CGPoint.zero
        checkIcon.zPosition = 502
        checkIcon.name = "CheckIcon"
        useKnightButton.addChild(checkIcon)
        
        //Cancel Button
        let cancelKnightButtonSize = CGSize(width: 35, height: 35)
        let cancelKnightButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        cancelKnightButton.size = cancelKnightButtonSize
        cancelKnightButton.name = "CancelKnightButton"
        let button2Margin: CGFloat = 45.0
        
        cancelKnightButton.position = CGPoint(
            x: sectionWidth/2 - cancelKnightButtonSize.width/2 - button2Margin,
            y: -sectionHeight/2 + cancelKnightButtonSize.height/2 + button1Margin
        )
        cancelKnightButton.zPosition = section.zPosition + 1
        
        section.addChild(cancelKnightButton)
        
        let xIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_x.svg"))
        xIcon.size = CGSize(width: 23, height: 23)
        xIcon.position = CGPoint.zero
        xIcon.zPosition = 502
        xIcon.name = "XIcon"
        cancelKnightButton.addChild(xIcon)
        
        // Finally, add the entire container to the UI layer.
        uiLayer.addChild(container)
    }
    
    private func createRoadBuildingUISection() {
        // Create a container for the entire knight UI.
        let container = SKNode()
        container.name = "Road_Building_UI_Container"
        
        // Define dimensions for the knight UI section.
        let sectionHeight: CGFloat = 105.0
        let leftMargin: CGFloat = 5.0   // Margin from the left edge.
        let rightMargin: CGFloat = 85.0 // Margin from the right edge.
        let bottomMargin: CGFloat = 103.0 // Margin from the bottom edge.
        
        let sectionWidth = size.width - leftMargin - rightMargin
        let centerX = (-size.width / 2 + leftMargin + size.width / 2 - rightMargin) / 2
        
        // Create a rounded rectangle path for the background.
        let cornerRadius: CGFloat = 5.0
        let rect = CGRect(x: -sectionWidth / 2, y: -sectionHeight / 2, width: sectionWidth, height: sectionHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        
        // Create the background shape node.
        let section = SKShapeNode(path: path)
        section.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        section.fillColor = .white
        section.strokeColor = .clear
        section.zPosition = 500
        section.name = "RoadBuilding_UI_Container"
        
        let centerY = -size.height / 2 + sectionHeight / 2 + bottomMargin
        section.position = CGPoint(x: centerX, y: centerY)
        container.addChild(section)
        
        // Existing element: Add the top left icon (e.g., the knight card).
        let topLeftMarginX: CGFloat = 10.0
        let topLeftMarginY: CGFloat = 12.5
        let cardSize = CGSize(width: 56, height: 80)
        let cardTexture = SKTexture(imageNamed: "card_roadbuilding.svg")
        let cardNode = SKSpriteNode(texture: cardTexture)
        cardNode.size = cardSize
        cardNode.position = CGPoint(
            x: -sectionWidth/2 + topLeftMarginX + cardSize.width/2,
            y: sectionHeight/2 - topLeftMarginY - cardSize.height/2
        )
        cardNode.zPosition = section.zPosition + 1
        section.addChild(cardNode)
        
        // Add text to the right of the knight card ---
        // Calculate the starting x position (to the right of the knight card) and a base y position.
        let textStartX = cardNode.position.x + cardSize.width/2 + 10
        // Position the title label near the top of the knight card.
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = "Road Building"
        titleLabel.fontSize = 20  // Slightly bigger font for emphasis.
        let textColor = UIColor(red: 50/255.0, green: 50/255.0, blue: 50/255.0, alpha: 1.0)
        titleLabel.fontColor = textColor
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        // Align the title label near the top of the knight card.
        titleLabel.position = CGPoint(x: textStartX, y: cardNode.position.y + cardSize.height/2 - 15)
        section.addChild(titleLabel)
        
        let descriptionLabel = SKLabelNode(fontNamed: "Helvetica")
        descriptionLabel.text = "Place 2 free roads."
        descriptionLabel.fontSize = 14  // A little smaller than the title.
        descriptionLabel.fontColor = textColor
        descriptionLabel.horizontalAlignmentMode = .left
        descriptionLabel.verticalAlignmentMode = .center
        // Position each label below the title, offset by its line height plus additional spacing.
       
        // Break the position calculation into smaller sub-expressions.
        let baseY = titleLabel.position.y - titleLabel.fontSize
        descriptionLabel.position = CGPoint(x: textStartX, y: baseY)
        
        section.addChild(descriptionLabel)

        
        //Buttons
        let useButtonSize = CGSize(width: 35, height: 35)
        let useButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        useButton.size = useButtonSize
        useButton.name = "UseRoadBuildingButton"
        let button1Margin: CGFloat = 5.0
        
        useButton.position = CGPoint(
            x: sectionWidth/2 - useButtonSize.width/2 - button1Margin,
            y: -sectionHeight/2 + useButtonSize.height/2 + button1Margin
        )
        useButton.zPosition = section.zPosition + 1
        
        section.addChild(useButton)
        
        let checkIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_check.svg"))
        checkIcon.size = CGSize(width: 23, height: 23)
        checkIcon.position = CGPoint.zero
        checkIcon.zPosition = 502
        checkIcon.name = "CheckIcon"
        useButton.addChild(checkIcon)
        
        //Cancel Button
        let cancelButtonSize = CGSize(width: 35, height: 35)
        let cancelButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        cancelButton.size = cancelButtonSize
        cancelButton.name = "CancelRoadBuildingButton"
        let button2Margin: CGFloat = 45.0
        
        cancelButton.position = CGPoint(
            x: sectionWidth/2 - cancelButtonSize.width/2 - button2Margin,
            y: -sectionHeight/2 + cancelButtonSize.height/2 + button1Margin
        )
        cancelButton.zPosition = section.zPosition + 1
        
        section.addChild(cancelButton)
        
        let xIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_x.svg"))
        xIcon.size = CGSize(width: 23, height: 23)
        xIcon.position = CGPoint.zero
        xIcon.zPosition = 502
        xIcon.name = "XIcon"
        cancelButton.addChild(xIcon)
        
        // Finally, add the entire container to the UI layer.
        uiLayer.addChild(container)
    }
    
    private func createVictoryPointUISection() {
        // Create a container for the entire knight UI.
        let container = SKNode()
        container.name = "VictoryPoint_UI_Container"
        
        // Define dimensions for the knight UI section.
        let sectionHeight: CGFloat = 105.0
        let leftMargin: CGFloat = 5.0   // Margin from the left edge.
        let rightMargin: CGFloat = 85.0 // Margin from the right edge.
        let bottomMargin: CGFloat = 103.0 // Margin from the bottom edge.
        
        let sectionWidth = size.width - leftMargin - rightMargin
        let centerX = (-size.width / 2 + leftMargin + size.width / 2 - rightMargin) / 2
        
        // Create a rounded rectangle path for the background.
        let cornerRadius: CGFloat = 5.0
        let rect = CGRect(x: -sectionWidth / 2, y: -sectionHeight / 2, width: sectionWidth, height: sectionHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        
        // Create the background shape node.
        let section = SKShapeNode(path: path)
        section.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        section.fillColor = .white
        section.strokeColor = .clear
        section.zPosition = 500
        section.name = "VictoryPoint_UI_Container"
        
        let centerY = -size.height / 2 + sectionHeight / 2 + bottomMargin
        section.position = CGPoint(x: centerX, y: centerY)
        container.addChild(section)
        
        // Existing element: Add the top left icon (e.g., the knight card).
        let topLeftMarginX: CGFloat = 10.0
        let topLeftMarginY: CGFloat = 12.5
        let cardSize = CGSize(width: 56, height: 80)
        let cardTexture = SKTexture(imageNamed: "card_vp.svg")
        let cardNode = SKSpriteNode(texture: cardTexture)
        cardNode.size = cardSize
        cardNode.position = CGPoint(
            x: -sectionWidth/2 + topLeftMarginX + cardSize.width/2,
            y: sectionHeight/2 - topLeftMarginY - cardSize.height/2
        )
        cardNode.zPosition = section.zPosition + 1
        section.addChild(cardNode)
        
        // Add text to the right of the knight card ---
        // Calculate the starting x position (to the right of the knight card) and a base y position.
        let textStartX = cardNode.position.x + cardSize.width/2 + 10
        // Position the title label near the top of the knight card.
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = "Point"
        titleLabel.fontSize = 20  // Slightly bigger font for emphasis.
        let textColor = UIColor(red: 50/255.0, green: 50/255.0, blue: 50/255.0, alpha: 1.0)
        titleLabel.fontColor = textColor
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        // Align the title label near the top of the knight card.
        titleLabel.position = CGPoint(x: textStartX, y: cardNode.position.y + cardSize.height/2 - 15)
        section.addChild(titleLabel)
        
        // Add the description labels below the title.
        let descriptionTexts = [
            "Secretly awards 1 point; it is",
            "automatically used."
        ]
        
        var lineSpacing: CGFloat = 0

        for (index, text) in descriptionTexts.enumerated() {
            let descriptionLabel = SKLabelNode(fontNamed: "Helvetica")
            descriptionLabel.text = text
            descriptionLabel.fontSize = 14  // A little smaller than the title.
            descriptionLabel.fontColor = textColor
            descriptionLabel.horizontalAlignmentMode = .left
            descriptionLabel.verticalAlignmentMode = .center
            // Position each label below the title, offset by its line height plus additional spacing.
            if (index == 0 ) {
                lineSpacing = 14
            } else if index == 1 {
                lineSpacing = 15
            }
           
            // Break the position calculation into smaller sub-expressions.
            let baseY = titleLabel.position.y - titleLabel.fontSize - 5
            let offset = CGFloat(index) * lineSpacing
            let newY = baseY - offset
            descriptionLabel.position = CGPoint(x: textStartX, y: newY)
            
            section.addChild(descriptionLabel)
        }
        
        //Buttons
        let useButtonSize = CGSize(width: 35, height: 35)
        let useButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        useButton.size = useButtonSize
        useButton.name = "UseVictoryPointButton"
        let button1Margin: CGFloat = 5.0
        
        useButton.position = CGPoint(
            x: sectionWidth/2 - useButtonSize.width/2 - button1Margin,
            y: -sectionHeight/2 + useButtonSize.height/2 + button1Margin
        )
        useButton.zPosition = section.zPosition + 1
        
        section.addChild(useButton)
        
        let checkIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_check.svg"))
        checkIcon.size = CGSize(width: 23, height: 23)
        checkIcon.position = CGPoint.zero
        checkIcon.zPosition = 502
        checkIcon.name = "CheckIcon"
        useButton.addChild(checkIcon)
      
        // Finally, add the entire container to the UI layer.
        uiLayer.addChild(container)
    }
    
    private func createMonopolyUISection() {
        // Create a container for the entire knight UI.
        let container = SKNode()
        container.name = "Monopoly_UI_Container"
        
        // Define dimensions for the knight UI section.
        let sectionHeight: CGFloat = 215.0
        let leftMargin: CGFloat = 5.0   // Margin from the left edge.
        let rightMargin: CGFloat = 85.0 // Margin from the right edge.
        let bottomMargin: CGFloat = 103.0 // Margin from the bottom edge.
        
        let sectionWidth = size.width - leftMargin - rightMargin
        let centerX = (-size.width / 2 + leftMargin + size.width / 2 - rightMargin) / 2
        
        // Create a rounded rectangle path for the background.
        let cornerRadius: CGFloat = 5.0
        let rect = CGRect(x: -sectionWidth / 2, y: -sectionHeight / 2, width: sectionWidth, height: sectionHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        
        // Create the background shape node.
        let section = SKShapeNode(path: path)
        section.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        section.fillColor = .white
        section.strokeColor = .clear
        section.zPosition = 500
        section.name = "Monopoly_MainSection"

        let centerY = -size.height / 2 + sectionHeight / 2 + bottomMargin
        section.position = CGPoint(x: centerX, y: centerY)
        container.addChild(section)
        
        
        // Define dimensions for the knight UI section.
        let middleSectionHeight: CGFloat = 48.0
        let middleBottomMargin: CGFloat = 165.0 // Margin from the bottom edge.
        
        // Create a rounded rectangle path for the background.
        let middleRect = CGRect(x: -sectionWidth / 2, y: -middleSectionHeight / 2, width: sectionWidth, height: middleSectionHeight)
        let middlePath = UIBezierPath(roundedRect: middleRect, cornerRadius: cornerRadius).cgPath
        
        // Create the background shape node.
        let middleSection = SKShapeNode(path: middlePath)
        middleSection.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        middleSection.fillColor = .white
        middleSection.strokeColor = .clear
        middleSection.zPosition = 501
        middleSection.name = "Middle_Monopoly_UI_Container"
        
        let middleCenterY = -size.height / 2 + middleSectionHeight / 2 + middleBottomMargin
        middleSection.position = CGPoint(x: centerX, y: middleCenterY)
        container.addChild(middleSection)
        
        // Add the top left development card icon
        let topLeftMarginX: CGFloat = 10.0
        let topLeftMarginY: CGFloat = 12.5
        let cardSize = CGSize(width: 56, height: 80)
        let cardTexture = SKTexture(imageNamed: "card_monopoly.svg")
        let cardNode = SKSpriteNode(texture: cardTexture)
        cardNode.size = cardSize
        cardNode.position = CGPoint(
            x: -sectionWidth/2 + topLeftMarginX + cardSize.width/2,
            y: sectionHeight/2 - topLeftMarginY - cardSize.height/2
        )
        cardNode.zPosition = section.zPosition + 1
        section.addChild(cardNode)
        
        
        // Add all resource cards (wood, brick, sheep, wheat, ore)
        let marginY: CGFloat = 5.0
        let resourcesCardSize = CGSize(width: 27, height: 38)
        let resourcesSpacing: CGFloat = 1.0  // Adjust spacing between cards as needed
        let resources: [ResourceType] = [.wood, .brick, .sheep, .wheat, .ore]

        for (index, resource) in resources.enumerated() {
            var textureName: String
            switch resource {
            case .wood:
                textureName = "card_lumber.svg"
            case .brick:
                textureName = "card_brick.svg"
            case .sheep:
                textureName = "card_wool.svg"
            case .wheat:
                textureName = "card_grain.svg"
            case .ore:
                textureName = "card_ore.svg"
            default:
                continue
            }
            
            let resourceTexture = SKTexture(imageNamed: textureName)
            let resourceCardNode = SKSpriteNode(texture: resourceTexture)
            resourceCardNode.size = resourcesCardSize
            
            // Set a unique name so we can detect taps (e.g., "monopolyResource_Wood")
            resourceCardNode.name = "monopolyResource_\(resource.rawValue)"
            
            // Calculate the x position so that the cards are laid out side-by-side
            let xPosition = (-sectionWidth / 2 + topLeftMarginX + resourcesCardSize.width / 2) + CGFloat(index) * (resourcesCardSize.width + resourcesSpacing)
            let yPosition = middleSectionHeight / 2 - marginY - resourcesCardSize.height / 2
            resourceCardNode.position = CGPoint(x: xPosition, y: yPosition)
            resourceCardNode.zPosition = middleSection.zPosition + 1
            
            middleSection.addChild(resourceCardNode)
        }

        
        // Add text to the right of the development card ---
        // Calculate the starting x position (to the right of the development card) and a base y position.
        let textStartX = cardNode.position.x + cardSize.width/2 + 10
        // Position the title label near the top of the knight card.
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = "Monopoly"
        titleLabel.fontSize = 20  // Slightly bigger font for emphasis.
        let textColor = UIColor(red: 50/255.0, green: 50/255.0, blue: 50/255.0, alpha: 1.0)
        titleLabel.fontColor = textColor
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        // Align the title label near the top of the knight card.
        titleLabel.position = CGPoint(x: textStartX, y: cardNode.position.y + cardSize.height/2 - 15)
        section.addChild(titleLabel)
        
        // Add the description labels below the title.
        let descriptionTexts = [
            "Steal all cards of a single type",
            "of resource from every player."
        ]
        
        let lineSpacing: CGFloat = 15

        for (index, text) in descriptionTexts.enumerated() {
            let descriptionLabel = SKLabelNode(fontNamed: "Helvetica")
            descriptionLabel.text = text
            descriptionLabel.fontSize = 14  // A little smaller than the title.
            descriptionLabel.fontColor = textColor
            descriptionLabel.horizontalAlignmentMode = .left
            descriptionLabel.verticalAlignmentMode = .center
      
            let baseY = titleLabel.position.y - titleLabel.fontSize - 5
            let offset = CGFloat(index) * lineSpacing
            let newY = baseY - offset
            descriptionLabel.position = CGPoint(x: textStartX, y: newY)
            
            section.addChild(descriptionLabel)
        }

        
        //Buttons
        let useButtonSize = CGSize(width: 35, height: 35)
        let useButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        useButton.size = useButtonSize
        useButton.name = "UseMonopolyButton"
        let button1Margin: CGFloat = 5.0
        
        useButton.position = CGPoint(
            x: sectionWidth/2 - useButtonSize.width/2 - button1Margin,
            y: -sectionHeight/2 + useButtonSize.height/2 + button1Margin
        )
        useButton.zPosition = section.zPosition + 1
        
        section.addChild(useButton)
        
        let checkIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_check.svg"))
        checkIcon.size = CGSize(width: 23, height: 23)
        checkIcon.position = CGPoint.zero
        checkIcon.zPosition = 502
        checkIcon.name = "CheckIcon"
        useButton.addChild(checkIcon)
        
        //Cancel Button
        let cancelButtonSize = CGSize(width: 35, height: 35)
        let cancelButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        cancelButton.size = cancelButtonSize
        cancelButton.name = "CancelMonopolyButton"
        let button2Margin: CGFloat = 45.0
        
        cancelButton.position = CGPoint(
            x: sectionWidth/2 - cancelButtonSize.width/2 - button2Margin,
            y: -sectionHeight/2 + cancelButtonSize.height/2 + button1Margin
        )
        cancelButton.zPosition = section.zPosition + 1
        
        section.addChild(cancelButton)
        
        let xIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_x.svg"))
        xIcon.size = CGSize(width: 23, height: 23)
        xIcon.position = CGPoint.zero
        xIcon.zPosition = 502
        xIcon.name = "XIcon"
        cancelButton.addChild(xIcon)
        
        // Finally, add the entire container to the UI layer.
        uiLayer.addChild(container)
    }
    
    private func createYearOfPlentyUISection() {
        // Create a container for the entire knight UI.
        let container = SKNode()
        container.name = "YearOfPlenty_UI_Container"
        
        // Define dimensions for the knight UI section.
        let sectionHeight: CGFloat = 215.0
        let leftMargin: CGFloat = 5.0   // Margin from the left edge.
        let rightMargin: CGFloat = 85.0 // Margin from the right edge.
        let bottomMargin: CGFloat = 103.0 // Margin from the bottom edge.
        
        let sectionWidth = size.width - leftMargin - rightMargin
        let centerX = (-size.width / 2 + leftMargin + size.width / 2 - rightMargin) / 2
        
        // Create a rounded rectangle path for the background.
        let cornerRadius: CGFloat = 5.0
        let rect = CGRect(x: -sectionWidth / 2, y: -sectionHeight / 2, width: sectionWidth, height: sectionHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        
        // Create the background shape node.
        let section = SKShapeNode(path: path)
        section.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        section.fillColor = .white
        section.strokeColor = .clear
        section.zPosition = 500
        section.name = "YearOfPlenty_MainSection"

        let centerY = -size.height / 2 + sectionHeight / 2 + bottomMargin
        section.position = CGPoint(x: centerX, y: centerY)
        container.addChild(section)
        
        
        // Define dimensions for the UI section.
        let middleSectionHeight: CGFloat = 48.0
        let middleBottomMargin: CGFloat = 165.0 // Margin from the bottom edge.
        
        // Create a rounded rectangle path for the background.
        let middleRect = CGRect(x: -sectionWidth / 2, y: -middleSectionHeight / 2, width: sectionWidth, height: middleSectionHeight)
        let middlePath = UIBezierPath(roundedRect: middleRect, cornerRadius: cornerRadius).cgPath
        
        // Create the background shape node.
        let middleSection = SKShapeNode(path: middlePath)
        middleSection.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        middleSection.fillColor = .white
        middleSection.strokeColor = .clear
        middleSection.zPosition = 501
        middleSection.name = "Middle_YearOfPlenty_UI_Container"
        
        let middleCenterY = -size.height / 2 + middleSectionHeight / 2 + middleBottomMargin
        middleSection.position = CGPoint(x: centerX, y: middleCenterY)
        container.addChild(middleSection)
        
        // Add the top left development card icon
        let topLeftMarginX: CGFloat = 10.0
        let topLeftMarginY: CGFloat = 12.5
        let cardSize = CGSize(width: 56, height: 80)
        let cardTexture = SKTexture(imageNamed: "card_yearofplenty.svg")
        let cardNode = SKSpriteNode(texture: cardTexture)
        cardNode.size = cardSize
        cardNode.position = CGPoint(
            x: -sectionWidth/2 + topLeftMarginX + cardSize.width/2,
            y: sectionHeight/2 - topLeftMarginY - cardSize.height/2
        )
        cardNode.zPosition = section.zPosition + 1
        section.addChild(cardNode)
        
        
        // Add all resource cards (wood, brick, sheep, wheat, ore)
        let marginY: CGFloat = 5.0
        let resourcesCardSize = CGSize(width: 27, height: 38)
        let resourcesSpacing: CGFloat = 1.0  // Adjust spacing between cards as needed
        let resources: [ResourceType] = [.wood, .brick, .sheep, .wheat, .ore]

        for (index, resource) in resources.enumerated() {
            var textureName: String
            switch resource {
            case .wood:
                textureName = "card_lumber.svg"
            case .brick:
                textureName = "card_brick.svg"
            case .sheep:
                textureName = "card_wool.svg"
            case .wheat:
                textureName = "card_grain.svg"
            case .ore:
                textureName = "card_ore.svg"
            default:
                continue
            }
            
            let resourceTexture = SKTexture(imageNamed: textureName)
            let resourceCardNode = SKSpriteNode(texture: resourceTexture)
            resourceCardNode.size = resourcesCardSize
            
            // Set a unique name so we can detect taps (e.g., "monopolyResource_Wood")
            resourceCardNode.name = "yearOfPlentyResource_\(resource.rawValue)"
            
            // Calculate the x position so that the cards are laid out side-by-side
            let xPosition = (-sectionWidth / 2 + topLeftMarginX + resourcesCardSize.width / 2) + CGFloat(index) * (resourcesCardSize.width + resourcesSpacing)
            let yPosition = middleSectionHeight / 2 - marginY - resourcesCardSize.height / 2
            resourceCardNode.position = CGPoint(x: xPosition, y: yPosition)
            resourceCardNode.zPosition = middleSection.zPosition + 1
            
            middleSection.addChild(resourceCardNode)
        }

        
        // Add text to the right of the development card ---
        // Calculate the starting x position (to the right of the development card) and a base y position.
        let textStartX = cardNode.position.x + cardSize.width/2 + 10
        // Position the title label near the top of the knight card.
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = "Year Of Plenty"
        titleLabel.fontSize = 20  // Slightly bigger font for emphasis.
        let textColor = UIColor(red: 50/255.0, green: 50/255.0, blue: 50/255.0, alpha: 1.0)
        titleLabel.fontColor = textColor
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        // Align the title label near the top of the knight card.
        titleLabel.position = CGPoint(x: textStartX, y: cardNode.position.y + cardSize.height/2 - 15)
        section.addChild(titleLabel)
        
        // Add the description labels below the title.
        let descriptionTexts = [
            "Select any 2 resources from the",
            "bank."
        ]
        
        let lineSpacing: CGFloat = 15

        for (index, text) in descriptionTexts.enumerated() {
            let descriptionLabel = SKLabelNode(fontNamed: "Helvetica")
            descriptionLabel.text = text
            descriptionLabel.fontSize = 14  // A little smaller than the title.
            descriptionLabel.fontColor = textColor
            descriptionLabel.horizontalAlignmentMode = .left
            descriptionLabel.verticalAlignmentMode = .center
      
            let baseY = titleLabel.position.y - titleLabel.fontSize - 5
            let offset = CGFloat(index) * lineSpacing
            let newY = baseY - offset
            descriptionLabel.position = CGPoint(x: textStartX, y: newY)
            
            section.addChild(descriptionLabel)
        }

        
        //Buttons
        let useButtonSize = CGSize(width: 35, height: 35)
        let useButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        useButton.size = useButtonSize
        useButton.name = "UseYearOfPlentyButton"
        let button1Margin: CGFloat = 5.0
        
        useButton.position = CGPoint(
            x: sectionWidth/2 - useButtonSize.width/2 - button1Margin,
            y: -sectionHeight/2 + useButtonSize.height/2 + button1Margin
        )
        useButton.zPosition = section.zPosition + 1
        
        section.addChild(useButton)
        
        let checkIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_check.svg"))
        checkIcon.size = CGSize(width: 23, height: 23)
        checkIcon.position = CGPoint.zero
        checkIcon.zPosition = 502
        checkIcon.name = "CheckIcon"
        useButton.addChild(checkIcon)
        
        //Cancel Button
        let cancelButtonSize = CGSize(width: 35, height: 35)
        let cancelButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        cancelButton.size = cancelButtonSize
        cancelButton.name = "CancelYearOfPlentyButton"
        let button2Margin: CGFloat = 45.0
        
        cancelButton.position = CGPoint(
            x: sectionWidth/2 - cancelButtonSize.width/2 - button2Margin,
            y: -sectionHeight/2 + cancelButtonSize.height/2 + button1Margin
        )
        cancelButton.zPosition = section.zPosition + 1
        
        section.addChild(cancelButton)
        
        let xIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_x.svg"))
        xIcon.size = CGSize(width: 23, height: 23)
        xIcon.position = CGPoint.zero
        xIcon.zPosition = 502
        xIcon.name = "XIcon"
        cancelButton.addChild(xIcon)
        
        // Finally, add the entire container to the UI layer.
        uiLayer.addChild(container)
    }
    
    private func createTradeUISection() {
        // Create a container for the entire trade UI.
        let container = SKNode()
        container.name = "Trade_UI_Container"
        
        // Define the dimensions for the trade section.
        let tradeSectionHeight: CGFloat = 190.0
        let leftMargin: CGFloat = 5.0 // Left margin from the scene edge.
        let rightMargin: CGFloat = 85.0
        // Full width of the scene.
        let bottomMargin: CGFloat = 103.0 // Margin from the bottom edge.
        
        let tradeSectionWidth = size.width - leftMargin - rightMargin
        
        let centerX = (-size.width / 2 + leftMargin + size.width / 2 - rightMargin) / 2
        
        // Create a rounded rectangle path.
        let cornerRadius: CGFloat = 5.0
        // Create the path with origin centered (SKShapeNode’s coordinate system is local).
        let rect = CGRect(x: -tradeSectionWidth / 2, y: -tradeSectionHeight / 2, width: tradeSectionWidth, height: tradeSectionHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        
        // Create the shape node and fill it with your background texture.
        let tradeSection = SKShapeNode(path: path)
        tradeSection.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        tradeSection.fillColor = .white
        tradeSection.strokeColor = .clear
        tradeSection.zPosition = 500
        tradeSection.name = "Trade_UI_Section"
        
        let centerY = -size.height / 2 + tradeSectionHeight / 2 + bottomMargin
        tradeSection.position = CGPoint(x: centerX, y: centerY)
        container.addChild(tradeSection)
        
        
        // Add the top left icon: "icon_players"
        let topLeftMarginX: CGFloat = 10.0
        let topLeftMarginY: CGFloat = 10.0
        let iconPlayersSize = CGSize(width: 40, height: 40)  // Customize size as needed.
        
        let iconPlayersTexture = SKTexture(imageNamed: "icon_players.svg")
        let iconPlayersNode = SKSpriteNode(texture: iconPlayersTexture)
        iconPlayersNode.size = iconPlayersSize
        // Trade section's anchor point is (0.5, 0.5); top left is at (-tradeSectionWidth/2, tradeSectionHeight/2)
        iconPlayersNode.position = CGPoint(x: -tradeSectionWidth/2 + topLeftMarginX + iconPlayersSize.width/2,
                                           y: tradeSectionHeight/2 - topLeftMarginY - iconPlayersSize.height/2)
        iconPlayersNode.zPosition = tradeSection.zPosition + 1
        tradeSection.addChild(iconPlayersNode)
        
        // --------------------------------------------------------
        // Add the bottom left composite icon: player background + logged-in icon
        // --------------------------------------------------------
        // Customize margins for the bottom left icon.
        let bottomLeftMarginX: CGFloat = 10.0
        let bottomLeftMarginY: CGFloat = 10.0
        // Get the human player's color (assuming human is always at index 0).
        let playerColor = gameState.players[0].assetColor
        let playerBGTexture = SKTexture(imageNamed: "player_bg_\(playerColor).svg")
        let playerBGSize = CGSize(width: 40, height: 40)  // Customize size as needed.
        
        let playerBGNode = SKSpriteNode(texture: playerBGTexture)
        playerBGNode.size = playerBGSize
        // Bottom left corner of tradeSection is at (-tradeSectionWidth/2, -tradeSectionHeight/2)
        playerBGNode.position = CGPoint(x: -tradeSectionWidth/2 + bottomLeftMarginX + playerBGSize.width/2,
                                        y: -tradeSectionHeight/2 + bottomLeftMarginY + playerBGSize.height/2)
        playerBGNode.zPosition = tradeSection.zPosition + 1
        tradeSection.addChild(playerBGNode)
        
        // Add the "icon_player_loggedin.svg" on top of the player background.
        let playerLoggedInTexture = SKTexture(imageNamed: "icon_player_loggedin.svg")
        let playerIconSize = CGSize(width: 25, height: 25)  // Customize size (typically a bit smaller than the BG).
        let playerLoggedInNode = SKSpriteNode(texture: playerLoggedInTexture)
        playerLoggedInNode.size = playerIconSize
        // Center the logged-in icon on top of the player background.
        playerLoggedInNode.position = CGPoint.zero
        playerLoggedInNode.zPosition = playerBGNode.zPosition + 1
        playerBGNode.addChild(playerLoggedInNode)
        
        // -----------------------------------
        // Add arrow green to the right of icon_players.
        // -----------------------------------
        let arrowGreenSize = CGSize(width: 40, height: 40)
        let arrowGreenMarginX: CGFloat = 0  // Horizontal gap between icon_players and the green arrow.
        let arrowGreenTexture = SKTexture(imageNamed: "icon_trade_arrow_green.svg")
        let arrowGreenNode = SKSpriteNode(texture: arrowGreenTexture)
        arrowGreenNode.size = arrowGreenSize
        arrowGreenNode.zPosition = 1
        arrowGreenNode.position = CGPoint(
            x: iconPlayersNode.position.x + iconPlayersSize.width/2 + arrowGreenMarginX + arrowGreenSize.width/2,
            y: iconPlayersNode.position.y
        )
        // Rotate the green arrow 90° to the left.
        arrowGreenNode.zRotation = CGFloat.pi/2
        tradeSection.addChild(arrowGreenNode)
        
        // -----------------------------------
        // Add arrow red to the right of playerBG.
        // -----------------------------------
        let arrowRedSize = CGSize(width: 40, height: 40)
        let arrowRedMarginX: CGFloat = 0  // Horizontal gap between playerBG and the red arrow.
        let arrowRedTexture = SKTexture(imageNamed: "icon_trade_arrow_red.svg")
        let arrowRedNode = SKSpriteNode(texture: arrowRedTexture)
        arrowRedNode.size = arrowRedSize
        arrowRedNode.zPosition = 1
        arrowRedNode.position = CGPoint(
            x: playerBGNode.position.x + playerBGSize.width/2 + arrowRedMarginX + arrowRedSize.width/2,
            y: playerBGNode.position.y
        )
        // Rotate the green arrow 90° to the left.
        arrowRedNode.zRotation = CGFloat.pi/2
        arrowRedNode.name = "ArrowRed"  // <-- Assign a name so we can reference it later.
        tradeSection.addChild(arrowRedNode)
        
        // -------------------------------------
        // Create the header section on top of the trade section.
        // -------------------------------------
        let headerSectionHeight: CGFloat = 75.0
        let headerRect = CGRect(x: -tradeSectionWidth / 2, y: -headerSectionHeight / 2, width: tradeSectionWidth, height: headerSectionHeight)
        let headerPath = UIBezierPath(roundedRect: headerRect, cornerRadius: cornerRadius).cgPath
        let headerSection = SKShapeNode(path: headerPath)
        headerSection.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        headerSection.fillColor = .white
        headerSection.strokeColor = .clear
        headerSection.zPosition = tradeSection.zPosition + 1
        headerSection.name = "Trade_Header_Section"
        
        // Margin variable to move the header higher from the main trade section.
        let headerMargin: CGFloat = 3.0
        
        // Position the header so that its bottom edge is headerMargin above the top edge of the main trade section.
        let tradeTopEdge = tradeSection.position.y + tradeSectionHeight / 2
        let headerCenterY = tradeTopEdge + headerSectionHeight / 2 + headerMargin
        headerSection.position = CGPoint(x: centerX, y: headerCenterY)
        
        container.addChild(headerSection)
        
        let bankIconTexture = SKTexture(imageNamed: "bank.svg")
        let bankIconSize = CGSize(width: 40, height: 40)  // Adjust as needed.
        let bankIconNode = SKSpriteNode(texture: bankIconTexture)
        bankIconNode.size = bankIconSize
        bankIconNode.alpha = 0.5  // Half opacity.
        // Compute its x-position: its right edge = (tradeSectionWidth/2 - 2)
        let bankX = tradeSectionWidth / 2 - 7.5 - bankIconSize.width / 2
        bankIconNode.position = CGPoint(x: bankX, y: 0)  // Centered vertically in headerSection.
        bankIconNode.zPosition = headerSection.zPosition + 1
        headerSection.addChild(bankIconNode)
        
        let bankIcon2Texture = SKTexture(imageNamed: "bank.svg")
        let bankIcon2Size = CGSize(width: 40, height: 40)  // Adjust as needed.
        let bankIcon2Node = SKSpriteNode(texture: bankIcon2Texture)
        bankIcon2Node.size = bankIcon2Size
        bankIcon2Node.alpha = 0.5  // Half opacity.
        // Compute its x-position: its right edge = (tradeSectionWidth/2 - 2)
        let bank2X = -tradeSectionWidth / 2 + 7.5 + bankIcon2Size.width / 2
        bankIcon2Node.position = CGPoint(x: bank2X, y: 0)  // Centered vertically in headerSection.
        bankIcon2Node.zPosition = headerSection.zPosition + 1
        headerSection.addChild(bankIcon2Node)
        
        // -------------------------------------
        // Add one card for each resource type in the header.
        // -------------------------------------
        // Define the header card size and spacing.
        let headerCardSize = CGSize(width: 42, height: 60)
        let cardSpacing: CGFloat = 5.0
        // Define the resource order (adjust as needed).
        let resourceOrder: [ResourceType] = [.wood, .brick, .sheep, .wheat, .ore]
        // Mapping from ResourceType to card file key.
        let headerCardMapping: [ResourceType: String] = [
            .wood: "lumber",    // wood -> card_lumber.svg
            .brick: "brick",    // brick -> card_brick.svg
            .sheep: "wool",     // sheep -> card_wool.svg (using 'wool' here)
            .wheat: "grain",    // wheat -> card_grain.svg
            .ore: "ore"         // ore -> card_ore.svg
        ]
        // Calculate total width for the resource cards.
        let totalCardsWidth = CGFloat(resourceOrder.count) * headerCardSize.width + CGFloat(resourceOrder.count - 1) * cardSpacing
        // Starting x in headerSection (its coordinate system is centered).
        var currentX = -totalCardsWidth / 2 + headerCardSize.width / 2
        
        var i = 0
        for resource in resourceOrder {
            if let cardKey = headerCardMapping[resource] {
                let texture = SKTexture(imageNamed: "card_\(cardKey).svg")
                let cardNode = SKSpriteNode(texture: texture)
                cardNode.size = headerCardSize
                cardNode.position = CGPoint(x: currentX, y: 0)  // Center vertically in headerSection.
                cardNode.zPosition = 1
                cardNode.name = "bank_\(resource.rawValue)_\(i)"
                headerSection.addChild(cardNode)
                
                currentX += headerCardSize.width + cardSpacing
            }
            i += 1
        }
        // -------------------------
        // Right-Side Buttons Setup
        // -------------------------
        // These buttons will only appear as part of the trade UI container.
        let buttonSize = CGSize(width: 75, height: 75)
        // Adjustable margins for right-side buttons.
        let rightMarginForButtons: CGFloat = 5.0
        let topMarginForButtons: CGFloat = 369.0
        let verticalSpacingForButtons: CGFloat = 22.0
        
        // Compute x position for buttons (scene's right edge is at size.width/2).
        let buttonX = size.width / 2 - rightMarginForButtons - buttonSize.width / 2
        // Compute y position for the top button.
        let topButtonY = -size.height / 2 + topMarginForButtons - buttonSize.height / 2
        
        // Top Right Button: Bank Check.
        let topButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        topButton.size = buttonSize
        topButton.position = CGPoint(x: buttonX, y: topButtonY)
        topButton.name = "TradeBankButton"
        topButton.zPosition = 103
        
        let bankIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_trade_bank_check.svg"))
        bankIcon.size = CGSize(width: 75, height: 75)
        bankIcon.position = CGPoint.zero
        bankIcon.alpha = 0.5
        bankIcon.zPosition = 104
        bankIcon.name = "bankCheckIcon"
        topButton.addChild(bankIcon)
        
        // Bottom Right Button: Opponents Check.
        let bottomButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        bottomButton.size = buttonSize
        let bottomButtonY = topButtonY - buttonSize.height - verticalSpacingForButtons
        bottomButton.position = CGPoint(x: buttonX, y: bottomButtonY)
        bottomButton.name = "TradeOpponentsButton"
        bottomButton.zPosition = 1030
        
        let opponentsIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_trade_opponents_check.svg"))
        opponentsIcon.size = CGSize(width: 75, height: 75)
        opponentsIcon.position = CGPoint.zero
        opponentsIcon.alpha = 0.5
        opponentsIcon.zPosition = 104
        opponentsIcon.name = "tradeOpponentsCheckIcon"
        bottomButton.addChild(opponentsIcon)
        
        // --- Third Button: X Check ---
        let thirdButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        thirdButton.size = buttonSize
        let thirdButtonY = bottomButton.position.y - buttonSize.height - verticalSpacingForButtons
        thirdButton.position = CGPoint(x: buttonX, y: thirdButtonY)
        thirdButton.name = "TradeXButton"
        thirdButton.zPosition = 103
        
        let xIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_x.svg"))
        xIcon.size = CGSize(width: 45, height: 45)
        xIcon.position = .zero
        xIcon.zPosition = 1030
        thirdButton.addChild(xIcon)
        
        // Add the right-side buttons as children of the container.
        container.addChild(topButton)
        container.addChild(bottomButton)
        container.addChild(thirdButton)
        
        // Finally, add the container to the uiLayer.
        uiLayer.addChild(container)
    }
    
    private func createTradePopUpUISection() {
        guard let view = self.view else {
            return
        }
        
        let sectionHeight: CGFloat = 114.0
        let sectionWidth = size.width
        let cornerRadius: CGFloat = 10.0
        
        let safeAreaInsets = view.safeAreaInsets
        let safeLeft = -size.width / 2 + safeAreaInsets.left
        let safeTop = size.height / 2 - safeAreaInsets.top
        
        // Create rounded rectangle path
        let rect = CGRect(x: -sectionWidth/2, y: -sectionHeight/2, width: sectionWidth, height: sectionHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath
        
        let section = SKShapeNode(path: path)
        section.fillTexture = SKTexture(imageNamed: "bg_section.svg")
        section.fillColor = .white
        section.strokeColor = .clear
        section.zPosition = 1000  // High zPosition to appear above other elements
        
        // Position at bottom of screen
        section.position = CGPoint(x: 0, y: safeTop - 192.0)
        section.name = "TradePopUp_UI_Container"
        
        let playerColor = gameState.players[0].assetColor.lowercased()
        let playerBGSize = CGSize(width: 40, height: 40)
        let playerBGMarginX: CGFloat = 5.0  // Adjust horizontal margin
        let playerBGMarginY: CGFloat = 10.0  // Adjust vertical margin
        
        let playerBG = SKSpriteNode(imageNamed: "player_bg_\(playerColor).svg")
        playerBG.size = playerBGSize
        playerBG.position = CGPoint(
            x: -sectionWidth/2 + playerBGMarginX + playerBGSize.width/2,
            y: -sectionHeight/2 + playerBGMarginY + playerBGSize.height/2
        )
        playerBG.zPosition = section.zPosition + 1
        section.addChild(playerBG)
        
    // Add logged-in indicator on top of player background
       let loggedInIconSize = CGSize(width: 25, height: 25) // Slightly smaller than background
       let loggedInIcon = SKSpriteNode(imageNamed: "icon_player_loggedin.svg")
       loggedInIcon.size = loggedInIconSize
       loggedInIcon.position = .zero // Centered relative to parent (playerBG)
       loggedInIcon.zPosition = playerBG.zPosition + 1
       playerBG.addChild(loggedInIcon)
        
        // Players icon settings (top left)
        let playersIconSize = CGSize(width: 40, height: 40)
        let playersIconMarginX: CGFloat = 5.0  // Adjust horizontal margin
        let playersIconMarginY: CGFloat = 5.0  // Adjust vertical margin
        
        let playersIcon = SKSpriteNode(imageNamed: "icon_players.svg")
        playersIcon.size = playersIconSize
        playersIcon.position = CGPoint(
            x: -sectionWidth/2 + playersIconMarginX + playersIconSize.width/2,
            y: sectionHeight/2 - playersIconMarginY - playersIconSize.height/2
        )
        playersIcon.zPosition = section.zPosition + 1
        section.addChild(playersIcon)
        
        // Red arrow settings (right of player background)
        let redArrowSize = CGSize(width: 30, height: 30)
        let redArrowMarginX: CGFloat = 12.0  // Adjust horizontal spacing from playerBG
        let redArrow = SKSpriteNode(imageNamed: "icon_trade_arrow_red.svg")
        redArrow.size = redArrowSize
        redArrow.position = CGPoint(
            x: playerBG.position.x + playerBGSize.width/2 + redArrowMarginX,
            y: playerBG.position.y
        )
        redArrow.zPosition = playerBG.zPosition
        redArrow.zRotation = Double.pi / 2
        section.addChild(redArrow)

        // Green arrow settings (right of players icon)
        let greenArrowSize = CGSize(width: 30, height: 30)
        let greenArrowMarginX: CGFloat = 12.0  // Adjust horizontal spacing from playersIcon
        let greenArrow = SKSpriteNode(imageNamed: "icon_trade_arrow_green.svg")
        greenArrow.size = greenArrowSize
        greenArrow.position = CGPoint(
            x: playersIcon.position.x + playersIconSize.width/2 + greenArrowMarginX,
            y: playersIcon.position.y - 5
        )
        greenArrow.zPosition = playersIcon.zPosition
        greenArrow.zRotation = Double.pi / 2
        section.addChild(greenArrow)
        
        //Cancel Button
        let cancelButtonSize = CGSize(width: 45, height: 45)
        let cancelButton = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button.svg"))
        cancelButton.size = cancelButtonSize
        cancelButton.name = "cancelTradeRequest"
        let cancelButtonMarginY: CGFloat = 5.0
        let cancelButtonMarginX: CGFloat = 5.0
        
        cancelButton.position = CGPoint(
            x: sectionWidth/2 - cancelButtonSize.width/2 - cancelButtonMarginX,
            y: -sectionHeight/2 + cancelButtonSize.height/2 + cancelButtonMarginY
        )
        cancelButton.zPosition = section.zPosition + 1
        
        section.addChild(cancelButton)
        
        let xIcon = SKSpriteNode(texture: SKTexture(imageNamed: "icon_x.svg"))
        xIcon.size = CGSize(width: 27.0, height: 27.0)
        xIcon.position = CGPoint.zero
        xIcon.zPosition = 502
        xIcon.name = "XIcon"
        cancelButton.addChild(xIcon)
        
        let player1Color = gameState.players[1].assetColor.lowercased()
        let player2Color = gameState.players[2].assetColor.lowercased()
        let player3Color = gameState.players[3].assetColor.lowercased()
        
        //Aceept Trade Button
        let acceptTrade1Button = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button_\(player1Color).svg"))
        acceptTrade1Button.size = cancelButtonSize
        acceptTrade1Button.name = "botTradeButton_1"
        let acceptTrade1ButtonMarginX: CGFloat = 57.0
        
        acceptTrade1Button.position = CGPoint(
            x: sectionWidth/2 - cancelButtonSize.width/2 - acceptTrade1ButtonMarginX,
            y: -sectionHeight/2 + cancelButtonSize.height/2 + cancelButtonMarginY
        )
        acceptTrade1Button.zPosition = section.zPosition + 1
        acceptTrade1Button.alpha = 0.4
        
        section.addChild(acceptTrade1Button)
        
        let hourglassIcon1 = SKSpriteNode(texture: SKTexture(imageNamed: "icon_hourglass.svg"))
        hourglassIcon1.size = CGSize(width: 27.0, height: 27.0)
        hourglassIcon1.position = CGPoint.zero
        hourglassIcon1.zPosition = 502
        hourglassIcon1.name = "HourglassIcon1"
        hourglassIcon1.alpha = 0.75
        
        acceptTrade1Button.addChild(hourglassIcon1)
        
        //Aceept Trade Button
        let acceptTrade2Button = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button_\(player2Color).svg"))
        acceptTrade2Button.size = cancelButtonSize
        acceptTrade2Button.name = "botTradeButton_2"
        let acceptTrade2ButtonMarginX: CGFloat = 109.0
        
        acceptTrade2Button.position = CGPoint(
            x: sectionWidth/2 - cancelButtonSize.width/2 - acceptTrade2ButtonMarginX,
            y: -sectionHeight/2 + cancelButtonSize.height/2 + cancelButtonMarginY
        )
        acceptTrade2Button.zPosition = section.zPosition + 1
        acceptTrade2Button.alpha = 0.4

        section.addChild(acceptTrade2Button)
        
        let hourglassIcon2 = SKSpriteNode(texture: SKTexture(imageNamed: "icon_hourglass.svg"))
        hourglassIcon2.size = CGSize(width: 27.0, height: 27.0)
        hourglassIcon2.position = CGPoint.zero
        hourglassIcon2.zPosition = 502
        hourglassIcon2.name = "HourglassIcon2"
        hourglassIcon2.alpha = 0.75

        acceptTrade2Button.addChild(hourglassIcon2)

        //Aceept Trade Button
        let acceptTrade3Button = SKSpriteNode(texture: SKTexture(imageNamed: "bg_button_\(player3Color).svg"))
        acceptTrade3Button.size = cancelButtonSize
        acceptTrade3Button.name = "botTradeButton_3"
        let acceptTrade3ButtonMarginX: CGFloat = 161.0
        
        acceptTrade3Button.position = CGPoint(
            x: sectionWidth/2 - cancelButtonSize.width/2 - acceptTrade3ButtonMarginX,
            y: -sectionHeight/2 + cancelButtonSize.height/2 + cancelButtonMarginY
        )
        acceptTrade3Button.zPosition = section.zPosition + 1
        acceptTrade3Button.alpha = 0.4

        section.addChild(acceptTrade3Button)
        
        let hourglassIcon3 = SKSpriteNode(texture: SKTexture(imageNamed: "icon_hourglass.svg"))
        hourglassIcon3.size = CGSize(width: 27.0, height: 27.0)
        hourglassIcon3.position = CGPoint.zero
        hourglassIcon3.zPosition = 502
        hourglassIcon3.name = "HourglassIcon3"
        hourglassIcon3.alpha = 0.75

        acceptTrade3Button.addChild(hourglassIcon3)
        
        // Remove any existing trade popup card nodes from the uiLayer.
        uiLayer.children.filter { $0.name?.hasPrefix("tradePopUp_") ?? false }
            .forEach { $0.removeFromParent() }

        // Layout parameters for card placement.
        let sameTypeSpacing: CGFloat = -24
        let groupSpacing: CGFloat = 35
        let cardSize = CGSize(width: 34, height: 48)

        let badgeSize = CGSize(width: 15, height: 15)
        let badgeOffset = CGPoint(x: cardSize.width/2 - (badgeSize.width/2 + 2),
                                  y: cardSize.height/2 - badgeSize.height/2)

        // Define a mapping from your ResourceType to the card image key.
        // (e.g. for wood, the file is "card_lumber.svg")
        let resourceCardMapping1: [ResourceType: String] = [
            .wood: "lumber",
            .brick: "brick",
            .sheep: "wool",
            .wheat: "grain",
            .ore: "ore"
        ]

        // Get the current player.
        let player = gameState.players[0]
        
        let marginBetweenArrowAndCards: CGFloat = 20.0

        // ***** Group 1: Trade Selected Cards (from player's hand) *****
        let tradeCardsStartX = section.position.x + redArrow.position.x + redArrow.size.width/2 + marginBetweenArrowAndCards
        let bankCardsStartX  = section.position.x + greenArrow.position.x + greenArrow.size.width/2 + marginBetweenArrowAndCards

        
        var currentXTrade = tradeCardsStartX
        for resource in ResourceType.allCases {
            if resource == .desert { continue }
            // Get the number of cards the player has chosen to trade (from their hand).
            let count = player.selectedForTrade[resource] ?? 0
            
            if count > 0, let cardKey = resourceCardMapping1[resource] {
                var lastCardNode: SKSpriteNode?
                // Create one card node per card selected.
                for i in 0..<count {
                    let texture = SKTexture(imageNamed: "card_\(cardKey).svg")
                    let cardNode = SKSpriteNode(texture: texture)
                    cardNode.size = cardSize
                    cardNode.position = CGPoint(x: currentXTrade, y: section.position.y + redArrow.position.y)
                    // Name the node with a prefix to denote trade selection.
                    cardNode.name = "tradePopUp_\(resource.rawValue)_trade_\(i)"
                    cardNode.zPosition = 3000
                    uiLayer.addChild(cardNode)
                    
                    lastCardNode = cardNode
                    
                    if i < count - 1 {
                        currentXTrade += cardSize.width + sameTypeSpacing
                    }
                }
                // Add a badge to the last card showing the count.
                if let lastCard = lastCardNode {
                    let badgeTexture = SKTexture(imageNamed: "card_badge_background.svg")
                    let badgeNode = SKSpriteNode(texture: badgeTexture)
                    badgeNode.size = badgeSize
                    badgeNode.position = badgeOffset
                    badgeNode.zPosition = lastCard.zPosition + 1
                    badgeNode.name = "badge_\(resource.rawValue)_trade"
                    lastCard.addChild(badgeNode)
                    
                    let countLabel = SKLabelNode(text: "\(count)")
                    countLabel.fontName = "Helvetica-Bold"
                    countLabel.fontSize = 12
                    countLabel.fontColor = .white
                    countLabel.verticalAlignmentMode = .center
                    countLabel.horizontalAlignmentMode = .center
                    countLabel.position = CGPoint(x: 2, y: 1)
                    countLabel.zPosition = lastCard.zPosition + 2
                    badgeNode.addChild(countLabel)
                }
                // Add group spacing after finishing a resource group.
                currentXTrade += groupSpacing
            }
        }

        // ***** Group 2: Bank Selected Cards *****
        // Start the bank-selected group immediately following the trade cards.
        var currentXBank = bankCardsStartX
        for resource in ResourceType.allCases {
            if resource == .desert { continue }
            // Get the number of cards chosen from the bank.
            let count = player.selectedBankCards[resource] ?? 0
            
            if count > 0, let cardKey = resourceCardMapping1[resource] {
                var lastCardNode: SKSpriteNode?
                for i in 0..<count {
                    let texture = SKTexture(imageNamed: "card_\(cardKey).svg")
                    let cardNode = SKSpriteNode(texture: texture)
                    cardNode.size = cardSize
                    cardNode.position = CGPoint(x: currentXBank, y: section.position.y + greenArrow.position.y)
                    cardNode.name = "tradePopUp_\(resource.rawValue)_bank_\(i)"
                    cardNode.zPosition = 3000
                    uiLayer.addChild(cardNode)
                    
                    lastCardNode = cardNode
                    
                    if i < count - 1 {
                        currentXBank += cardSize.width + sameTypeSpacing
                    }
                }
                if let lastCard = lastCardNode {
                    let badgeTexture = SKTexture(imageNamed: "card_badge_background.svg")
                    let badgeNode = SKSpriteNode(texture: badgeTexture)
                    badgeNode.size = badgeSize
                    badgeNode.position = badgeOffset
                    badgeNode.zPosition = lastCard.zPosition + 1
                    badgeNode.name = "badge_\(resource.rawValue)_bank"
                    lastCard.addChild(badgeNode)
                    
                    let countLabel = SKLabelNode(text: "\(count)")
                    countLabel.fontName = "Helvetica-Bold"
                    countLabel.fontSize = 12
                    countLabel.fontColor = .white
                    countLabel.verticalAlignmentMode = .center
                    countLabel.horizontalAlignmentMode = .center
                    countLabel.position = CGPoint(x: 2, y: 1)
                    countLabel.zPosition = lastCard.zPosition + 2
                    badgeNode.addChild(countLabel)
                }
                currentXBank += groupSpacing
            }
        }
        
        uiLayer.addChild(section)
    }
    
    func updatePlayerUISection() {
        for (index, player) in gameState.players.enumerated() {
            // Update resource card label to show total resource count.
            let resourceCount = player.resources.values.reduce(0, +)
            if let resLabel = uiLayer.childNode(withName: "//resBadgeLabel_player\(index)") as? SKLabelNode {
                resLabel.text = "\(resourceCount)"
            }
            
            if let resCard = uiLayer.childNode(withName: "//resCard_player\(index)") as? SKSpriteNode {
                let overLimit = (resourceCount > discardLimit)
                let resCardTextureName = overLimit ? "card_rescardoverlimit.svg" : "card_rescardback.svg"
                resCard.texture = SKTexture(imageNamed: "\(resCardTextureName)")
            }

            
            // Update development card label to show total development cards.
            let devCount = player.developmentCards.values.reduce(0, +)
            if let devLabel = uiLayer.childNode(withName: "//devBadgeLabel_player\(index)") as? SKLabelNode {
                devLabel.text = "\(devCount)"
            }
            
            // Update army label to show how many knights were used.
            if let armyLabel = uiLayer.childNode(withName: "//armyBadgeLabel_player\(index)") as? SKLabelNode {
                armyLabel.text = "\(player.knightsUsed)"
            }
            
            // Update longest road label to show the player's longest road length.
            if let roadLabel = uiLayer.childNode(withName: "//roadBadgeLabel_player\(index)") as? SKLabelNode {
                roadLabel.text = "\(player.longestRoadLength)"
            }
            
            // Update ribbon label to show the player's victory points.
            if let ribbonLabel = uiLayer.childNode(withName: "//ribbonLabel_player\(index)") as? SKLabelNode {
                if let vpCardCount = player.developmentCards[.victoryPoint], vpCardCount > 0, index == 0 {
                    // Calculate the victory points not coming from VP cards.
                    let nonCardVP = player.victoryPoints - vpCardCount
                    // Display both values. You can adjust the formatting as needed.
                    ribbonLabel.text = "\(nonCardVP) (\(player.victoryPoints))"
                } else {
                    ribbonLabel.text = "\(player.victoryPoints)"
                }

            }
            
            // Update the largest army icon texture.
            if let armyIcon = uiLayer.childNode(withName: "//armyIcon_player\(index)") as? SKSpriteNode {
                let textureName = player.hasLargestArmy ? "icon_largest_army_highlight.svg" : "icon_largest_army.svg"
                armyIcon.texture = SKTexture(imageNamed: textureName)
            }
            
            // Update the longest road icon texture.
            if let roadIcon = uiLayer.childNode(withName: "//roadIcon_player\(index)") as? SKSpriteNode {
                let textureName = player.hasLongestRoad ? "icon_longest_road_highlight.svg" : "icon_longest_road.svg"
                roadIcon.texture = SKTexture(imageNamed: textureName)
            }
            
            let isCurrentPlayer = gameState.currentPlayerIndex == index
            
            if let playerBG = uiLayer.childNode(withName: "//player\(index + 1)Section") as? SKShapeNode {
                let bgTextureName = isCurrentPlayer ? "bg_section.svg" : "bg_player_inactive.svg"
                playerBG.fillTexture = SKTexture(imageNamed: "\(bgTextureName)")
            }
        }
    }
    
    // MARK: - Debug Overlay for Settlement Scores
    func showSettlementScoreOverlays(vertexScores: [VertexPoint: Double],
                                     completion: @escaping () -> Void) {
        let debugLayer = SKNode()
        debugLayer.name = "debugSettlementLayer"
        
        // Create and position a label for each vertex with a bigger, bold font.
        for (vertex, score) in vertexScores {
            let label = SKLabelNode(text: String(format: "%.2f", score))
            label.fontSize = 20  // Bigger font size
            label.fontName = "Helvetica-Bold"  // Bold font
            label.fontColor = .cyan
            label.position = vertex.position
            label.zPosition = 1001  // Ensure it's above game elements.
            debugLayer.addChild(label)
        }
        
        addChild(debugLayer)
        
        // Run an action to wait 5 seconds, remove the debug overlay,
        // and then call the completion closure.
        debugLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: 5.0),
            SKAction.removeFromParent()
        ]), completion: {
            completion()
        })
    }
      
    // MARK: - Debug Overlay for Road Scores
    func showRoadScoreOverlays(edgeScores: [EdgePoint: Double],
                               completion: @escaping () -> Void) {
        let debugLayer = SKNode()
        debugLayer.name = "debugRoadLayer"
        
        // Create and position a label at the midpoint of each edge.
        for (edge, score) in edgeScores {
            if edge.vertices.count >= 2 {
                let midX = (edge.vertices[0].position.x + edge.vertices[1].position.x) / 2
                let midY = (edge.vertices[0].position.y + edge.vertices[1].position.y) / 2
                let label = SKLabelNode(text: String(format: "%.2f", score))
                label.fontSize = 20  // Bigger font size
                label.fontName = "Helvetica-Bold"  // Bold font
                label.fontColor = .magenta
                label.position = CGPoint(x: midX, y: midY)
                label.zPosition = 1001
                debugLayer.addChild(label)
            }
        }
        
        addChild(debugLayer)
        
        debugLayer.run(SKAction.sequence([
            SKAction.wait(forDuration: 5.0),
            SKAction.removeFromParent()
        ]), completion: {
            completion()
        })
    }

}

struct Coordinate: Hashable {
    let x: CGFloat
    let y: CGFloat
}
