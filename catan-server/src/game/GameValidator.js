class GameValidator {
  validateAction(gameState, action) {
    // Check if it's the player's turn
    const currentPlayer = gameState.getCurrentPlayer();
    if (currentPlayer.id !== action.playerId) {
      return { valid: false, error: 'Not your turn' };
    }

    // Validate based on current phase
    switch (gameState.phase) {
      case 'setup':
        return this.validateSetupAction(gameState, action);
      
      case 'rolling':
        if (action.type !== 'diceRoll') {
          return { valid: false, error: 'Must roll dice first' };
        }
        return { valid: true };
      
      case 'main':
        return this.validateMainPhaseAction(gameState, action);
      
      case 'discard':
        if (action.type !== 'discard') {
          return { valid: false, error: 'Must discard cards' };
        }
        return this.validateDiscard(gameState, action);
      
      case 'moveRobber':
        if (action.type !== 'moveRobber') {
          return { valid: false, error: 'Must move the robber' };
        }
        return this.validateRobberMove(gameState, action);
      
      case 'trading':
        return this.validateTradeAction(gameState, action);
      
      default:
        return { valid: false, error: 'Invalid game phase' };
    }
  }

  validateSetupAction(gameState, action) {
    // During setup, players can only place initial settlements and roads
    if (action.type === 'buildSettlement' || action.type === 'buildRoad') {
      // Check if it's free placement (setup phase)
      return { valid: true };
    }
    return { valid: false, error: 'Invalid action during setup' };
  }

  validateMainPhaseAction(gameState, action) {
    const validActions = [
      'buildRoad', 'buildSettlement', 'buildCity',
      'trade', 'playDevelopmentCard', 'endTurn'
    ];

    if (!validActions.includes(action.type)) {
      return { valid: false, error: 'Invalid action for main phase' };
    }

    // Validate specific action
    switch (action.type) {
      case 'buildRoad':
        return this.validateRoadBuilding(gameState, action);
      case 'buildSettlement':
        return this.validateSettlementBuilding(gameState, action);
      case 'buildCity':
        return this.validateCityBuilding(gameState, action);
      case 'trade':
        return this.validateTrade(gameState, action);
      case 'playDevelopmentCard':
        return this.validateCardPlay(gameState, action);
      case 'endTurn':
        return { valid: true };
      default:
        return { valid: false, error: 'Unknown action' };
    }
  }

  validateRoadBuilding(gameState, action) {
    const player = gameState.players.find(p => p.id === action.playerId);
    
    // Check resources
    if (player.resources.wood < 1 || player.resources.brick < 1) {
      return { valid: false, error: 'Insufficient resources for road' };
    }

    // Check road placement rules
    const { from, to } = action.data;
    
    // Must connect to existing road or building
    const hasConnection = this.checkRoadConnection(gameState, player, from, to);
    if (!hasConnection) {
      return { valid: false, error: 'Road must connect to your existing roads or buildings' };
    }

    // Check if edge is already occupied
    const isOccupied = this.checkEdgeOccupied(gameState, from, to);
    if (isOccupied) {
      return { valid: false, error: 'Edge already has a road' };
    }

    return { valid: true };
  }

  validateSettlementBuilding(gameState, action) {
    const player = gameState.players.find(p => p.id === action.playerId);
    
    // Check resources
    if (player.resources.wood < 1 || player.resources.brick < 1 ||
        player.resources.sheep < 1 || player.resources.wheat < 1) {
      return { valid: false, error: 'Insufficient resources for settlement' };
    }

    // Check settlement placement rules
    const { position } = action.data;
    
    // Must be connected to a road
    const hasRoadConnection = this.checkSettlementRoadConnection(gameState, player, position);
    if (!hasRoadConnection) {
      return { valid: false, error: 'Settlement must be connected to your road' };
    }

    // Check distance rule (no settlements on adjacent vertices)
    const respectsDistance = this.checkSettlementDistance(gameState, position);
    if (!respectsDistance) {
      return { valid: false, error: 'Too close to another settlement' };
    }

    return { valid: true };
  }

  validateCityBuilding(gameState, action) {
    const player = gameState.players.find(p => p.id === action.playerId);
    
    // Check resources
    if (player.resources.wheat < 2 || player.resources.ore < 3) {
      return { valid: false, error: 'Insufficient resources for city' };
    }

    // Check if player has a settlement at this position
    const { position } = action.data;
    const hasSettlement = player.buildings.settlements.some(s => 
      s.position.x === position.x && s.position.y === position.y
    );

    if (!hasSettlement) {
      return { valid: false, error: 'No settlement to upgrade at this position' };
    }

    return { valid: true };
  }

  validateTrade(gameState, action) {
    const player = gameState.players.find(p => p.id === action.playerId);
    const { offering, requesting, targetPlayer } = action.data;

    // Check if player has resources to offer
    for (const [resource, amount] of Object.entries(offering)) {
      if (player.resources[resource] < amount) {
        return { valid: false, error: `Not enough ${resource} to trade` };
      }
    }

    if (targetPlayer) {
      // Player-to-player trade
      const target = gameState.players.find(p => p.id === targetPlayer);
      if (!target) {
        return { valid: false, error: 'Target player not found' };
      }

      // Check if target has resources
      for (const [resource, amount] of Object.entries(requesting)) {
        if (target.resources[resource] < amount) {
          return { valid: false, error: 'Target player lacks requested resources' };
        }
      }
    } else {
      // Bank trade
      // Check trade ratios (4:1, 3:1 with port, 2:1 with specific port)
      const tradeRatio = this.getTradeRatio(gameState, player, offering, requesting);
      
      for (const [resource, amount] of Object.entries(offering)) {
        const required = amount * tradeRatio;
        if (player.resources[resource] < required) {
          return { valid: false, error: 'Insufficient resources for bank trade' };
        }
      }
    }

    return { valid: true };
  }

  validateCardPlay(gameState, action) {
    const player = gameState.players.find(p => p.id === action.playerId);
    const { cardType } = action.data;

    // Check if player has the card
    if (!player.developmentCards[cardType] || player.developmentCards[cardType] < 1) {
      return { valid: false, error: 'You do not have this development card' };
    }

    // Can't play victory point cards until end game
    if (cardType === 'victoryPoint' && player.victoryPoints < 9) {
      return { valid: false, error: 'Cannot play victory point card yet' };
    }

    return { valid: true };
  }

  validateDiscard(gameState, action) {
    const player = gameState.players.find(p => p.id === action.playerId);
    const { discarding } = action.data;

    // Count total resources
    const totalResources = Object.values(player.resources).reduce((sum, count) => sum + count, 0);
    
    // Must discard half (rounded down)
    const requiredDiscard = Math.floor(totalResources / 2);
    const discardCount = Object.values(discarding).reduce((sum, count) => sum + count, 0);

    if (discardCount !== requiredDiscard) {
      return { valid: false, error: `Must discard exactly ${requiredDiscard} cards` };
    }

    // Check if player has the cards to discard
    for (const [resource, amount] of Object.entries(discarding)) {
      if (player.resources[resource] < amount) {
        return { valid: false, error: `Not enough ${resource} to discard` };
      }
    }

    return { valid: true };
  }

  validateRobberMove(gameState, action) {
    const { tilePosition } = action.data;

    // Can't place robber on current position
    if (tilePosition === gameState.robberPosition) {
      return { valid: false, error: 'Must move robber to a different tile' };
    }

    // Can't place robber on water or invalid tiles
    if (tilePosition < 0 || tilePosition >= gameState.tiles.length) {
      return { valid: false, error: 'Invalid tile position' };
    }

    return { valid: true };
  }

  // Helper methods for validation
  checkRoadConnection(gameState, player, from, to) {
    // Check if the road connects to player's existing roads or buildings
    // Simplified implementation - in real game, use proper graph traversal
    return player.buildings.roads.length > 0 || 
           player.buildings.settlements.length > 0;
  }

  checkEdgeOccupied(gameState, from, to) {
    // Check if any player has a road on this edge
    return gameState.players.some(p => 
      p.buildings.roads.some(r => 
        (r.from.x === from.x && r.from.y === from.y && 
         r.to.x === to.x && r.to.y === to.y) ||
        (r.from.x === to.x && r.from.y === to.y && 
         r.to.x === from.x && r.to.y === from.y)
      )
    );
  }

  checkSettlementRoadConnection(gameState, player, position) {
    // Check if settlement connects to player's road
    // Simplified - in real implementation, check actual adjacency
    return player.buildings.roads.length > 0;
  }

  checkSettlementDistance(gameState, position) {
    // Check distance rule - no settlements within 2 edges
    // Simplified implementation
    const minDistance = 2;
    
    for (const player of gameState.players) {
      for (const settlement of player.buildings.settlements) {
        const distance = Math.sqrt(
          Math.pow(position.x - settlement.position.x, 2) +
          Math.pow(position.y - settlement.position.y, 2)
        );
        if (distance < minDistance) {
          return false;
        }
      }
      
      for (const city of player.buildings.cities) {
        const distance = Math.sqrt(
          Math.pow(position.x - city.position.x, 2) +
          Math.pow(position.y - city.position.y, 2)
        );
        if (distance < minDistance) {
          return false;
        }
      }
    }
    
    return true;
  }

  getTradeRatio(gameState, player, offering, requesting) {
    // Check if player has access to ports
    // Simplified - check for generic 3:1 or specific 2:1 ports
    
    // Default 4:1 trade
    let ratio = 4;
    
    // Check for 3:1 port access
    // In real implementation, check if player has settlement/city on port
    const hasGenericPort = false; // Simplified
    if (hasGenericPort) {
      ratio = 3;
    }
    
    // Check for specific 2:1 port
    // In real implementation, check port type matches offering resource
    const hasSpecificPort = false; // Simplified
    if (hasSpecificPort) {
      ratio = 2;
    }
    
    return ratio;
  }
}

module.exports = GameValidator;