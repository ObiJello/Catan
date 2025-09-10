const GameState = require('./GameState');
const GameValidator = require('./GameValidator');

class GameManager {
  constructor(roomManager) {
    this.roomManager = roomManager;
    this.games = new Map();
    this.validator = new GameValidator();
  }

  createGame(roomCode, players) {
    const gameState = new GameState(roomCode, players);
    this.games.set(roomCode, gameState);
    
    console.log(`Game created for room ${roomCode} with ${players.length} players`);
    return gameState.getPublicState();
  }

  getGameState(roomCode) {
    const game = this.games.get(roomCode);
    return game ? game.getPublicState() : null;
  }

  processAction(roomCode, action) {
    const game = this.games.get(roomCode);
    
    if (!game) {
      return { success: false, error: 'Game not found' };
    }

    // Validate action
    const validation = this.validator.validateAction(game, action);
    if (!validation.valid) {
      return { success: false, error: validation.error };
    }

    // Process action based on type
    let result;
    switch (action.type) {
      case 'diceRoll':
        result = this.processDiceRoll(game, action);
        break;
      case 'buildRoad':
        result = this.processBuildRoad(game, action);
        break;
      case 'buildSettlement':
        result = this.processBuildSettlement(game, action);
        break;
      case 'buildCity':
        result = this.processBuildCity(game, action);
        break;
      case 'trade':
        result = this.processTrade(game, action);
        break;
      case 'playDevelopmentCard':
        result = this.processPlayCard(game, action);
        break;
      case 'moveRobber':
        result = this.processMoveRobber(game, action);
        break;
      case 'endTurn':
        result = this.processEndTurn(game, action);
        break;
      default:
        result = { success: false, error: 'Unknown action type' };
    }

    if (result.success) {
      // Check for game end
      const winner = game.checkWinner();
      if (winner) {
        result.gameEnded = true;
        result.winner = winner;
        this.endGame(roomCode);
      }
      
      result.gameState = game.getPublicState();
    }

    return result;
  }

  processDiceRoll(game, action) {
    const { value1, value2 } = action.data;
    const total = value1 + value2;
    
    game.setDiceRoll(value1, value2);
    
    if (total === 7) {
      // Handle robber
      game.setPhase('moveRobber');
      
      // Check for discard
      const playersToDiscard = game.getPlayersToDiscard();
      if (playersToDiscard.length > 0) {
        game.setPhase('discard');
        return {
          success: true,
          requiresDiscard: true,
          playersToDiscard: playersToDiscard
        };
      }
    } else {
      // Distribute resources
      game.distributeResources(total);
    }
    
    return { success: true };
  }

  processBuildRoad(game, action) {
    const { playerId, from, to } = action.data;
    
    if (game.buildRoad(playerId, from, to)) {
      game.updateLongestRoad();
      return { success: true };
    }
    
    return { success: false, error: 'Cannot build road at this location' };
  }

  processBuildSettlement(game, action) {
    const { playerId, position } = action.data;
    
    if (game.buildSettlement(playerId, position)) {
      return { success: true };
    }
    
    return { success: false, error: 'Cannot build settlement at this location' };
  }

  processBuildCity(game, action) {
    const { playerId, position } = action.data;
    
    if (game.buildCity(playerId, position)) {
      return { success: true };
    }
    
    return { success: false, error: 'Cannot upgrade to city at this location' };
  }

  processTrade(game, action) {
    const { playerId, offering, requesting, targetPlayer } = action.data;
    
    if (targetPlayer) {
      // Player-to-player trade
      if (game.proposeT
(playerId, targetPlayer, offering, requesting)) {
        return { success: true, tradeProposed: true };
      }
    } else {
      // Bank trade
      if (game.tradeWithBank(playerId, offering, requesting)) {
        return { success: true };
      }
    }
    
    return { success: false, error: 'Invalid trade' };
  }

  processPlayCard(game, action) {
    const { playerId, cardType, cardData } = action.data;
    
    switch (cardType) {
      case 'knight':
        game.playKnight(playerId);
        game.setPhase('moveRobber');
        return { success: true, requiresRobberMove: true };
        
      case 'roadBuilding':
        game.playRoadBuilding(playerId);
        return { success: true, requiresRoadPlacement: 2 };
        
      case 'yearOfPlenty':
        return { success: true, requiresResourceSelection: 2 };
        
      case 'monopoly':
        const resource = cardData.resource;
        game.playMonopoly(playerId, resource);
        return { success: true };
        
      case 'victoryPoint':
        game.playVictoryPoint(playerId);
        return { success: true };
        
      default:
        return { success: false, error: 'Unknown card type' };
    }
  }

  processMoveRobber(game, action) {
    const { playerId, tilePosition, stealFrom } = action.data;
    
    if (game.moveRobber(tilePosition)) {
      if (stealFrom) {
        game.stealResource(playerId, stealFrom);
      }
      game.setPhase('main');
      return { success: true };
    }
    
    return { success: false, error: 'Invalid robber position' };
  }

  processEndTurn(game, action) {
    const { playerId } = action.data;
    
    if (game.getCurrentPlayer().id === playerId) {
      game.nextTurn();
      return { success: true };
    }
    
    return { success: false, error: 'Not your turn' };
  }

  endGame(roomCode) {
    const game = this.games.get(roomCode);
    if (game) {
      // Save game stats, update player records, etc.
      console.log(`Game ended for room ${roomCode}. Winner: ${game.getWinner()?.name}`);
      
      // Clean up after a delay
      setTimeout(() => {
        this.games.delete(roomCode);
      }, 5 * 60 * 1000); // Keep for 5 minutes for replay/stats
    }
  }

  cleanup() {
    // Remove games for rooms that no longer exist
    this.games.forEach((game, roomCode) => {
      if (!this.roomManager.getRoom(roomCode)) {
        this.games.delete(roomCode);
      }
    });
  }
}

module.exports = GameManager;