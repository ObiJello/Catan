const Room = require('./Room');

class RoomManager {
  constructor() {
    this.rooms = new Map();
  }

  createRoom(hostId, settings = {}) {
    // Use provided room code if available, otherwise generate new one
    const room = new Room(hostId, settings);
    if (settings.roomCode) {
      room.code = settings.roomCode;
    }
    this.rooms.set(room.code, room);
    console.log(`Room created: ${room.code} by host ${hostId}`);
    return room;
  }

  getRoom(code) {
    return this.rooms.get(code);
  }

  removeRoom(code) {
    const deleted = this.rooms.delete(code);
    if (deleted) {
      console.log(`Room removed: ${code}`);
    }
    return deleted;
  }

  getPublicRooms() {
    const publicRooms = [];
    this.rooms.forEach((room, code) => {
      if (!room.isPrivate && !room.isInGame() && !room.isFull()) {
        publicRooms.push({
          code: code,
          hostName: room.getHost()?.name || 'Unknown',
          playerCount: room.getPlayerCount(),
          maxPlayers: room.maxPlayers,
          settings: room.settings
        });
      }
    });
    return publicRooms;
  }

  getAllRooms() {
    const allRooms = [];
    this.rooms.forEach((room, code) => {
      allRooms.push({
        code: code,
        playerCount: room.getPlayerCount(),
        status: room.getStatus(),
        created: room.createdAt
      });
    });
    return allRooms;
  }

  getRoomsByPlayer(playerId) {
    const playerRooms = [];
    this.rooms.forEach((room, code) => {
      if (room.hasPlayer(playerId)) {
        playerRooms.push(code);
      }
    });
    return playerRooms;
  }

  cleanup() {
    // Remove empty rooms or rooms that have been idle for too long
    const now = Date.now();
    const maxIdleTime = 30 * 60 * 1000; // 30 minutes

    this.rooms.forEach((room, code) => {
      if (room.isEmpty() || (now - room.lastActivity > maxIdleTime && !room.isInGame())) {
        this.removeRoom(code);
      }
    });
  }
}

module.exports = RoomManager;