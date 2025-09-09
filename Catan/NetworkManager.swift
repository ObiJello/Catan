import Foundation

// MARK: - Game Action Types
enum GameActionType: String, Codable {
    case diceRoll
    case buildRoad
    case buildSettlement
    case buildCity
    case trade
    case playDevelopmentCard
    case moveRobber
    case endTurn
    case chat
    case playerJoined
    case playerLeft
    case gameStart
    case gameEnd
}

// MARK: - Game Action
struct GameAction: Codable {
    let type: GameActionType
    let playerId: String
    let data: [String: Any]
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case type, playerId, data, timestamp
    }
    
    init(type: GameActionType, playerId: String, data: [String: Any]) {
        self.type = type
        self.playerId = playerId
        self.data = data
        self.timestamp = Date()
    }
    
    // Custom encoding/decoding for the Any type in data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(GameActionType.self, forKey: .type)
        playerId = try container.decode(String.self, forKey: .playerId)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // Decode data as JSON
        if let dataString = try? container.decode(String.self, forKey: .data),
           let jsonData = dataString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            data = json
        } else {
            data = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(playerId, forKey: .playerId)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Encode data as JSON string
        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try container.encode(jsonString, forKey: .data)
        }
    }
}

// MARK: - Network Manager Delegate
protocol NetworkManagerDelegate: AnyObject {
    func networkManager(_ manager: NetworkManager, didReceiveGameAction action: GameAction)
    func networkManager(_ manager: NetworkManager, didUpdateConnectionStatus connected: Bool)
    func networkManager(_ manager: NetworkManager, playerDidDisconnect playerId: String)
}

// MARK: - Network Manager
class NetworkManager: NSObject {
    
    weak var delegate: NetworkManagerDelegate?
    
    // Connection properties
    private var session: URLSession!
    private var webSocketTask: URLSessionWebSocketTask?
    private var isConnected = false
    private var isHost = false
    private var roomCode: String?
    
    // Server configuration (would be configured for real server)
    private let serverURL = "wss://catan-server.example.com/game"
    private let localServerURL = "ws://localhost:3000/game"
    
    // Message queue for offline handling
    private var messageQueue: [GameAction] = []
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }
    
    // MARK: - Connection Management
    
    func startHost() {
        isHost = true
        roomCode = generateRoomCode()
        connect(asHost: true)
    }
    
    func joinGame(withCode code: String? = nil) {
        isHost = false
        roomCode = code
        connect(asHost: false)
    }
    
    private func connect(asHost: Bool) {
        // For demo purposes, use local server URL
        // In production, use the actual server URL
        guard let url = URL(string: localServerURL) else {
            print("Invalid server URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("game", forHTTPHeaderField: "Sec-WebSocket-Protocol")
        
        // Add room code and host status to headers
        if let roomCode = roomCode {
            request.setValue(roomCode, forHTTPHeaderField: "X-Room-Code")
        }
        request.setValue(String(asHost), forHTTPHeaderField: "X-Is-Host")
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Start receiving messages
        receiveMessage()
        
        // Send initial connection message
        let connectionAction = GameAction(
            type: .playerJoined,
            playerId: getCurrentPlayerId(),
            data: [
                "username": UserDefaults.standard.string(forKey: "playerUsername") ?? "Player",
                "isHost": asHost
            ]
        )
        sendAction(connectionAction)
        
        isConnected = true
        delegate?.networkManager(self, didUpdateConnectionStatus: true)
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
        delegate?.networkManager(self, didUpdateConnectionStatus: false)
    }
    
    // MARK: - Message Handling
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self.handleDisconnection()
                
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleTextMessage(text)
                case .data(let data):
                    self.handleDataMessage(data)
                @unknown default:
                    break
                }
                
                // Continue receiving messages
                self.receiveMessage()
            }
        }
    }
    
    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let action = try? JSONDecoder().decode(GameAction.self, from: data) else {
            print("Failed to decode message: \(text)")
            return
        }
        
        // Don't process our own actions
        if action.playerId != getCurrentPlayerId() {
            delegate?.networkManager(self, didReceiveGameAction: action)
        }
    }
    
    private func handleDataMessage(_ data: Data) {
        guard let action = try? JSONDecoder().decode(GameAction.self, from: data) else {
            print("Failed to decode data message")
            return
        }
        
        // Don't process our own actions
        if action.playerId != getCurrentPlayerId() {
            delegate?.networkManager(self, didReceiveGameAction: action)
        }
    }
    
    func sendAction(_ action: GameAction) {
        guard isConnected else {
            // Queue message for later sending
            messageQueue.append(action)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(action)
            let message = URLSessionWebSocketTask.Message.data(data)
            
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                    self.handleDisconnection()
                }
            }
        } catch {
            print("Failed to encode action: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateRoomCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in letters.randomElement()! })
    }
    
    private func getCurrentPlayerId() -> String {
        // Use stored player ID or generate new one
        if let playerId = UserDefaults.standard.string(forKey: "multiplayerPlayerId") {
            return playerId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "multiplayerPlayerId")
            return newId
        }
    }
    
    private func handleDisconnection() {
        isConnected = false
        delegate?.networkManager(self, didUpdateConnectionStatus: false)
        
        // Attempt to reconnect after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self, !self.isConnected else { return }
            print("Attempting to reconnect...")
            self.connect(asHost: self.isHost)
        }
    }
    
    private func sendQueuedMessages() {
        guard isConnected else { return }
        
        let queue = messageQueue
        messageQueue.removeAll()
        
        for action in queue {
            sendAction(action)
        }
    }
    
    // MARK: - Game Actions
    
    func sendDiceRoll(value1: Int, value2: Int) {
        let action = GameAction(
            type: .diceRoll,
            playerId: getCurrentPlayerId(),
            data: ["value1": value1, "value2": value2, "total": value1 + value2]
        )
        sendAction(action)
    }
    
    func sendBuildRoad(from: CGPoint, to: CGPoint) {
        let action = GameAction(
            type: .buildRoad,
            playerId: getCurrentPlayerId(),
            data: [
                "fromX": from.x,
                "fromY": from.y,
                "toX": to.x,
                "toY": to.y
            ]
        )
        sendAction(action)
    }
    
    func sendBuildSettlement(at position: CGPoint) {
        let action = GameAction(
            type: .buildSettlement,
            playerId: getCurrentPlayerId(),
            data: ["x": position.x, "y": position.y]
        )
        sendAction(action)
    }
    
    func sendBuildCity(at position: CGPoint) {
        let action = GameAction(
            type: .buildCity,
            playerId: getCurrentPlayerId(),
            data: ["x": position.x, "y": position.y]
        )
        sendAction(action)
    }
    
    func sendTradeOffer(offering: [String: Int], requesting: [String: Int], toPlayer: String?) {
        let action = GameAction(
            type: .trade,
            playerId: getCurrentPlayerId(),
            data: [
                "offering": offering,
                "requesting": requesting,
                "toPlayer": toPlayer ?? "all"
            ]
        )
        sendAction(action)
    }
    
    func sendEndTurn() {
        let action = GameAction(
            type: .endTurn,
            playerId: getCurrentPlayerId(),
            data: [:]
        )
        sendAction(action)
    }
    
    func sendChatMessage(_ message: String) {
        let action = GameAction(
            type: .chat,
            playerId: getCurrentPlayerId(),
            data: ["message": message]
        )
        sendAction(action)
    }
}

// MARK: - URLSessionWebSocketDelegate
extension NetworkManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, 
                   didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
        isConnected = true
        delegate?.networkManager(self, didUpdateConnectionStatus: true)
        sendQueuedMessages()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, 
                   didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket closed with code: \(closeCode)")
        handleDisconnection()
    }
}