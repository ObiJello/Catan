import SpriteKit
import UIKit

struct AvailableLobby {
    let code: String
    let hostName: String
    let playerCount: Int
    let maxPlayers: Int
    let victoryPoints: Int
}

class JoinLobbyScene: SKScene, UITextFieldDelegate {
    
    // UI Components
    private var backButton: SKShapeNode!
    private var titleLabel: SKLabelNode!
    private var codeField: UITextField!
    private var joinButton: SKShapeNode!
    private var friendLobbiesContainer: SKNode!
    private var publicLobbiesContainer: SKNode!
    private var refreshButton: SKShapeNode!
    
    // Available lobbies (would come from server in real app)
    private var friendLobbies: [AvailableLobby] = []
    private var publicLobbies: [AvailableLobby] = []
    
    override func didMove(to view: SKView) {
        self.backgroundColor = SKColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)
        setupUI()
        loadAvailableLobbies()
    }
    
    private func setupUI() {
        // Title
        titleLabel = SKLabelNode(text: "Join Lobby")
        titleLabel.fontName = "Helvetica-Bold"
        titleLabel.fontSize = self.size.width * 0.08
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.9)
        self.addChild(titleLabel)
        
        // Back Button
        backButton = createBackButton()
        backButton.position = CGPoint(x: 50, y: self.size.height - 50)
        backButton.name = "backButton"
        self.addChild(backButton)
        
        // Refresh Button
        refreshButton = createRefreshButton()
        refreshButton.position = CGPoint(x: self.size.width - 60, y: self.size.height - 50)
        refreshButton.name = "refreshButton"
        self.addChild(refreshButton)
        
        // Join by Code Section
        setupJoinByCodeSection()
        
        // Friends' Lobbies Section
        setupFriendLobbiesSection()
        
        // Public Lobbies Section
        setupPublicLobbiesSection()
    }
    
    private func setupJoinByCodeSection() {
        // Section title
        let codeTitle = SKLabelNode(text: "Enter Lobby Code:")
        codeTitle.fontName = "Helvetica"
        codeTitle.fontSize = self.size.width * 0.045
        codeTitle.fontColor = .white
        codeTitle.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.78)
        self.addChild(codeTitle)
        
        // Code input field
        codeField = UITextField()
        codeField.frame = CGRect(
            x: self.size.width * 0.2,
            y: self.size.height * 0.25,
            width: self.size.width * 0.4,
            height: 40
        )
        codeField.backgroundColor = .white
        codeField.textColor = .black
        codeField.font = UIFont.systemFont(ofSize: 20)
        codeField.borderStyle = .roundedRect
        codeField.placeholder = "XXXXXX"
        codeField.textAlignment = .center
        codeField.autocapitalizationType = .allCharacters
        codeField.autocorrectionType = .no
        codeField.delegate = self
        codeField.returnKeyType = .join
        self.view?.addSubview(codeField)
        
        // Join button
        joinButton = SKShapeNode(rectOf: CGSize(width: self.size.width * 0.25, height: 40), 
                                 cornerRadius: 8)
        joinButton.fillColor = .systemGreen
        joinButton.strokeColor = .clear
        joinButton.position = CGPoint(x: self.size.width * 0.75, y: self.size.height * 0.73)
        joinButton.name = "joinButton"
        
        let joinLabel = SKLabelNode(text: "Join")
        joinLabel.fontName = "Helvetica-Bold"
        joinLabel.fontSize = 18
        joinLabel.fontColor = .white
        joinLabel.verticalAlignmentMode = .center
        joinLabel.name = "joinButton"
        joinButton.addChild(joinLabel)
        
        self.addChild(joinButton)
    }
    
    private func setupFriendLobbiesSection() {
        // Section title
        let friendsTitle = SKLabelNode(text: "Friends' Lobbies")
        friendsTitle.fontName = "Helvetica-Bold"
        friendsTitle.fontSize = self.size.width * 0.05
        friendsTitle.fontColor = .white
        friendsTitle.horizontalAlignmentMode = .left
        friendsTitle.position = CGPoint(x: self.size.width * 0.05, y: self.size.height * 0.6)
        self.addChild(friendsTitle)
        
        // Container for friend lobbies
        friendLobbiesContainer = SKNode()
        friendLobbiesContainer.position = CGPoint(x: 0, y: self.size.height * 0.52)
        self.addChild(friendLobbiesContainer)
    }
    
    private func setupPublicLobbiesSection() {
        // Section title
        let publicTitle = SKLabelNode(text: "Public Lobbies")
        publicTitle.fontName = "Helvetica-Bold"
        publicTitle.fontSize = self.size.width * 0.05
        publicTitle.fontColor = .white
        publicTitle.horizontalAlignmentMode = .left
        publicTitle.position = CGPoint(x: self.size.width * 0.05, y: self.size.height * 0.35)
        self.addChild(publicTitle)
        
        // Container for public lobbies
        publicLobbiesContainer = SKNode()
        publicLobbiesContainer.position = CGPoint(x: 0, y: self.size.height * 0.27)
        self.addChild(publicLobbiesContainer)
    }
    
    private func createBackButton() -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: 25)
        button.fillColor = .white.withAlphaComponent(0.2)
        button.strokeColor = .white
        button.lineWidth = 2
        
        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: 5, y: 0))
        arrowPath.addLine(to: CGPoint(x: -5, y: -10))
        arrowPath.addLine(to: CGPoint(x: -5, y: -3))
        arrowPath.addLine(to: CGPoint(x: -10, y: -3))
        arrowPath.addLine(to: CGPoint(x: -10, y: 3))
        arrowPath.addLine(to: CGPoint(x: -5, y: 3))
        arrowPath.addLine(to: CGPoint(x: -5, y: 10))
        arrowPath.closeSubpath()
        
        let arrow = SKShapeNode(path: arrowPath)
        arrow.fillColor = .white
        arrow.strokeColor = .clear
        button.addChild(arrow)
        
        return button
    }
    
    private func createRefreshButton() -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: 25)
        button.fillColor = .white.withAlphaComponent(0.2)
        button.strokeColor = .white
        button.lineWidth = 2
        
        // Refresh icon (circular arrow)
        let refreshPath = CGMutablePath()
        refreshPath.addArc(center: .zero, radius: 10, startAngle: 0, endAngle: .pi * 1.5, 
                           clockwise: false)
        refreshPath.move(to: CGPoint(x: 0, y: 10))
        refreshPath.addLine(to: CGPoint(x: 5, y: 8))
        refreshPath.move(to: CGPoint(x: 0, y: 10))
        refreshPath.addLine(to: CGPoint(x: -2, y: 5))
        
        let refresh = SKShapeNode(path: refreshPath)
        refresh.strokeColor = .white
        refresh.lineWidth = 2
        button.addChild(refresh)
        
        return button
    }
    
    private func loadAvailableLobbies() {
        // In a real app, this would fetch from a server
        // For now, create some sample lobbies
        
        friendLobbies = [
            AvailableLobby(code: "ABC123", hostName: "AlexTheGreat", 
                          playerCount: 2, maxPlayers: 4, victoryPoints: 10),
            AvailableLobby(code: "XYZ789", hostName: "BoardGameBob", 
                          playerCount: 3, maxPlayers: 4, victoryPoints: 12)
        ]
        
        publicLobbies = [
            AvailableLobby(code: "PUB001", hostName: "Player123", 
                          playerCount: 1, maxPlayers: 4, victoryPoints: 10),
            AvailableLobby(code: "PUB002", hostName: "CatanMaster", 
                          playerCount: 2, maxPlayers: 3, victoryPoints: 15),
            AvailableLobby(code: "PUB003", hostName: "Newbie", 
                          playerCount: 1, maxPlayers: 4, victoryPoints: 8)
        ]
        
        displayLobbies()
    }
    
    private func displayLobbies() {
        // Clear existing lobbies
        friendLobbiesContainer.removeAllChildren()
        publicLobbiesContainer.removeAllChildren()
        
        // Display friend lobbies
        for (index, lobby) in friendLobbies.enumerated() {
            let lobbyNode = createLobbyRow(lobby: lobby, isFriend: true)
            lobbyNode.position = CGPoint(x: self.size.width/2, y: -CGFloat(index) * 60)
            friendLobbiesContainer.addChild(lobbyNode)
        }
        
        // Display public lobbies
        for (index, lobby) in publicLobbies.enumerated() {
            let lobbyNode = createLobbyRow(lobby: lobby, isFriend: false)
            lobbyNode.position = CGPoint(x: self.size.width/2, y: -CGFloat(index) * 60)
            publicLobbiesContainer.addChild(lobbyNode)
        }
        
        // Show "No lobbies" message if empty
        if friendLobbies.isEmpty {
            let noFriendsLabel = SKLabelNode(text: "No friend lobbies available")
            noFriendsLabel.fontName = "Helvetica"
            noFriendsLabel.fontSize = 14
            noFriendsLabel.fontColor = .white.withAlphaComponent(0.5)
            noFriendsLabel.position = CGPoint(x: self.size.width/2, y: 0)
            friendLobbiesContainer.addChild(noFriendsLabel)
        }
        
        if publicLobbies.isEmpty {
            let noPublicLabel = SKLabelNode(text: "No public lobbies available")
            noPublicLabel.fontName = "Helvetica"
            noPublicLabel.fontSize = 14
            noPublicLabel.fontColor = .white.withAlphaComponent(0.5)
            noPublicLabel.position = CGPoint(x: self.size.width/2, y: 0)
            publicLobbiesContainer.addChild(noPublicLabel)
        }
    }
    
    private func createLobbyRow(lobby: AvailableLobby, isFriend: Bool) -> SKNode {
        let container = SKNode()
        container.name = "lobby_\(lobby.code)"
        
        // Background
        let background = SKShapeNode(rectOf: CGSize(width: self.size.width * 0.9, height: 50), 
                                     cornerRadius: 8)
        background.fillColor = .white.withAlphaComponent(0.1)
        background.strokeColor = .white.withAlphaComponent(0.3)
        background.name = container.name
        container.addChild(background)
        
        // Host name
        let hostLabel = SKLabelNode(text: lobby.hostName)
        hostLabel.fontName = "Helvetica-Bold"
        hostLabel.fontSize = 16
        hostLabel.fontColor = .white
        hostLabel.horizontalAlignmentMode = .left
        hostLabel.position = CGPoint(x: -self.size.width * 0.4, y: 8)
        container.addChild(hostLabel)
        
        // Lobby code
        let codeLabel = SKLabelNode(text: "Code: \(lobby.code)")
        codeLabel.fontName = "Helvetica"
        codeLabel.fontSize = 12
        codeLabel.fontColor = .white.withAlphaComponent(0.7)
        codeLabel.horizontalAlignmentMode = .left
        codeLabel.position = CGPoint(x: -self.size.width * 0.4, y: -12)
        container.addChild(codeLabel)
        
        // Player count
        let playerCountLabel = SKLabelNode(text: "\(lobby.playerCount)/\(lobby.maxPlayers)")
        playerCountLabel.fontName = "Helvetica"
        playerCountLabel.fontSize = 16
        playerCountLabel.fontColor = lobby.playerCount < lobby.maxPlayers ? .systemGreen : .systemOrange
        playerCountLabel.position = CGPoint(x: self.size.width * 0.2, y: 0)
        container.addChild(playerCountLabel)
        
        // Victory points
        let vpLabel = SKLabelNode(text: "VP: \(lobby.victoryPoints)")
        vpLabel.fontName = "Helvetica"
        vpLabel.fontSize = 14
        vpLabel.fontColor = .white.withAlphaComponent(0.7)
        vpLabel.position = CGPoint(x: self.size.width * 0.35, y: 0)
        container.addChild(vpLabel)
        
        // Friend indicator
        if isFriend {
            let friendIcon = SKLabelNode(text: "👥")
            friendIcon.fontSize = 20
            friendIcon.position = CGPoint(x: -self.size.width * 0.42, y: 0)
            container.addChild(friendIcon)
        }
        
        return container
    }
    
    private func joinLobby(withCode code: String) {
        // Clean up text field
        codeField.resignFirstResponder()
        codeField.removeFromSuperview()
        
        // In a real app, this would connect to the server
        // For now, navigate to lobby scene as a non-host player
        let lobbyScene = LobbyScene(size: self.size)
        lobbyScene.scaleMode = .aspectFill
        lobbyScene.isHost = false
        
        self.view?.presentScene(lobbyScene, transition: SKTransition.fade(withDuration: 0.5))
    }
    
    private func showError(_ message: String) {
        let errorLabel = SKLabelNode(text: message)
        errorLabel.fontName = "Helvetica"
        errorLabel.fontSize = 16
        errorLabel.fontColor = .systemRed
        errorLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.65)
        self.addChild(errorLabel)
        
        errorLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.5),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
    
    // UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if let code = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
           !code.isEmpty {
            joinLobby(withCode: code)
        }
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = self.atPoint(location)
        
        // Dismiss keyboard if active
        codeField.resignFirstResponder()
        
        if let nodeName = node.name {
            if nodeName == "backButton" {
                // Clean up text field
                codeField.removeFromSuperview()
                
                let multiplayerMenuScene = MultiplayerMenuScene(size: self.size)
                multiplayerMenuScene.scaleMode = .aspectFill
                self.view?.presentScene(multiplayerMenuScene, transition: SKTransition.fade(withDuration: 0.5))
                
            } else if nodeName == "joinButton" {
                if let code = codeField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !code.isEmpty {
                    joinLobby(withCode: code)
                } else {
                    showError("Please enter a lobby code")
                }
                
            } else if nodeName == "refreshButton" {
                // Animate refresh
                refreshButton.run(SKAction.rotate(byAngle: .pi * 2, duration: 0.5))
                loadAvailableLobbies()
                
            } else if nodeName.starts(with: "lobby_") {
                let code = String(nodeName.dropFirst(6))
                joinLobby(withCode: code)
            }
        }
    }
    
    override func willMove(from view: SKView) {
        // Clean up text field when leaving scene
        codeField.removeFromSuperview()
    }
}