# Catan Multiplayer Server

WebSocket server for the Catan iOS multiplayer game.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Start the server:
```bash
npm start
```

For development with auto-reload:
```bash
npm run dev
```

## Server Endpoints

### HTTP Endpoints
- `GET /health` - Server health check
- `POST /api/lobby/create` - Create a new game lobby
- `GET /api/lobby/list` - List available public lobbies
- `GET /api/lobby/:code` - Get specific lobby info

### WebSocket Events

#### Client → Server
- `join-room` - Join a game room
- `player-ready` - Toggle ready status
- `start-game` - Start the game (host only)
- `game-action` - Send game action (dice roll, build, trade, etc.)
- `chat-message` - Send chat message
- `disconnect` - Leave the game
- `reconnect` - Reconnect to game

#### Server → Client
- `player-joined` - New player joined room
- `player-ready-changed` - Player ready status changed
- `game-started` - Game has started
- `game-action` - Game action from another player
- `chat-message` - Chat message from another player
- `player-disconnected` - Player disconnected
- `player-reconnected` - Player reconnected
- `game-ended` - Game has ended
- `error` - Error message

## Architecture

### Core Components

1. **RoomManager** - Manages game lobbies
   - Create/join/leave rooms
   - Track room states
   - Handle room cleanup

2. **GameManager** - Manages game logic
   - Process game actions
   - Validate moves
   - Track game state
   - Determine winners

3. **GameState** - Game state representation
   - Player resources and buildings
   - Board state
   - Turn management
   - Victory conditions

4. **GameValidator** - Validates game actions
   - Check turn order
   - Validate resources
   - Enforce game rules
   - Prevent cheating

## Development

### Environment Variables
Create a `.env` file:
```
PORT=3000
NODE_ENV=development
```

### Testing with iOS App

1. Start the server locally
2. In iOS app, update `NetworkManager.swift`:
   - Change server URL to `ws://localhost:3000/game`
   - For device testing, use your machine's IP: `ws://YOUR_IP:3000/game`

### Deployment

For production deployment:

1. Set up a cloud server (AWS EC2, Heroku, DigitalOcean)
2. Install Node.js and npm
3. Clone the repository
4. Install dependencies
5. Set up environment variables
6. Use PM2 or similar for process management
7. Set up nginx for reverse proxy
8. Configure SSL certificates

## Game Flow

1. **Lobby Phase**
   - Host creates room
   - Players join with room code
   - Players ready up
   - Host starts game

2. **Setup Phase**
   - Initial settlement placement
   - Initial road placement
   - Reverse order second placement

3. **Main Game**
   - Roll dice
   - Collect resources
   - Build roads/settlements/cities
   - Trade with players/bank
   - Play development cards
   - End turn

4. **End Game**
   - Player reaches victory points
   - Game ends
   - Stats recorded

## Troubleshooting

### Connection Issues
- Check firewall settings
- Verify server is running
- Check client WebSocket URL
- Enable CORS if needed

### Game State Issues
- Server maintains authoritative state
- Client actions are validated
- Invalid actions are rejected
- State syncs on reconnection

## Future Enhancements

- [ ] User authentication system
- [ ] Persistent game storage
- [ ] Spectator mode
- [ ] Tournament system
- [ ] Advanced statistics
- [ ] Voice chat integration
- [ ] Push notifications
- [ ] Anti-cheat measures