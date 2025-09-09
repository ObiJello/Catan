import Foundation
import SpriteKit

/// High-level decisions a bot can make on its turn.
enum BotDecision {
    case buildSettlement(at: VertexPoint)
    case buildRoad(at: EdgePoint)
    case upgradeCity(at: VertexPoint)
    case playDevelopmentCard(type: DevelopmentCardType)
    case moveRobber(to: Tile)
    case acceptTrade(offer: BotDecisionEngine.TradeOffer)
    case declineTrade
    case endTurn
}

class BotDecisionEngine {
    // MARK: - Tweakable Scoring Variables
    var productionWeight: Double = 1.0
    var diversityWeight: Double = 0.3
    var portProximityWeight: Double = 0.3
    var expansionWeight: Double = 0.2
    var missingResourceBonusWeight: Double = 0.2
    
    var roadExtensionWeight: Double = 1.0
    var longestRoadBonus: Double = 0.7
    var settlementAtRoadBonusWeight: Double = 0.5
    var pathLookAheadWeight: Double = 0.5
    var lookAheadDepth: Int = 2
    
    var tradeValueWeight: Double = 1.0
    
    var knightUsageWeight: Double = 0.8
    var roadBuildingUsageWeight: Double = 0.7
    var monopolyUsageWeight: Double = 0.6
    var yearOfPlentyUsageWeight: Double = 0.5
    
    var opponentResourceBonus: Double = 1.0
    var leaderBlockBonus: Double = 1.2
    
    // MARK: - Helper Functions
    /// Dice roll probability for resource production.
    func productionProbability(for roll: Int) -> Double {
        let probabilities: [Int: Double] = [
            2: 0.028, 3: 0.056, 4: 0.083, 5: 0.111,
            6: 0.139, 8: 0.139, 9: 0.111, 10: 0.083,
            11: 0.056, 12: 0.028
        ]
        return probabilities[roll] ?? 0
    }
    
    // MARK: - Settlement Placement
    func scoreSettlementOptions(vertices: [VertexPoint],
                                forPlayer player: Player,
                                gameState: GameState,
                                portNodes: [(portName: String, position: CGPoint)],
                                blockedPorts: Set<Coordinate>) -> [VertexPoint: Double] {
        var scores: [VertexPoint: Double] = [:]
        for v in vertices where v.building == nil {
            if v.canBuildSettlement(for: player.id, checkConnectedRoad: gameState.currentPhase != .setup) {
                scores[v] = computeSettlementScore(for: v, player: player, gameState: gameState,
                                                   portNodes: portNodes, blockedPorts: blockedPorts)
            }
        }
        return scores
    }
    
    private func computeSettlementScore(for vertex: VertexPoint,
                                        player: Player,
                                        gameState: GameState,
                                        portNodes: [(portName: String, position: CGPoint)],
                                        blockedPorts: Set<Coordinate>) -> Double {
        var score = 0.0
        // Production
        for tile in vertex.adjacentHexes where tile.resourceType != .desert {
            if let value = tile.diceValue {
                score += productionWeight * productionProbability(for: value)
            }
        }
        // Diversity
        let types = Set(vertex.adjacentHexes.compactMap { $0.resourceType != .desert ? $0.resourceType : nil })
        score += diversityWeight * Double(types.count)
        // Port proximity
        if !blockedPorts.contains(Coordinate(x: vertex.position.x, y: vertex.position.y)) {
            for port in portNodes {
                let d = hypot(vertex.position.x - port.position.x, vertex.position.y - port.position.y)
                if d <= 70 { score += portProximityWeight; break }
            }
        }
        // Expansion
        score += expansionWeight
        // Missing resources
        let covered = player.settlements.reduce(into: Set<ResourceType>()) { set, s in
            for t in s.adjacentHexes where t.resourceType != .desert { set.insert(t.resourceType) }
        }
        let missing = types.subtracting(covered)
        score += missingResourceBonusWeight * Double(missing.count)
        return score
    }
    
    func chooseBestSettlement(from scores: [VertexPoint: Double]) -> VertexPoint? {
        return scores.max(by: { $0.value < $1.value })?.key
    }
    
    // MARK: - Road Placement
    func scoreRoadOptions(edges: [EdgePoint],
                          forPlayer player: Player,
                          gameState: GameState,
                          portNodes: [(portName: String, position: CGPoint)],
                          blockedPorts: Set<Coordinate>) -> [EdgePoint: Double] {
        var scores: [EdgePoint: Double] = [:]
        for e in edges where e.road == nil {
            if e.canBuildRoad(for: player.id, isSetupPhase: gameState.currentPhase == .setup) {
                scores[e] = computeRoadScore(for: e, player: player, gameState: gameState,
                                              portNodes: portNodes, blockedPorts: blockedPorts)
            }
        }
        return scores
    }
    
    private func computeRoadScore(for edge: EdgePoint,
                                  player: Player,
                                  gameState: GameState,
                                  portNodes: [(portName: String, position: CGPoint)],
                                  blockedPorts: Set<Coordinate>) -> Double {
        var score = 0.0
        // Extension
        for v in edge.vertices {
            if v.building == nil && v.canBuildSettlement(for: player.id, checkConnectedRoad: false) {
                score += roadExtensionWeight
            }
        }
        // Longest road
        if player.longestRoadLength < gameState.currentLongestRoadLength {
            score += longestRoadBonus
        }
        // Immediate settlement spot bonus
        let imm = edge.vertices.compactMap { v -> Double? in
            guard v.building == nil else { return nil }
            return computeSettlementScore(for: v, player: player, gameState: gameState,
                                          portNodes: portNodes, blockedPorts: blockedPorts)
        }.max() ?? 0
        score += imm * settlementAtRoadBonusWeight
        // Look-ahead
        let la = edge.vertices.map { lookAheadSettlementBonus(from: $0, forPlayer: player,
                                                              gameState: gameState, portNodes: portNodes,
                                                              maxDepth: lookAheadDepth, blockedPorts: blockedPorts) }
                                 .max() ?? 0
        score += la * pathLookAheadWeight
        return score
    }
    
    private func lookAheadSettlementBonus(from start: VertexPoint,
                                          forPlayer player: Player,
                                          gameState: GameState,
                                          portNodes: [(portName: String, position: CGPoint)],
                                          maxDepth: Int,
                                          blockedPorts: Set<Coordinate>) -> Double {
        var best: Double = 0
        var queue: [(VertexPoint, Int)] = [(start, 0)]
        var visited: Set<VertexPoint> = [start]
        while !queue.isEmpty {
            let (v, d) = queue.removeFirst()
            if d > 0 && v.building == nil && v.canBuildSettlement(for: player.id, checkConnectedRoad: false) {
                let sc = computeSettlementScore(for: v, player: player, gameState: gameState,
                                                portNodes: portNodes, blockedPorts: blockedPorts)
                best = max(best, sc / Double(d + 1))
            }
            if d < maxDepth {
                for e in v.adjacentEdges {
                    if let r = e.road, r.ownerId != player.id { continue }
                    for n in e.vertices where n !== v && !visited.contains(n) {
                        if let b = n.building, b.ownerId != player.id { continue }
                        visited.insert(n)
                        queue.append((n, d + 1))
                    }
                }
            }
        }
        return best
    }
    
    func chooseBestRoad(from scores: [EdgePoint: Double]) -> EdgePoint? {
        return scores.max(by: { $0.value < $1.value })?.key
    }
    
    // MARK: - Trade Decision
    struct TradeOffer {
        let offered: [ResourceType: Int]
        let requested: [ResourceType: Int]
    }
    
    private func tradeValue(for resource: ResourceType) -> Double {
        switch resource {
        case .wheat, .ore: return 1.2
        case .brick, .wood: return 1.0
        case .sheep: return 0.9
        case .desert: return 0
        }
    }
    
    func evaluateTradeOffer(offer: TradeOffer, forPlayer player: Player, gameState: GameState) -> Double {
        let out = offer.offered.reduce(0) { $0 + tradeValue(for: $1.key) * Double($1.value) }
        let req = offer.requested.reduce(0) { $0 + tradeValue(for: $1.key) * Double($1.value) }
        return tradeValueWeight * (req - out)
    }
    
    func chooseBestTradeOffer(offers: [TradeOffer], forPlayer player: Player, gameState: GameState) -> TradeOffer? {
        return offers.max(by: { evaluateTradeOffer(offer: $0, forPlayer: player, gameState: gameState) <
                                evaluateTradeOffer(offer: $1, forPlayer: player, gameState: gameState) })
    }
    
    // MARK: - Development Card Usage
    func decideDevelopmentCardUsage(forPlayer player: Player, gameState: GameState) -> DevelopmentCardType? {
        if let count = player.developmentCards[.knight], count > 0 {
            if gameState.players.filter({ $0.id != player.id }).contains(where: { $0.victoryPoints > player.victoryPoints }) {
                return .knight
            }
        }
        return nil
    }
    
    // MARK: - Robber Movement
    func chooseRobberDestination(from tiles: [Tile], forPlayer player: Player, gameState: GameState) -> Tile? {
        var best: (Tile, Double)?
        for t in tiles where !t.hasRobber && t.resourceType != .desert {
            if let dv = t.diceValue {
                let prod = productionProbability(for: dv)
                let opp = evaluateOpponentResourceNeed(for: t.resourceType, gameState: gameState, currentPlayer: player)
                let score = prod + opp
                if best == nil || score > best!.1 { best = (t, score) }
            }
        }
        return best?.0
    }
    
    private func evaluateOpponentResourceNeed(for resource: ResourceType, gameState: GameState, currentPlayer: Player) -> Double {
        return gameState.players.filter({ $0.id != currentPlayer.id }).reduce(0) { $0 + Double(($1.resources[resource] ?? 0) * Int(opponentResourceBonus)) }
    }
    
    // MARK: – Discard Decision
    
    func decideDiscard(forPlayer player: Player, discardLimit: Int) -> [ResourceType: Int] {
        var toDiscard: [ResourceType: Int] = [:]
        // Sort resource types by increasing trade value
        let sorted = ResourceType.allCases
            .filter { $0 != .desert }
            .sorted { tradeValue(for: $0) < tradeValue(for: $1) }

        var remaining = discardLimit
        for res in sorted {
            guard remaining > 0 else { break }
            let have = player.resources[res] ?? 0
            if have > 0 {
                let take = min(have, remaining)
                toDiscard[res] = take
                remaining -= take
            }
        }
        return toDiscard
    }
    
    // MARK: - High-Level Turn Decision
    func decideNextMove(for player: Player,
                        gameState: GameState,
                        vertices: [VertexPoint],
                        edges: [EdgePoint],
                        tiles: [Tile],
                        tradeOffers: [TradeOffer],
                        portNodes: [(portName: String, position: CGPoint)],
                        blockedPorts: Set<Coordinate>) -> BotDecision {
        // Roll dice phase handled externally
        if gameState.currentPhase == .setup {
            // Initial placements done elsewhere
            return .endTurn
        }
        // Settlement
        if player.canBuild(buildingType: .settlement) {
            let sScores = scoreSettlementOptions(vertices: vertices, forPlayer: player, gameState: gameState,
                                                 portNodes: portNodes, blockedPorts: blockedPorts)
            if let best = chooseBestSettlement(from: sScores) {
                return .buildSettlement(at: best)
            }
        }
        // City upgrade
        if player.canBuild(buildingType: .city) {
            let upgrade = player.settlements.max(by: { v1, v2 in
                computeSettlementScore(for: v1, player: player, gameState: gameState,
                                        portNodes: portNodes, blockedPorts: blockedPorts) <
                computeSettlementScore(for: v2, player: player, gameState: gameState,
                                        portNodes: portNodes, blockedPorts: blockedPorts) })
            if let up = upgrade { return .upgradeCity(at: up) }
        }
        // Road
        if player.shouldBuildRoad(gameState: gameState) {
            let rScores = scoreRoadOptions(edges: edges, forPlayer: player, gameState: gameState,
                                           portNodes: portNodes, blockedPorts: blockedPorts)
            if let best = chooseBestRoad(from: rScores) { return .buildRoad(at: best) }
        }
        // Development Card
        if let card = decideDevelopmentCardUsage(forPlayer: player, gameState: gameState) {
            return .playDevelopmentCard(type: card)
        }
        // Trade
        if let offer = chooseBestTradeOffer(offers: tradeOffers, forPlayer: player, gameState: gameState) {
            return .acceptTrade(offer: offer)
        }
        // Robber (if stealing phase)
        if gameState.currentDiceRoll == 7 {
            if let tile = chooseRobberDestination(from: tiles, forPlayer: player, gameState: gameState) {
                return .moveRobber(to: tile)
            }
        }
        return .endTurn
    }
}
