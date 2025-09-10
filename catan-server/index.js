const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
require('dotenv').config();

const RoomManager = require('./src/rooms/RoomManager');
const GameManager = require('./src/game/GameManager');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// Managers
const roomManager = new RoomManager();
const gameManager = new GameManager(roomManager);

// REST API Routes
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.post('/api/lobby/create', (req, res) => {
  const { hostId, roomCode, settings } = req.body;
  // Include roomCode in settings if provided
  if (roomCode) {
    settings.roomCode = roomCode;
  }
  const room = roomManager.createRoom(hostId, settings);
  res.json({ success: true, roomCode: room.code });
});

app.get('/api/lobby/list', (req, res) => {
  const publicRooms = roomManager.getPublicRooms();
  res.json({ rooms: publicRooms });
});

app.get('/api/lobby/:code', (req, res) => {
  const room = roomManager.getRoom(req.params.code);
  if (room) {
    res.json({ success: true, room: room.getInfo() });
  } else {
    res.status(404).json({ success: false, error: 'Room not found' });
  }
});

// WebSocket handling
io.on('connection', (socket) => {
  console.log('New client connected:', socket.id);

  // Handle player joining a room
  socket.on('join-room', (data) => {
    const { roomCode, playerId, playerName, isHost } = data;
    
    const room = roomManager.getRoom(roomCode);
    if (!room) {
      socket.emit('error', { message: 'Room not found' });
      return;
    }

    // Add player to room
    const player = {
      id: playerId,
      socketId: socket.id,
      name: playerName,
      isHost: isHost,
      isReady: false
    };

    if (room.addPlayer(player)) {
      socket.join(roomCode);
      socket.data.roomCode = roomCode;
      socket.data.playerId = playerId;

      // Notify all players in room
      io.to(roomCode).emit('player-joined', {
        player: player,
        players: room.getPlayers()
      });

      // Send current room state to joining player
      socket.emit('room-state', room.getState());
    } else {
      socket.emit('error', { message: 'Room is full' });
    }
  });

  // Handle player ready status
  socket.on('player-ready', (data) => {
    const { roomCode, playerId, isReady } = data;
    const room = roomManager.getRoom(roomCode);
    
    if (room) {
      room.setPlayerReady(playerId, isReady);
      io.to(roomCode).emit('player-ready-changed', {
        playerId: playerId,
        isReady: isReady,
        players: room.getPlayers()
      });
    }
  });

  // Handle game start
  socket.on('start-game', (data) => {
    const { roomCode } = data;
    const room = roomManager.getRoom(roomCode);
    
    if (room && room.canStart()) {
      const gameState = gameManager.createGame(roomCode, room.getPlayers());
      room.startGame();
      
      io.to(roomCode).emit('game-started', {
        gameState: gameState,
        players: room.getPlayers()
      });
    } else {
      socket.emit('error', { message: 'Cannot start game yet' });
    }
  });

  // Handle game actions
  socket.on('game-action', (data) => {
    const { roomCode, action } = data;
    const room = roomManager.getRoom(roomCode);
    
    if (room && room.isInGame()) {
      // Validate and process game action
      const result = gameManager.processAction(roomCode, action);
      
      if (result.success) {
        // Broadcast action to all players
        io.to(roomCode).emit('game-action', {
          action: action,
          gameState: result.gameState
        });

        // Check for game end
        if (result.gameEnded) {
          io.to(roomCode).emit('game-ended', {
            winner: result.winner,
            finalState: result.gameState
          });
          room.endGame();
        }
      } else {
        socket.emit('error', { message: result.error });
      }
    }
  });

  // Handle chat messages
  socket.on('chat-message', (data) => {
    const { roomCode, message } = data;
    const playerId = socket.data.playerId;
    
    io.to(roomCode).emit('chat-message', {
      playerId: playerId,
      message: message,
      timestamp: new Date().toISOString()
    });
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
    
    const roomCode = socket.data.roomCode;
    const playerId = socket.data.playerId;
    
    if (roomCode && playerId) {
      const room = roomManager.getRoom(roomCode);
      if (room) {
        room.removePlayer(playerId);
        
        // Notify other players
        io.to(roomCode).emit('player-disconnected', {
          playerId: playerId,
          players: room.getPlayers()
        });

        // Clean up empty rooms
        if (room.isEmpty()) {
          roomManager.removeRoom(roomCode);
        }
      }
    }
  });

  // Handle reconnection
  socket.on('reconnect', (data) => {
    const { roomCode, playerId } = data;
    const room = roomManager.getRoom(roomCode);
    
    if (room) {
      const player = room.getPlayer(playerId);
      if (player) {
        player.socketId = socket.id;
        socket.join(roomCode);
        socket.data.roomCode = roomCode;
        socket.data.playerId = playerId;
        
        socket.emit('reconnected', {
          room: room.getState(),
          gameState: gameManager.getGameState(roomCode)
        });
        
        io.to(roomCode).emit('player-reconnected', {
          playerId: playerId
        });
      }
    }
  });
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Catan server running on port ${PORT}`);
  console.log(`WebSocket endpoint: ws://localhost:${PORT}`);
  console.log(`HTTP endpoint: http://localhost:${PORT}`);
});