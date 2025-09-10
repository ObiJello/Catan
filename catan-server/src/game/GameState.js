class GameState {
  constructor(roomCode, players) {
    this.roomCode = roomCode;
    this.players = players.map((p, index) => ({
      ...p,
      index: index,
      resources: { wood: 0, brick: 0, sheep: 0, wheat: 0, ore: 0 },
      developmentCards: { knight: 0, roadBuilding: 0, yearOfPlenty: 0, monopoly: 0, victoryPoint: 0 },
      victoryPoints: 0,
      longestRoadLength: 0,
      largestArmySize: 0,
      buildings: {
        roads: [],
        settlements: [],
        cities: []
      }
    }));
    
    this.currentPlayerIndex = 0;
    this.phase = 'setup'; // setup, rolling, main, discard, moveRobber, trading, ended
    this.turnNumber = 0;
    this.diceRoll = null;
    this.robberPosition = null;
    this.longestRoadOwner = null;
    this.largestArmyOwner = null;
    
    // Board setup (simplified - in real implementation, generate random board)
    this.tiles = this.generateBoard();
    this.ports = this.generatePorts();
    
    // Development card deck
    this.developmentDeck = this.createDevelopmentDeck();
    this.shuffleDeck();
    
    // Resource bank
    this.resourceBank = {
      wood: 19,
      brick: 19,
      sheep: 19,
      wheat: 19,
      ore: 19
    };
  }

  generateBoard() {
    // Simplified board generation
    // In real implementation, this would create a proper hex board
    const resources = ['wood', 'brick', 'sheep', 'wheat', 'ore'];
    const numbers = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12];
    const tiles = [];
    
    // Create 19 tiles (including desert)
    for (let i = 0; i < 18; i++) {
      tiles.push({
        id: i,
        resource: resources[i % resources.length],
        number: numbers[i],
        hasRobber: false
      });
    }
    
    // Add desert tile
    tiles.push({
      id: 18,
      resource: 'desert',
      number: null,
      hasRobber: true
    });
    
    this.robberPosition = 18; // Start on desert
    return tiles;
  }

  generatePorts() {
    // Simplified port generation
    return [
      { type: '3:1', position: 0 },
      { type: '2:1 wood', position: 1 },
      { type: '2:1 brick', position: 2 },
      { type: '2:1 sheep', position: 3 },
      { type: '2:1 wheat', position: 4 },
      { type: '2:1 ore', position: 5 },
      { type: '3:1', position: 6 },
      { type: '3:1', position: 7 },
      { type: '3:1', position: 8 }
    ];
  }

  createDevelopmentDeck() {
    const deck = [];
    
    // Add cards according to standard Catan distribution
    for (let i = 0; i < 14; i++) deck.push('knight');
    for (let i = 0; i < 5; i++) deck.push('victoryPoint');
    for (let i = 0; i < 2; i++) deck.push('roadBuilding');
    for (let i = 0; i < 2; i++) deck.push('yearOfPlenty');
    for (let i = 0; i < 2; i++) deck.push('monopoly');
    
    return deck;
  }

  shuffleDeck() {
    for (let i = this.developmentDeck.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [this.developmentDeck[i], this.developmentDeck[j]] = 
      [this.developmentDeck[j], this.developmentDeck[i]];
    }
  }

  getCurrentPlayer() {
    return this.players[this.currentPlayerIndex];
  }

  setDiceRoll(value1, value2) {
    this.diceRoll = { value1, value2, total: value1 + value2 };
    this.phase = 'main';
  }

  distributeResources(diceTotal) {
    this.tiles.forEach(tile => {
      if (tile.number === diceTotal && !tile.hasRobber && tile.resource !== 'desert') {
        // Find all settlements and cities adjacent to this tile
        // Simplified - in real implementation, check actual adjacency
        this.players.forEach(player => {
          const settlementCount = player.buildings.settlements.filter(s => 
            this.isAdjacentToTile(s, tile)).length;
          const cityCount = player.buildings.cities.filter(c => 
            this.isAdjacentToTile(c, tile)).length;
          
          const resourceAmount = settlementCount + (cityCount * 2);
          if (resourceAmount > 0 && this.resourceBank[tile.resource] >= resourceAmount) {
            player.resources[tile.resource] += resourceAmount;
            this.resourceBank[tile.resource] -= resourceAmount;
          }
        });
      }
    });
  }

  isAdjacentToTile(building, tile) {
    // Simplified adjacency check
    // In real implementation, use proper hex coordinate system
    return Math.random() > 0.7; // Random for demo
  }

  getPlayersToDiscard() {
    return this.players.filter(p => {
      const totalCards = Object.values(p.resources).reduce((sum, count) => sum + count, 0);
      return totalCards > 7;
    });
  }

  buildRoad(playerId, from, to) {
    const player = this.players.find(p => p.id === playerId);
    if (!player) return false;
    
    // Check resources
    if (player.resources.wood < 1 || player.resources.brick < 1) {
      return false;
    }
    
    // Deduct resources
    player.resources.wood--;
    player.resources.brick--;
    this.resourceBank.wood++;
    this.resourceBank.brick++;
    
    // Add road
    player.buildings.roads.push({ from, to });
    
    // Update longest road calculation
    this.updateLongestRoad();
    
    return true;
  }

  buildSettlement(playerId, position) {
    const player = this.players.find(p => p.id === playerId);
    if (!player) return false;
    
    // Check resources
    if (player.resources.wood < 1 || player.resources.brick < 1 || 
        player.resources.sheep < 1 || player.resources.wheat < 1) {
      return false;
    }
    
    // Deduct resources
    player.resources.wood--;
    player.resources.brick--;
    player.resources.sheep--;
    player.resources.wheat--;
    this.resourceBank.wood++;
    this.resourceBank.brick++;
    this.resourceBank.sheep++;
    this.resourceBank.wheat++;
    
    // Add settlement
    player.buildings.settlements.push({ position });
    player.victoryPoints++;
    
    return true;
  }

  buildCity(playerId, position) {
    const player = this.players.find(p => p.id === playerId);
    if (!player) return false;
    
    // Check resources
    if (player.resources.wheat < 2 || player.resources.ore < 3) {
      return false;
    }
    
    // Find settlement to upgrade
    const settlementIndex = player.buildings.settlements.findIndex(s => 
      s.position.x === position.x && s.position.y === position.y);
    
    if (settlementIndex === -1) {
      return false;
    }
    
    // Deduct resources
    player.resources.wheat -= 2;
    player.resources.ore -= 3;
    this.resourceBank.wheat += 2;
    this.resourceBank.ore += 3;
    
    // Upgrade settlement to city
    player.buildings.settlements.splice(settlementIndex, 1);
    player.buildings.cities.push({ position });
    player.victoryPoints++;
    
    return true;
  }

  tradeWithBank(playerId, offering, requesting) {
    const player = this.players.find(p => p.id === playerId);
    if (!player) return false;
    
    // Check if player has resources to offer
    for (const [resource, amount] of Object.entries(offering)) {
      if (player.resources[resource] < amount) {
        return false;
      }
    }
    
    // Check if bank has resources to give
    for (const [resource, amount] of Object.entries(requesting)) {
      if (this.resourceBank[resource] < amount) {
        return false;
      }
    }
    
    // Execute trade
    for (const [resource, amount] of Object.entries(offering)) {
      player.resources[resource] -= amount;
      this.resourceBank[resource] += amount;
    }
    
    for (const [resource, amount] of Object.entries(requesting)) {
      player.resources[resource] += amount;
      this.resourceBank[resource] -= amount;
    }
    
    return true;
  }

  moveRobber(tileId) {
    if (tileId < 0 || tileId >= this.tiles.length) {
      return false;
    }
    
    // Remove robber from current tile
    if (this.robberPosition !== null) {
      this.tiles[this.robberPosition].hasRobber = false;
    }
    
    // Place robber on new tile
    this.tiles[tileId].hasRobber = true;
    this.robberPosition = tileId;
    
    return true;
  }

  stealResource(thief, victim) {
    const thiefPlayer = this.players.find(p => p.id === thief);
    const victimPlayer = this.players.find(p => p.id === victim);
    
    if (!thiefPlayer || !victimPlayer) return false;
    
    // Get all resources victim has
    const availableResources = [];
    for (const [resource, count] of Object.entries(victimPlayer.resources)) {
      for (let i = 0; i < count; i++) {
        availableResources.push(resource);
      }
    }
    
    if (availableResources.length === 0) return false;
    
    // Steal random resource
    const stolenResource = availableResources[Math.floor(Math.random() * availableResources.length)];
    victimPlayer.resources[stolenResource]--;
    thiefPlayer.resources[stolenResource]++;
    
    return true;
  }

  playKnight(playerId) {
    const player = this.players.find(p => p.id === playerId);
    if (!player || player.developmentCards.knight < 1) return false;
    
    player.developmentCards.knight--;
    player.largestArmySize++;
    
    // Check for largest army
    this.updateLargestArmy();
    
    return true;
  }

  playMonopoly(playerId, resource) {
    const player = this.players.find(p => p.id === playerId);
    if (!player || player.developmentCards.monopoly < 1) return false;
    
    player.developmentCards.monopoly--;
    
    // Collect all of specified resource from other players
    let totalCollected = 0;
    this.players.forEach(p => {
      if (p.id !== playerId) {
        totalCollected += p.resources[resource];
        p.resources[resource] = 0;
      }
    });
    
    player.resources[resource] += totalCollected;
    
    return true;
  }

  playVictoryPoint(playerId) {
    const player = this.players.find(p => p.id === playerId);
    if (!player || player.developmentCards.victoryPoint < 1) return false;
    
    player.developmentCards.victoryPoint--;
    player.victoryPoints++;
    
    return true;
  }

  playRoadBuilding(playerId) {
    const player = this.players.find(p => p.id === playerId);
    if (!player || player.developmentCards.roadBuilding < 1) return false;
    
    player.developmentCards.roadBuilding--;
    // The actual road placement will be handled by subsequent buildRoad calls
    
    return true;
  }

  updateLongestRoad() {
    let maxLength = 4; // Minimum for longest road
    let newOwner = null;
    
    this.players.forEach(player => {
      // Simplified - in real implementation, calculate actual road length
      const roadLength = player.buildings.roads.length;
      player.longestRoadLength = roadLength;
      
      if (roadLength > maxLength) {
        maxLength = roadLength;
        newOwner = player.id;
      }
    });
    
    // Update longest road owner
    if (this.longestRoadOwner !== newOwner) {
      // Remove points from old owner
      if (this.longestRoadOwner) {
        const oldOwner = this.players.find(p => p.id === this.longestRoadOwner);
        if (oldOwner) oldOwner.victoryPoints -= 2;
      }
      
      // Add points to new owner
      if (newOwner) {
        const owner = this.players.find(p => p.id === newOwner);
        if (owner) owner.victoryPoints += 2;
      }
      
      this.longestRoadOwner = newOwner;
    }
  }

  updateLargestArmy() {
    let maxArmy = 2; // Minimum for largest army
    let newOwner = null;
    
    this.players.forEach(player => {
      if (player.largestArmySize > maxArmy) {
        maxArmy = player.largestArmySize;
        newOwner = player.id;
      }
    });
    
    // Update largest army owner
    if (this.largestArmyOwner !== newOwner) {
      // Remove points from old owner
      if (this.largestArmyOwner) {
        const oldOwner = this.players.find(p => p.id === this.largestArmyOwner);
        if (oldOwner) oldOwner.victoryPoints -= 2;
      }
      
      // Add points to new owner
      if (newOwner) {
        const owner = this.players.find(p => p.id === newOwner);
        if (owner) owner.victoryPoints += 2;
      }
      
      this.largestArmyOwner = newOwner;
    }
  }

  nextTurn() {
    this.currentPlayerIndex = (this.currentPlayerIndex + 1) % this.players.length;
    this.turnNumber++;
    this.phase = 'rolling';
    this.diceRoll = null;
  }

  setPhase(phase) {
    this.phase = phase;
  }

  checkWinner() {
    const winner = this.players.find(p => p.victoryPoints >= 10);
    if (winner) {
      this.phase = 'ended';
      return winner;
    }
    return null;
  }

  getWinner() {
    return this.players.find(p => p.victoryPoints >= 10);
  }

  getPublicState() {
    // Return state visible to all players
    return {
      roomCode: this.roomCode,
      players: this.players.map(p => ({
        id: p.id,
        name: p.name,
        color: p.color,
        victoryPoints: p.victoryPoints,
        resourceCount: Object.values(p.resources).reduce((sum, count) => sum + count, 0),
        developmentCardCount: Object.values(p.developmentCards).reduce((sum, count) => sum + count, 0),
        largestArmySize: p.largestArmySize,
        longestRoadLength: p.longestRoadLength,
        buildings: p.buildings
      })),
      currentPlayerIndex: this.currentPlayerIndex,
      phase: this.phase,
      turnNumber: this.turnNumber,
      diceRoll: this.diceRoll,
      robberPosition: this.robberPosition,
      longestRoadOwner: this.longestRoadOwner,
      largestArmyOwner: this.largestArmyOwner,
      tiles: this.tiles,
      ports: this.ports
    };
  }

  getPrivateState(playerId) {
    // Return state including private information for specific player
    const publicState = this.getPublicState();
    const player = this.players.find(p => p.id === playerId);
    
    if (player) {
      publicState.myResources = player.resources;
      publicState.myDevelopmentCards = player.developmentCards;
    }
    
    return publicState;
  }
}

module.exports = GameState;