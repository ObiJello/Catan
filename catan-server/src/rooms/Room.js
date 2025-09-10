const { v4: uuidv4 } = require('uuid');

class Room {
  constructor(hostId, settings = {}) {
    this.code = this.generateRoomCode();
    this.hostId = hostId;
    this.players = new Map();
    this.maxPlayers = settings.maxPlayers || 4;
    this.isPrivate = settings.isPrivate || false;
    this.settings = {
      victoryPoints: settings.victoryPoints || 10,
      discardLimit: settings.discardLimit || 7,
      ...settings
    };
    this.status = 'waiting'; // waiting, ready, in-game, ended
    this.createdAt = Date.now();
    this.lastActivity = Date.now();
    this.gameStartedAt = null;
  }

  generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  }

  addPlayer(player) {
    if (this.players.size >= this.maxPlayers) {
      return false;
    }

    this.players.set(player.id, {
      ...player,
      joinedAt: Date.now(),
      isReady: false,
      color: this.getAvailableColor()
    });

    this.updateActivity();
    return true;
  }

  removePlayer(playerId) {
    const removed = this.players.delete(playerId);
    
    // If host left, assign new host
    if (removed && playerId === this.hostId && this.players.size > 0) {
      const newHost = this.players.values().next().value;
      this.hostId = newHost.id;
      newHost.isHost = true;
    }

    this.updateActivity();
    return removed;
  }

  getPlayer(playerId) {
    return this.players.get(playerId);
  }

  hasPlayer(playerId) {
    return this.players.has(playerId);
  }

  getPlayers() {
    return Array.from(this.players.values());
  }

  getPlayerCount() {
    return this.players.size;
  }

  getHost() {
    return this.players.get(this.hostId);
  }

  setPlayerReady(playerId, isReady) {
    const player = this.players.get(playerId);
    if (player) {
      player.isReady = isReady;
      this.updateActivity();
      this.checkReadyStatus();
    }
  }

  checkReadyStatus() {
    if (this.players.size < 2) {
      this.status = 'waiting';
      return;
    }

    const allReady = Array.from(this.players.values()).every(p => p.isReady);
    this.status = allReady ? 'ready' : 'waiting';
  }

  canStart() {
    return this.status === 'ready' && this.players.size >= 2;
  }

  startGame() {
    this.status = 'in-game';
    this.gameStartedAt = Date.now();
    this.updateActivity();
  }

  endGame() {
    this.status = 'ended';
    this.updateActivity();
  }

  isInGame() {
    return this.status === 'in-game';
  }

  isEmpty() {
    return this.players.size === 0;
  }

  isFull() {
    return this.players.size >= this.maxPlayers;
  }

  getStatus() {
    return this.status;
  }

  updateActivity() {
    this.lastActivity = Date.now();
  }

  getAvailableColor() {
    const colors = ['red', 'blue', 'green', 'orange', 'white', 'brown'];
    const usedColors = new Set(Array.from(this.players.values()).map(p => p.color));
    
    for (const color of colors) {
      if (!usedColors.has(color)) {
        return color;
      }
    }
    return colors[0]; // Fallback
  }

  getState() {
    return {
      code: this.code,
      hostId: this.hostId,
      players: this.getPlayers(),
      settings: this.settings,
      status: this.status,
      maxPlayers: this.maxPlayers
    };
  }

  getInfo() {
    return {
      code: this.code,
      hostName: this.getHost()?.name || 'Unknown',
      playerCount: this.getPlayerCount(),
      maxPlayers: this.maxPlayers,
      status: this.status,
      settings: this.settings,
      isPrivate: this.isPrivate,
      createdAt: this.createdAt
    };
  }
}

module.exports = Room;