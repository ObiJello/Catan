import Foundation
import UIKit

enum GamePhase {
    case setup
    case play
    case discardCards
    case buildRoad
    case buildSettlement
    case buildCity
    case trade
    case end
}

class GameState {
    var currentPhase: GamePhase = .setup
    var currentPlayerIndex: Int = 0
    var players: [Player] = []
    var currentDiceRoll: Int = 0
    var turnCount: Int = 0
    var victoryPointGoal: Int = 10
    var longestRoadOwnerId: Int? = nil
    var currentLongestRoadLength = 0
    let minimumLongestRoad = 5
    
    // A bag for biased dice rolls.
    var diceRollBag: [Int] = []
    
    // New property to track if the dice have been rolled this turn
    var hasRolledDice: Bool = false
    
    // Computed property to check if we're in setup phase
    var isSetupPhase: Bool {
        return currentPhase == .setup
    }
    
    init(playerCount: Int) {
        let colors: [UIColor] = [.red, .blue, .white, .orange]
        for i in 0..<playerCount {
            // Only player 0 is human; others are bots.
            let isBot = (i != 0)
            let player = Player(id: i, isBot: isBot)
            players.append(player)
        }
    }
    
    func nextPlayer() {
            currentPlayerIndex = (currentPlayerIndex + 1) % players.count
            if currentPlayerIndex == 0 {
                turnCount += 1
            }
            // Reset the dice roll flag for the new turn.
            hasRolledDice = false
        }
    
    func isPlayersTurn(index: Int) -> Bool {
        return index == currentPlayerIndex
    }
    
    func rollDice() -> Int {
            // Only roll if not already rolled this turn.
            if hasRolledDice {
                return currentDiceRoll
            }
            let dice1 = Int.random(in: 1...6)
            let dice2 = Int.random(in: 1...6)
            currentDiceRoll = dice1 + dice2
            hasRolledDice = true
            return currentDiceRoll
        }
    
    func initializeDiceRollBag() {
            diceRollBag = []
            // Two dice: Outcome frequencies are:
            // 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6, 8: 5, 9: 4, 10: 3, 11: 2, 12: 1
            diceRollBag.append(contentsOf: Array(repeating: 2, count: 1))
            diceRollBag.append(contentsOf: Array(repeating: 3, count: 2))
            diceRollBag.append(contentsOf: Array(repeating: 4, count: 3))
            diceRollBag.append(contentsOf: Array(repeating: 5, count: 4))
            diceRollBag.append(contentsOf: Array(repeating: 6, count: 5))
            diceRollBag.append(contentsOf: Array(repeating: 7, count: 6))
            diceRollBag.append(contentsOf: Array(repeating: 8, count: 5))
            diceRollBag.append(contentsOf: Array(repeating: 9, count: 4))
            diceRollBag.append(contentsOf: Array(repeating: 10, count: 3))
            diceRollBag.append(contentsOf: Array(repeating: 11, count: 2))
            diceRollBag.append(contentsOf: Array(repeating: 12, count: 1))
        }
        
        // The biased dice roll function.
        func rollDiceWithBias() -> Int {
            // If the bag is empty, reinitialize it.
            if diceRollBag.isEmpty {
                initializeDiceRollBag()
            }
            // Pick a random index and remove that outcome.
            let randomIndex = Int.random(in: 0..<diceRollBag.count)
            let result = diceRollBag.remove(at: randomIndex)
            currentDiceRoll = result
            hasRolledDice = true
            return result
        }
}

extension Player {
    func shouldBuildRoad(gameState: GameState) -> Bool {
        let hasEnough = resources[.wood] ?? 0 >= 1 && resources[.brick] ?? 0 >= 1
        
        // Only build if we can potentially challenge for longest road
        let neededLength = gameState.currentLongestRoadLength + 1
        let roadPotential = longestRoadLength >= neededLength ||
                          (longestRoadLength + 2 >= neededLength)
        
        return hasEnough && roadPotential
    }
    
    func shouldBuildSettlement() -> Bool {
        let hasResources = (resources[.wood] ?? 0 >= 1) &&
                          (resources[.brick] ?? 0 >= 1) &&
                          (resources[.sheep] ?? 0 >= 1) &&
                          (resources[.wheat] ?? 0 >= 1)
        return hasResources && victoryPoints < 4 // Prioritize early expansion
    }
    
    func shouldUpgradeCity(gameState: GameState) -> Bool {
        let hasResources = (resources[.wheat] ?? 0 >= 2) &&
                          (resources[.ore] ?? 0 >= 3)
        return hasResources && victoryPoints < gameState.victoryPointGoal - 2
    }
}

extension GameState {
    func updateLongestRoad() {
        var maxLength = 0
        var candidates: [Int] = []
        
        // Find maximum road length among all players
        for player in players {
            maxLength = max(maxLength, player.longestRoadLength)
        }
        
        // Find all players with max length
        candidates = players.indices.filter {
            players[$0].longestRoadLength == maxLength
        }
        
        // Only update if someone meets minimum requirement
        if maxLength >= minimumLongestRoad {
            // Check if current owner still qualifies
            if let currentOwner = longestRoadOwnerId {
                if !candidates.contains(currentOwner) || players[currentOwner].longestRoadLength < maxLength {
                    longestRoadOwnerId = nil
                }
            }
            
            // Assign to first candidate if not already assigned
            if longestRoadOwnerId == nil && !candidates.isEmpty {
                longestRoadOwnerId = candidates[0]
            }
        } else {
            // Clear if no one qualifies
            if let currentOwner = longestRoadOwnerId {
                longestRoadOwnerId = nil
            }
        }
        
        currentLongestRoadLength = maxLength
    }
}
