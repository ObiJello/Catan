import Foundation
import SpriteKit

struct HexCoord: Hashable {
    let q: Int
    let r: Int
    
    // Derived coordinate (q + r + s = 0)
    var s: Int {
        return -q - r
    }
    
    /* Add equality check
    static func == (lhs: HexCoord, rhs: HexCoord) -> Bool {
        return lhs.q == rhs.q && lhs.r == rhs.r
    }*/
}

class HexGrid {
    let size: Int
    let hexRadius: CGFloat
    
    init(size: Int, hexRadius: CGFloat) {
        self.size = size
        self.hexRadius = hexRadius
    }
    
    // Convert hex coordinates to pixel coordinates
    func hexToPixel(hex: HexCoord) -> CGPoint {
        let q = CGFloat(hex.q)
        let r = CGFloat(hex.r)
        let x = hexRadius * sqrt(3) * (q + r/2)
        let y = hexRadius * (3/2) * r
        return CGPoint(x: x, y: y)
    }

    
    // Generate all hex coordinates for a given board size
    func generateHexCoords(for layer: Int) -> [HexCoord] {
        var coords: [HexCoord] = []
        for q in -layer...layer {
            let r1 = max(-layer, -q - layer)
            let r2 = min(layer, -q + layer)
            for r in r1...r2 {
                coords.append(HexCoord(q: q, r: r))
            }
        }
        return coords
    }
    
    func generateBoardPoints(from tiles: [Tile]) -> (vertices: [VertexPoint], edges: [EdgePoint]) {
        var verticesByPosition: [String: VertexPoint] = [:]
        var edgesByPosition: [String: EdgePoint] = [:]
        
        // For each tile, calculate its vertices and edges
        for tile in tiles {
            let tileVertices = calculateTileVertices(for: tile.position)
            let tileEdges = calculateTileEdges(for: tileVertices)
            
            // Create vertex points, reusing existing ones if already created
            for vertexPosition in tileVertices {
                let key = "\(Int(vertexPosition.x))_\(Int(vertexPosition.y))"
                
                if verticesByPosition[key] == nil {
                    let newVertex = VertexPoint(position: vertexPosition)
                    newVertex.adjacentHexes.append(tile)
                    verticesByPosition[key] = newVertex
                } else {
                    verticesByPosition[key]?.adjacentHexes.append(tile)
                }
            }
            
            // Create edge points, reusing existing ones if already created
            for edgePosition in tileEdges.positions {
                let key = "\(Int(edgePosition.x))_\(Int(edgePosition.y))"
                if edgesByPosition[key] == nil {
                    let newEdge = EdgePoint(position: edgePosition)
                    edgesByPosition[key] = newEdge
                }
            }
            
            // Link vertices and edges
            for (edgeIndex, edgePosition) in tileEdges.positions.enumerated() {
                let edgeKey = "\(Int(edgePosition.x))_\(Int(edgePosition.y))"
                guard let edge = edgesByPosition[edgeKey] else { continue }
                
                // Connect to the two vertices at each end of this edge
                let v1Index = tileEdges.connections[edgeIndex].0
                let v2Index = tileEdges.connections[edgeIndex].1
                
                let v1Position = tileVertices[v1Index]
                let v2Position = tileVertices[v2Index]
                
                let v1Key = "\(Int(v1Position.x))_\(Int(v1Position.y))"
                let v2Key = "\(Int(v2Position.x))_\(Int(v2Position.y))"
                
                guard let vertex1 = verticesByPosition[v1Key],
                      let vertex2 = verticesByPosition[v2Key] else { continue }
                
                if !edge.vertices.contains(where: { $0 === vertex1 }) {
                    edge.vertices.append(vertex1)
                }
                if !edge.vertices.contains(where: { $0 === vertex2 }) {
                    edge.vertices.append(vertex2)
                }
                
                if !vertex1.adjacentEdges.contains(where: { $0 === edge }) {
                    vertex1.adjacentEdges.append(edge)
                }
                if !vertex2.adjacentEdges.contains(where: { $0 === edge }) {
                    vertex2.adjacentEdges.append(edge)
                }
            }
        }
        
        return (Array(verticesByPosition.values), Array(edgesByPosition.values))
    }
    
    // In HexGrid.swift
    func generateTilePoints(from tiles: [Tile]) -> [TilePoint] {
        return tiles.map { TilePoint(tile: $0) }
    }
    
    private func calculateTileVertices(for tilePosition: CGPoint) -> [CGPoint] {
        var vertices: [CGPoint] = []
        let angleOffset = CGFloat.pi / 6.0  // Rotate for pointy-top orientation
        for i in 0..<6 {
            let angle = angleOffset + CGFloat(i) * CGFloat.pi / 3.0
            let x = tilePosition.x + hexRadius * cos(angle)
            let y = tilePosition.y + hexRadius * sin(angle)
            let roundedX = round(x * 10) / 10
            let roundedY = round(y * 10) / 10
            vertices.append(CGPoint(x: roundedX, y: roundedY))
        }
        return vertices
    }

    
    private func calculateTileEdges(for vertices: [CGPoint]) -> (positions: [CGPoint], connections: [(Int, Int)]) {
        var edgePositions: [CGPoint] = []
        var edgeConnections: [(Int, Int)] = []
        
        // For each adjacent pair of vertices, create an edge at the midpoint
        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            let startVertex = vertices[i]
            let endVertex = vertices[j]
            let midpoint = CGPoint(
                x: (startVertex.x + endVertex.x) / 2.0,
                y: (startVertex.y + endVertex.y) / 2.0
            )
            edgePositions.append(midpoint)
            edgeConnections.append((i, j))
        }
        
        return (positions: edgePositions, connections: edgeConnections)
    }
}

extension Tile {
    var tokenProbability: Double {
        guard let diceValue = diceValue else { return 0 }
        let probabilities: [Int: Double] = [
            2: 1/36.0, 3: 2/36.0, 4: 3/36.0, 5: 4/36.0,
            6: 5/36.0, 8: 5/36.0, 9: 4/36.0, 10: 3/36.0,
            11: 2/36.0, 12: 1/36.0
        ]
        return probabilities[diceValue] ?? 0
    }
}

extension VertexPoint {
    func settlementScore(for playerId: Int) -> Double {
        // Prevent invalid placements
        guard canBuildSettlement(for: playerId, checkConnectedRoad: false) else { return -1 }
        
        var score = 0.0
        var resourceTypes = Set<ResourceType>()
        
        for tile in adjacentHexes {
            // Skip desert tiles
            guard tile.resourceType != .desert else { continue }
            
            // Add probability value
            score += tile.tokenProbability * 100 // Scale up for easier math
            
            // Track resource diversity
            resourceTypes.insert(tile.resourceType)
        }
        
        // Bonus for resource diversity
        let diversityBonus = Double(resourceTypes.count) * 15
        score += diversityBonus
        
        // Penalize adjacency to existing settlements
        for edge in adjacentEdges {
            for vertex in edge.vertices {
                if vertex.building != nil {
                    score -= 30
                }
            }
        }
        
        return score
    }
}
