# Catan Multiplayer Setup Guide

## Quick Start

### Step 1: Start the Server

1. Open Terminal and navigate to the server directory:
```bash
cd catan-server
```

2. Install dependencies (first time only):
```bash
npm install
```

3. Start the server:
```bash
npm start
```

You should see:
```
Catan server running on port 3000
WebSocket endpoint: ws://localhost:3000
HTTP endpoint: http://localhost:3000
```

### Step 2: Run the iOS App

1. Open `Catan.xcodeproj` in Xcode
2. Select your simulator or device
3. Build and run (⌘R)

### Step 3: Test Multiplayer

1. In the app, tap "Multiplayer" on the title screen
2. Create a profile (optional)
3. Tap "Create Lobby" to host a game
4. Note the 6-character lobby code
5. On another simulator/device:
   - Tap "Join Lobby"
   - Enter the lobby code
   - Join the game
6. Start the game when all players are ready

## Testing on Multiple Simulators

1. In Xcode, select a different simulator
2. Build and run to launch second instance
3. Both simulators can connect to `localhost:3000`

## Testing on Real Devices

1. Find your computer's IP address:
   - Mac: System Preferences → Network → Your IP
   - Or run: `ifconfig | grep "inet "`

2. Update `NetworkManager.swift`:
```swift
// Change this line:
private let serverURL = "ws://localhost:3000"
// To your IP:
private let serverURL = "ws://192.168.1.100:3000"  // Replace with your IP
```

3. Make sure devices are on same WiFi network
4. Build and run on devices

## Server Commands

### Development Mode (auto-restart on changes)
```bash
npm run dev
```

### Check Server Health
```bash
curl http://localhost:3000/health
```

### View Available Lobbies
```bash
curl http://localhost:3000/api/lobby/list
```

## Troubleshooting

### Server Issues

**Port already in use:**
```bash
# Find process using port 3000
lsof -i :3000
# Kill the process
kill -9 <PID>
```

**Dependencies not installed:**
```bash
cd catan-server
rm -rf node_modules package-lock.json
npm install
```

### iOS App Issues

**Can't connect to server:**
1. Check server is running
2. Check URL in NetworkManager.swift
3. For devices, check IP address
4. Check firewall settings

**Multiplayer button doesn't work:**
1. Clean build folder (⌘⇧K)
2. Delete app from simulator
3. Rebuild

### Network Issues

**Allow incoming connections:**
- Mac: System Preferences → Security & Privacy → Firewall → Firewall Options
- Add Terminal or Node.js to allowed apps

**Test WebSocket connection:**
```bash
# Install wscat
npm install -g wscat

# Test connection
wscat -c ws://localhost:3000
```

## Features Working

✅ Lobby creation and joining
✅ Player ready system
✅ Color selection
✅ Game settings (victory points, discard limit)
✅ Real-time player updates
✅ Chat system (UI ready)
✅ Friend system (local storage)
✅ Profile management

## Features In Progress

🚧 Full game synchronization
🚧 Dice rolls and resource distribution
🚧 Building placement sync
🚧 Trading between players
🚧 Development cards
🚧 Win conditions

## Next Steps

1. **Complete Game Logic Sync**
   - Implement all game actions in server
   - Add proper validation
   - Handle edge cases

2. **Add Authentication**
   - User accounts
   - Persistent profiles
   - Friend system backend

3. **Production Deployment**
   - Deploy server to cloud
   - Set up database
   - Configure SSL
   - Update iOS app with production URL

## Development Tips

### Monitor Server Logs
The server logs all connections and game actions. Keep the terminal open to see activity.

### Test Different Scenarios
- Player disconnection/reconnection
- Host leaving game
- Network interruptions
- Invalid game moves

### Debug WebSocket Messages
In Xcode console, you'll see WebSocket activity. Enable verbose logging in NetworkManager if needed.

## Support

For issues or questions:
1. Check server logs for errors
2. Check Xcode console for client errors
3. Verify network connectivity
4. Review this guide

Happy gaming! 🎲