# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a iOS/SpriteKit implementation of Catan (board game) written in Swift. The app consists of a title screen, game configuration screen, and the main game scene with hexagonal board, resource management, building placement, and bot AI.

## Architecture

### Key Components
- **GameScene.swift**: Main game controller handling the board display, user interactions, dice rolling, building placement, and turn management
- **GameConfigScene.swift**: Player setup screen for selecting colors and game parameters (victory points, discard limit)
- **TitleScene.swift**: Initial menu screen for choosing singleplayer/multiplayer modes
- **Models.swift**: Core data structures including Player, Tile, Building, GameBoard, and resource/development card types
- **GameState.swift**: Turn management, phase tracking, and game flow logic
- **BotDecisionEngine.swift**: AI logic for bot players making trading, building, and development card decisions
- **HexGrid.swift**: Hexagonal coordinate system and pixel conversion utilities
- **BoardPoints.swift**: Vertex and edge management for the hex grid, used for building placement
- **Bank.swift**: Resource and development card bank management

### Game Flow
1. TitleScene → GameConfigScene → GameScene
2. Players take turns in phases: roll dice → main actions (build/trade/cards) → end turn
3. Victory conditions checked after each action (default: 10 victory points)

## Development Commands

### Build & Run
```bash
# Build the project
xcodebuild -project Catan.xcodeproj -scheme Catan -configuration Debug build

# Run on iOS Simulator
open -a Simulator
xcodebuild -project Catan.xcodeproj -scheme Catan -destination 'platform=iOS Simulator,name=iPhone 15' build-for-testing
```

### Testing
```bash
# Run all tests
xcodebuild test -project Catan.xcodeproj -scheme Catan -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -project Catan.xcodeproj -scheme Catan -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:CatanTests/CatanTests/testName
```

### Clean Build
```bash
xcodebuild clean -project Catan.xcodeproj -scheme Catan
```

## Key Implementation Details

### Coordinate Systems
- Uses axial hex coordinates (q, r) with constraint q + r + s = 0
- Vertices stored as VertexPoint with position and adjacent tiles
- Edges stored as EdgePoint connecting two vertices
- Port locations mapped to specific board edge coordinates

### Asset Naming Convention
- Building sprites: `{color}_{type}` (e.g., "blue_settlement", "red_road")
- Resource cards: `{resource}_card` (e.g., "wood_card", "brick_card")
- Development cards: `{type}_card` (e.g., "knight_card", "monopoly_card")
- Dice: `dice_{number}` (1-6)
- Tiles: `{resource}_tile` (e.g., "wood_tile", "desert_tile")

### Turn Phases
- **Rolling**: Waiting for dice roll
- **Main**: Building, trading, playing development cards
- **Discard**: When 7 is rolled and players have >7 cards
- **MoveRobber**: After rolling 7 or playing knight card

### Port Types
- 0: Generic 3:1 port
- 1-5: Resource-specific 2:1 ports (clay, sheep, wheat, ore, wood)