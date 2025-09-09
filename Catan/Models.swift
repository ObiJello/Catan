import Foundation
import SpriteKit

// Resource types in Catan
enum ResourceType: String, CaseIterable {
    case wood = "Wood"
    case brick = "Brick"
    case sheep = "Sheep"
    case wheat = "Wheat"
    case ore = "Ore"
    case desert = "Desert"
}

// Represents a hex tile on the game board
class Tile {
    let resourceType: ResourceType
    let diceValue: Int?  // nil for desert
    var hasRobber: Bool
    let position: CGPoint
    
    init(resourceType: ResourceType, diceValue: Int?, position: CGPoint) {
        self.resourceType = resourceType
        self.diceValue = diceValue
        self.position = position
        self.hasRobber = resourceType == .desert
    }
}

extension Notification.Name {
    static let victoryPointsDidChange = Notification.Name("victoryPointsDidChange")
}

// Represents a player in the game
class Player {
    let id: Int
    var assetColor: String  // New: stores the chosen color as a string for asset naming.
    var isBot: Bool
    var resources: [ResourceType: Int]
    var selectedForTrade: [ResourceType: Int]
    var selectedBankCards: [ResourceType: Int]
    var selectedToDiscard: [ResourceType: Int]
    var developmentCards: [DevelopmentCardType: Int]
    var portsUnlocked: [String] = []
    var hasLongestRoad: Bool
    var hasLargestArmy: Bool
    var knightsUsed: Int
    var longestRoadLength: Int
    var roadsLeft = 15
    var settlementsLeft = 5
    var citiesLeft = 4
    var settlements: [VertexPoint] = []

    var victoryPoints: Int = 0 {
            didSet {
                // Post a notification every time victoryPoints changes.
                NotificationCenter.default.post(name: .victoryPointsDidChange, object: nil)
            }
        }
    
    init(id: Int, isBot: Bool = false) {
        self.id = id
        self.assetColor = "blue"  // Default value – will be overwritten by configuration.
        self.isBot = isBot
        self.resources = [.wood: 0, .brick: 0, .sheep: 0, .wheat: 0, .ore: 0]
        self.selectedForTrade = [.wood: 0, .brick: 0, .sheep: 0, .wheat: 0, .ore: 0]
        self.selectedBankCards = [.wood: 0, .brick: 0, .sheep: 0, .wheat: 0, .ore: 0]
        self.selectedToDiscard = [.wood: 0, .brick: 0, .sheep: 0, .wheat: 0, .ore: 0]
        self.developmentCards = [.knight: 0, .monopoly: 0, .roadBuilding: 0, .victoryPoint: 0, .yearOfPlenty: 0]
        self.portsUnlocked = []
        self.victoryPoints = 0
        self.hasLargestArmy = false
        self.hasLongestRoad = false
        self.longestRoadLength = 0
        self.knightsUsed = 0
        self.settlements = []

    }
}

// Building types in Catan
enum BuildingType {
    case road
    case settlement
    case city
}

// Represents a building on the board
class Building {
    var type: BuildingType
    let ownerId: Int
    let position: CGPoint
    
    init(type: BuildingType, ownerId: Int, position: CGPoint) {
        self.type = type
        self.ownerId = ownerId
        self.position = position
    }
}

// Represents the game board
class GameBoard {
    var tiles: [Tile]
    var buildings: [Building]
    var robberPosition: CGPoint

    // New property: mapping from port type to an array of node coordinates (using CGPoint)
    var ports: [Int: [CGPoint]]
    
    init() {
        self.tiles = []
        self.buildings = []
        self.robberPosition = .zero
        self.ports = [:]
    }
    
    /// Adds a port coordinate for a given port type.
    func addPort(portType: Int, coordinate: CGPoint) {
        if ports[portType] != nil {
            ports[portType]?.append(coordinate)
        } else {
            ports[portType] = [coordinate]
        }
    }
    
    /// Initialize ports from a pre-defined configuration.
    /// (Adjust the coordinates and port types to match your game design.)
    func initializePorts() {
        // Example: MISC_PORT (port type 0)
        addPort(portType: 0, coordinate: CGPoint(x: 100.0, y: 200.0))
        addPort(portType: 0, coordinate: CGPoint(x: 250.0, y: 300.0))
        
        // Example: CLAY_PORT (port type 1)
        addPort(portType: 1, coordinate: CGPoint(x: 150.0, y: 250.0))
        
        // Example: SHEEP_PORT (port type 2)
        addPort(portType: 2, coordinate: CGPoint(x: 200.0, y: 350.0))
        
        // Example: WHEAT_PORT (port type 3)
        addPort(portType: 3, coordinate: CGPoint(x: 300.0, y: 400.0))
        
        // Example: ORE_PORT (port type 4)
        addPort(portType: 4, coordinate: CGPoint(x: 350.0, y: 450.0))
        
        // Example: WOOD_PORT (port type 5)
        addPort(portType: 5, coordinate: CGPoint(x: 400.0, y: 500.0))
    }
}

extension Player {
    func canBuild(buildingType: BuildingType) -> Bool {
        switch buildingType {
        case .road:
            return roadsLeft > 0
        case .settlement:
            return settlementsLeft > 0
        case .city:
            return citiesLeft > 0
        }
    }
    
    func deductBuilding(buildingType: BuildingType) {
        switch buildingType {
        case .road:
            roadsLeft -= 1
        case .settlement:
            settlementsLeft -= 1
        case .city:
            citiesLeft -= 1
        }
    }
}
