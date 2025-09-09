import SpriteKit
import UIKit

class MultiplayerMenuScene: SKScene {
    
    // UI Components
    private var backButton: SKShapeNode!
    private var titleLabel: SKLabelNode!
    private var createLobbyButton: SKShapeNode!
    private var joinLobbyButton: SKShapeNode!
    private var friendsButton: SKShapeNode!
    private var profileButton: SKShapeNode!
    private var usernameLabel: SKLabelNode!
    
    override func didMove(to view: SKView) {
        // Set background color to match the app theme
        self.backgroundColor = SKColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)
        
        setupUI()
        displayUsername()
    }
    
    private func setupUI() {
        let buttonWidth = self.size.width * 0.7
        let buttonHeight = self.size.width * 0.12
        let cornerRadius: CGFloat = 10.0
        
        // Title Label
        titleLabel = SKLabelNode(text: "Multiplayer")
        titleLabel.fontName = "Helvetica-Bold"
        titleLabel.fontSize = self.size.width * 0.08
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.85)
        self.addChild(titleLabel)
        
        // Back Button (top-left corner)
        backButton = createBackButton()
        backButton.position = CGPoint(x: 50, y: self.size.height - 50)
        backButton.name = "backButton"
        self.addChild(backButton)
        
        // Username display
        usernameLabel = SKLabelNode(text: "Guest")
        usernameLabel.fontName = "Helvetica"
        usernameLabel.fontSize = self.size.width * 0.045
        usernameLabel.fontColor = .white
        usernameLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.75)
        self.addChild(usernameLabel)
        
        // Create Lobby Button
        createLobbyButton = createMenuButton(
            text: "Create Lobby",
            size: CGSize(width: buttonWidth, height: buttonHeight),
            cornerRadius: cornerRadius
        )
        createLobbyButton.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.55)
        createLobbyButton.name = "createLobbyButton"
        self.addChild(createLobbyButton)
        
        // Join Lobby Button
        joinLobbyButton = createMenuButton(
            text: "Join Lobby",
            size: CGSize(width: buttonWidth, height: buttonHeight),
            cornerRadius: cornerRadius
        )
        joinLobbyButton.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.42)
        joinLobbyButton.name = "joinLobbyButton"
        self.addChild(joinLobbyButton)
        
        // Friends Button
        friendsButton = createMenuButton(
            text: "Friends",
            size: CGSize(width: buttonWidth, height: buttonHeight),
            cornerRadius: cornerRadius
        )
        friendsButton.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.29)
        friendsButton.name = "friendsButton"
        self.addChild(friendsButton)
        
        // Profile Button
        profileButton = createMenuButton(
            text: "Profile",
            size: CGSize(width: buttonWidth, height: buttonHeight),
            cornerRadius: cornerRadius
        )
        profileButton.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.16)
        profileButton.name = "profileButton"
        self.addChild(profileButton)
        
        // Quick Play section (bottom area)
        let quickPlayLabel = SKLabelNode(text: "Quick Play")
        quickPlayLabel.fontName = "Helvetica"
        quickPlayLabel.fontSize = self.size.width * 0.04
        quickPlayLabel.fontColor = .white.withAlphaComponent(0.8)
        quickPlayLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.08)
        self.addChild(quickPlayLabel)
        
        let quickPlayButton = createMenuButton(
            text: "Find Match",
            size: CGSize(width: buttonWidth * 0.5, height: buttonHeight * 0.8),
            cornerRadius: cornerRadius
        )
        quickPlayButton.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.04)
        quickPlayButton.name = "quickPlayButton"
        quickPlayButton.fillColor = .systemGreen
        self.addChild(quickPlayButton)
    }
    
    private func createMenuButton(text: String, size: CGSize, cornerRadius: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        button.fillColor = .white
        button.strokeColor = .clear
        
        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica"
        label.fontSize = min(22, self.size.width * 0.06)
        label.fontColor = .black
        label.verticalAlignmentMode = .center
        label.position = .zero
        label.name = button.name  // Inherit parent's name for touch detection
        button.addChild(label)
        
        return button
    }
    
    private func createBackButton() -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: 25)
        button.fillColor = .white.withAlphaComponent(0.2)
        button.strokeColor = .white
        button.lineWidth = 2
        
        // Create back arrow using path
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
        arrow.position = .zero
        button.addChild(arrow)
        
        return button
    }
    
    private func displayUsername() {
        // Check if user has a saved username
        if let username = UserDefaults.standard.string(forKey: "playerUsername") {
            usernameLabel.text = "Welcome, \(username)"
        } else {
            usernameLabel.text = "Welcome, Guest"
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = self.atPoint(location)
        
        if let nodeName = node.name {
            handleButtonTap(nodeName)
        }
    }
    
    private func handleButtonTap(_ nodeName: String) {
        switch nodeName {
        case "backButton":
            // Return to TitleScene
            let titleScene = TitleScene(size: self.size)
            titleScene.scaleMode = .aspectFill
            self.view?.presentScene(titleScene, transition: SKTransition.fade(withDuration: 0.5))
            
        case "createLobbyButton":
            // Navigate to Lobby Scene with create mode
            let lobbyScene = LobbyScene(size: self.size)
            lobbyScene.scaleMode = .aspectFill
            lobbyScene.isHost = true
            self.view?.presentScene(lobbyScene, transition: SKTransition.fade(withDuration: 0.5))
            
        case "joinLobbyButton":
            // Navigate to Join Lobby Scene
            let joinLobbyScene = JoinLobbyScene(size: self.size)
            joinLobbyScene.scaleMode = .aspectFill
            self.view?.presentScene(joinLobbyScene, transition: SKTransition.fade(withDuration: 0.5))
            
        case "friendsButton":
            // Navigate to Friends List Scene
            let friendsScene = FriendsListScene(size: self.size)
            friendsScene.scaleMode = .aspectFill
            self.view?.presentScene(friendsScene, transition: SKTransition.fade(withDuration: 0.5))
            
        case "profileButton":
            // Navigate to Profile Scene
            let profileScene = ProfileScene(size: self.size)
            profileScene.scaleMode = .aspectFill
            self.view?.presentScene(profileScene, transition: SKTransition.fade(withDuration: 0.5))
            
        case "quickPlayButton":
            // Start quick match - find a random lobby or create one
            startQuickMatch()
            
        default:
            break
        }
    }
    
    private func startQuickMatch() {
        // For now, create a new lobby with bots
        let lobbyScene = LobbyScene(size: self.size)
        lobbyScene.scaleMode = .aspectFill
        lobbyScene.isHost = true
        lobbyScene.isQuickPlay = true
        self.view?.presentScene(lobbyScene, transition: SKTransition.fade(withDuration: 0.5))
    }
}