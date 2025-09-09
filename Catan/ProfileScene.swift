import SpriteKit
import UIKit

class ProfileScene: SKScene, UITextFieldDelegate {
    
    // UI Components
    private var backButton: SKShapeNode!
    private var titleLabel: SKLabelNode!
    private var usernameField: UITextField!
    private var avatarNode: SKShapeNode!
    private var statsContainer: SKNode!
    private var saveButton: SKShapeNode!
    private var friendCodeLabel: SKLabelNode!
    private var avatarButtons: [SKShapeNode] = []
    
    // Profile data
    private var selectedAvatarIndex: Int = 0
    private let avatarColors: [UIColor] = [
        .systemRed, .systemBlue, .systemGreen, .systemOrange,
        .systemPurple, .systemPink, .systemYellow, .systemCyan
    ]
    
    override func didMove(to view: SKView) {
        self.backgroundColor = SKColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)
        setupUI()
        loadProfileData()
    }
    
    private func setupUI() {
        // Title
        titleLabel = SKLabelNode(text: "Profile")
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
        
        // Avatar Section
        setupAvatarSection()
        
        // Username Section
        setupUsernameSection()
        
        // Friend Code Section
        setupFriendCodeSection()
        
        // Stats Section
        setupStatsSection()
        
        // Save Button
        saveButton = createSaveButton()
        saveButton.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.15)
        saveButton.name = "saveButton"
        self.addChild(saveButton)
    }
    
    private func setupAvatarSection() {
        // Avatar display
        avatarNode = SKShapeNode(circleOfRadius: 50)
        avatarNode.fillColor = avatarColors[selectedAvatarIndex]
        avatarNode.strokeColor = .white
        avatarNode.lineWidth = 3
        avatarNode.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.7)
        self.addChild(avatarNode)
        
        // Avatar selection buttons
        let avatarY = self.size.height * 0.55
        let spacing = self.size.width / CGFloat(avatarColors.count + 1)
        
        for (index, color) in avatarColors.enumerated() {
            let button = SKShapeNode(circleOfRadius: 20)
            button.fillColor = color
            button.strokeColor = index == selectedAvatarIndex ? .white : .clear
            button.lineWidth = 2
            button.position = CGPoint(x: spacing * CGFloat(index + 1), y: avatarY)
            button.name = "avatar_\(index)"
            avatarButtons.append(button)
            self.addChild(button)
        }
    }
    
    private func setupUsernameSection() {
        // Username label
        let usernameLabel = SKLabelNode(text: "Username:")
        usernameLabel.fontName = "Helvetica"
        usernameLabel.fontSize = self.size.width * 0.045
        usernameLabel.fontColor = .white
        usernameLabel.horizontalAlignmentMode = .left
        usernameLabel.position = CGPoint(x: self.size.width * 0.15, y: self.size.height * 0.45)
        self.addChild(usernameLabel)
        
        // Username text field
        usernameField = UITextField()
        usernameField.frame = CGRect(
            x: self.size.width * 0.15,
            y: self.size.height * 0.58,
            width: self.size.width * 0.7,
            height: 40
        )
        usernameField.backgroundColor = .white
        usernameField.textColor = .black
        usernameField.font = UIFont.systemFont(ofSize: 18)
        usernameField.borderStyle = .roundedRect
        usernameField.placeholder = "Enter username"
        usernameField.autocorrectionType = .no
        usernameField.autocapitalizationType = .none
        usernameField.delegate = self
        usernameField.returnKeyType = .done
        self.view?.addSubview(usernameField)
    }
    
    private func setupFriendCodeSection() {
        // Friend code label
        let friendCodeTitleLabel = SKLabelNode(text: "Friend Code:")
        friendCodeTitleLabel.fontName = "Helvetica"
        friendCodeTitleLabel.fontSize = self.size.width * 0.045
        friendCodeTitleLabel.fontColor = .white
        friendCodeTitleLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.35)
        self.addChild(friendCodeTitleLabel)
        
        // Generate or load friend code
        let friendCode = UserDefaults.standard.string(forKey: "friendCode") ?? generateFriendCode()
        friendCodeLabel = SKLabelNode(text: friendCode)
        friendCodeLabel.fontName = "Helvetica-Bold"
        friendCodeLabel.fontSize = self.size.width * 0.06
        friendCodeLabel.fontColor = .white
        friendCodeLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.3)
        self.addChild(friendCodeLabel)
        
        // Copy button
        let copyButton = createCopyButton()
        copyButton.position = CGPoint(x: self.size.width * 0.75, y: self.size.height * 0.3)
        copyButton.name = "copyButton"
        self.addChild(copyButton)
    }
    
    private func setupStatsSection() {
        statsContainer = SKNode()
        statsContainer.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.22)
        
        // Load stats from UserDefaults
        let wins = UserDefaults.standard.integer(forKey: "totalWins")
        let games = UserDefaults.standard.integer(forKey: "totalGames")
        let winRate = games > 0 ? Int((Double(wins) / Double(games)) * 100) : 0
        
        // Stats labels
        let statsText = "Games: \(games)  |  Wins: \(wins)  |  Win Rate: \(winRate)%"
        let statsLabel = SKLabelNode(text: statsText)
        statsLabel.fontName = "Helvetica"
        statsLabel.fontSize = self.size.width * 0.04
        statsLabel.fontColor = .white
        statsContainer.addChild(statsLabel)
        
        self.addChild(statsContainer)
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
    
    private func createSaveButton() -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: self.size.width * 0.5, height: 50), cornerRadius: 10)
        button.fillColor = .systemGreen
        button.strokeColor = .clear
        
        let label = SKLabelNode(text: "Save Profile")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 20
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        button.addChild(label)
        
        return button
    }
    
    private func createCopyButton() -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: 60, height: 30), cornerRadius: 5)
        button.fillColor = .white.withAlphaComponent(0.2)
        button.strokeColor = .white
        
        let label = SKLabelNode(text: "Copy")
        label.fontName = "Helvetica"
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        button.addChild(label)
        
        return button
    }
    
    private func generateFriendCode() -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let code = String((0..<8).map { _ in letters.randomElement()! })
        let formattedCode = "\(code.prefix(4))-\(code.suffix(4))"
        UserDefaults.standard.set(formattedCode, forKey: "friendCode")
        return formattedCode
    }
    
    private func loadProfileData() {
        // Load username
        if let username = UserDefaults.standard.string(forKey: "playerUsername") {
            usernameField.text = username
        }
        
        // Load avatar
        selectedAvatarIndex = UserDefaults.standard.integer(forKey: "selectedAvatar")
        avatarNode.fillColor = avatarColors[selectedAvatarIndex]
        updateAvatarSelection()
    }
    
    private func saveProfile() {
        // Save username
        let username = usernameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !username.isEmpty {
            UserDefaults.standard.set(username, forKey: "playerUsername")
        }
        
        // Save avatar
        UserDefaults.standard.set(selectedAvatarIndex, forKey: "selectedAvatar")
        
        // Show save confirmation
        let savedLabel = SKLabelNode(text: "Profile Saved!")
        savedLabel.fontName = "Helvetica-Bold"
        savedLabel.fontSize = 20
        savedLabel.fontColor = .systemGreen
        savedLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.08)
        self.addChild(savedLabel)
        
        savedLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
    
    private func updateAvatarSelection() {
        for (index, button) in avatarButtons.enumerated() {
            button.strokeColor = index == selectedAvatarIndex ? .white : .clear
        }
    }
    
    // UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = self.atPoint(location)
        
        // Dismiss keyboard if active
        usernameField.resignFirstResponder()
        
        if let nodeName = node.name {
            if nodeName == "backButton" {
                // Clean up text field before transitioning
                usernameField.removeFromSuperview()
                
                let multiplayerMenuScene = MultiplayerMenuScene(size: self.size)
                multiplayerMenuScene.scaleMode = .aspectFill
                self.view?.presentScene(multiplayerMenuScene, transition: SKTransition.fade(withDuration: 0.5))
                
            } else if nodeName == "saveButton" {
                saveProfile()
                
            } else if nodeName == "copyButton" {
                // Copy friend code to clipboard
                UIPasteboard.general.string = friendCodeLabel.text
                
                // Show copied confirmation
                let copiedLabel = SKLabelNode(text: "Copied!")
                copiedLabel.fontName = "Helvetica"
                copiedLabel.fontSize = 14
                copiedLabel.fontColor = .systemGreen
                copiedLabel.position = CGPoint(x: self.size.width * 0.75, y: self.size.height * 0.26)
                self.addChild(copiedLabel)
                
                copiedLabel.run(SKAction.sequence([
                    SKAction.wait(forDuration: 1.5),
                    SKAction.fadeOut(withDuration: 0.3),
                    SKAction.removeFromParent()
                ]))
                
            } else if nodeName.starts(with: "avatar_") {
                // Avatar selection
                if let indexStr = nodeName.split(separator: "_").last,
                   let index = Int(indexStr) {
                    selectedAvatarIndex = index
                    avatarNode.fillColor = avatarColors[index]
                    updateAvatarSelection()
                }
            }
        }
    }
    
    override func willMove(from view: SKView) {
        // Clean up text field when leaving scene
        usernameField.removeFromSuperview()
    }
}