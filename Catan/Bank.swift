import Foundation
import SpriteKit

// MARK: - Development Card Definitions

enum DevelopmentCardType {
    case knight
    case roadBuilding
    case yearOfPlenty
    case monopoly
    case victoryPoint
}

class DevelopmentCard {
    let type: DevelopmentCardType
    init(type: DevelopmentCardType) {
        self.type = type
    }
}

// MARK: - Bank Class

class Bank {
    // An array holding all development cards
    var developmentCards: [DevelopmentCard]
    // A dictionary representing the resource counts remaining in the bank
    var resourceCards: [ResourceType: Int]
    
    init() {
        // Initialize development cards according to the specified counts
        developmentCards = []
        for _ in 0..<14 {
            developmentCards.append(DevelopmentCard(type: .knight))
        }
        for _ in 0..<2 {
            developmentCards.append(DevelopmentCard(type: .roadBuilding))
        }
        for _ in 0..<2 {
            developmentCards.append(DevelopmentCard(type: .yearOfPlenty))
        }
        for _ in 0..<2 {
            developmentCards.append(DevelopmentCard(type: .monopoly))
        }
        for _ in 0..<5 {
            developmentCards.append(DevelopmentCard(type: .victoryPoint))
        }
        // Shuffle the development cards if desired
        developmentCards.shuffle()
        
        // Initialize the resource bank with 19 of each resource type (excluding desert)
        resourceCards = [
            .wood: 19,
            .brick: 19,
            .sheep: 19,
            .wheat: 19,
            .ore: 19
        ]
    }
    
    // Example function to draw a development card from the bank
    func drawDevelopmentCard() -> DevelopmentCard? {
        guard !developmentCards.isEmpty else { return nil }
        let randomIndex = Int.random(in: 0..<developmentCards.count)
        return developmentCards.remove(at: randomIndex)
    }
    
    // Example function to take resources from the bank (returns true if successful)
    func takeResources(resource: ResourceType, amount: Int) -> Bool {
        guard let currentCount = resourceCards[resource], currentCount >= amount else {
            return false
        }
        resourceCards[resource] = currentCount - amount
        return true
    }
    
    // Additional bank-related methods can be added here...
}
