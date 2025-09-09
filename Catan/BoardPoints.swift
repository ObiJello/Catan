import Foundation
import SpriteKit

// Represents a vertex point where settlements/cities can be built
class VertexPoint {
    let position: CGPoint
    var building: Building?
    var adjacentHexes: [Tile] = []
    var adjacentEdges: [EdgePoint] = []
    
    init(position: CGPoint) {
        self.position = position
    }
    
    func canBuildSettlement(for playerID: Int, checkConnectedRoad: Bool) -> Bool {
        // No existing building
        guard building == nil else { return false }
        
        // Check distance rule - no adjacent buildings
        for edge in adjacentEdges {
            for vertex in edge.vertices {
                if vertex !== self && vertex.building != nil {
                    return false
                }
            }
        }
        
        // Check if player has a connected road (not needed in setup phase)
        if checkConnectedRoad {
            let hasConnectedRoad = adjacentEdges.contains { edge in
                return edge.road?.ownerId == playerID
            }
            if !hasConnectedRoad {
                return false
            }
        }
        
        return true
    }
}
extension VertexPoint: Hashable {
    public static func == (lhs: VertexPoint, rhs: VertexPoint) -> Bool {
        return lhs.position == rhs.position
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(position.x)
        hasher.combine(position.y)
    }
}

// Represents an edge point where roads can be built
class EdgePoint: Hashable {
    let position: CGPoint
    var road: Building?
    var vertices: [VertexPoint] = []
    
    init(position: CGPoint) {
        self.position = position
    }
    
    // Hashable conformance
    static func == (lhs: EdgePoint, rhs: EdgePoint) -> Bool {
        return lhs.position.x == rhs.position.x &&
               lhs.position.y == rhs.position.y
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(position.x)
        hasher.combine(position.y)
    }
    
    func canBuildRoad(for playerID: Int, isSetupPhase: Bool) -> Bool {
        guard road == nil else { return false }
        
        // Count opponent buildings on this edge's vertices.
        // (If both vertices host an opponent building, block road building.)
        let opponentBuildingCount = vertices.filter {
            if let owner = $0.building?.ownerId {
                return owner != playerID
            }
            return false
        }.count
        guard opponentBuildingCount < 2 else { return false }
        
        if isSetupPhase {
            // In setup phase, only allow if a vertex has your own settlement.
            return vertices.contains { vertex in
                vertex.building?.ownerId == playerID
            }
        }
        
        // Normal gameplay:
        // Allow building a road if at least one vertex is:
        // • Either directly your own settlement
        // • Or an empty vertex connected (via an adjacent road) to your road network.
        // Note: A vertex with an opponent settlement is skipped so it won't serve as a connecting point.
        return vertices.contains { vertex in
            if let building = vertex.building {
                // Only consider it a valid connection if it’s yours.
                return building.ownerId == playerID
            } else {
                // Check if an adjacent edge already has your road.
                return vertex.adjacentEdges.contains { edge in
                    edge.road?.ownerId == playerID
                }
            }
        }
    }
}

class TilePoint {
    let position: CGPoint
    let tile: Tile

    init(tile: Tile) {
        self.tile = tile
        self.position = tile.position
    }
}
