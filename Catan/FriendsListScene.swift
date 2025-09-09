import SpriteKit
import UIKit

struct Friend: Codable {
    let id: String
    let username: String
    let friendCode: String
    let avatarIndex: Int
    var isOnline: Bool
    var lastSeen: Date?
}

class FriendsListScene: SKScene, UITextFieldDelegate {
    
    // UI Components
    private var backButton: SKShapeNode!
    private var titleLabel: SKLabelNode!
    private var addFriendButton: SKShapeNode!
    private var friendsScrollNode: SKNode!
    private var noFriendsLabel: SKLabelNode!
    private var addFriendContainer: SKNode?
    private var friendCodeField: UITextField?
    
    // Friends data
    private var friends: [Friend] = []
    private let friendsKey = "savedFriends"
    
    // Layout constants
    private let rowHeight: CGFloat = 80
    private let maxVisibleRows = 6
    
    override func didMove(to view: SKView) {
        self.backgroundColor = SKColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)
        setupUI()
        loadFriends()
        displayFriends()
    }
    
    private func setupUI() {
        // Title
        titleLabel = SKLabelNode(text: "Friends")
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
        
        // Add Friend Button
        addFriendButton = createAddFriendButton()
        addFriendButton.position = CGPoint(x: self.size.width - 60, y: self.size.height - 50)
        addFriendButton.name = "addFriendButton"
        self.addChild(addFriendButton)
        
        // Friends scroll container
        friendsScrollNode = SKNode()
        friendsScrollNode.position = CGPoint(x: 0, y: self.size.height * 0.75)
        self.addChild(friendsScrollNode)
        
        // No friends label (shown when list is empty)
        noFriendsLabel = SKLabelNode(text: "No friends yet")
        noFriendsLabel.fontName = "Helvetica"
        noFriendsLabel.fontSize = self.size.width * 0.05
        noFriendsLabel.fontColor = .white.withAlphaComponent(0.6)
        noFriendsLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.5)
        noFriendsLabel.isHidden = true
        self.addChild(noFriendsLabel)
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
    
    private func createAddFriendButton() -> SKShapeNode {
        let button = SKShapeNode(circleOfRadius: 25)
        button.fillColor = .systemGreen
        button.strokeColor = .white
        button.lineWidth = 2
        
        // Plus sign
        let plusPath = CGMutablePath()
        plusPath.move(to: CGPoint(x: -10, y: 0))
        plusPath.addLine(to: CGPoint(x: 10, y: 0))
        plusPath.move(to: CGPoint(x: 0, y: -10))
        plusPath.addLine(to: CGPoint(x: 0, y: 10))
        
        let plus = SKShapeNode(path: plusPath)
        plus.strokeColor = .white
        plus.lineWidth = 3
        button.addChild(plus)
        
        return button
    }
    
    private func loadFriends() {
        if let data = UserDefaults.standard.data(forKey: friendsKey),
           let decoded = try? JSONDecoder().decode([Friend].self, from: data) {
            friends = decoded
        } else {
            // Load some sample friends for testing
            friends = createSampleFriends()
        }
    }
    
    private func saveFriends() {
        if let encoded = try? JSONEncoder().encode(friends) {
            UserDefaults.standard.set(encoded, forKey: friendsKey)
        }
    }
    
    private func createSampleFriends() -> [Friend] {
        // For demo purposes, create some sample friends
        return [
            Friend(id: "1", username: "AlexTheGreat", friendCode: "ALEX-1234", 
                   avatarIndex: 0, isOnline: true, lastSeen: nil),
            Friend(id: "2", username: "BoardGameBob", friendCode: "BOBB-5678", 
                   avatarIndex: 2, isOnline: false, lastSeen: Date().addingTimeInterval(-3600)),
            Friend(id: "3", username: "CatanChampion", friendCode: "CATA-9012", 
                   avatarIndex: 4, isOnline: true, lastSeen: nil)
        ]
    }
    
    private func displayFriends() {
        // Clear existing friend nodes
        friendsScrollNode.removeAllChildren()
        
        if friends.isEmpty {
            noFriendsLabel.isHidden = false
        } else {
            noFriendsLabel.isHidden = true
            
            for (index, friend) in friends.enumerated() {
                let friendNode = createFriendRow(friend: friend, index: index)
                friendNode.position = CGPoint(x: self.size.width/2, y: -CGFloat(index) * rowHeight)
                friendsScrollNode.addChild(friendNode)
            }
        }
    }
    
    private func createFriendRow(friend: Friend, index: Int) -> SKNode {
        let container = SKNode()
        container.name = "friend_\(friend.id)"
        
        // Background
        let background = SKShapeNode(rectOf: CGSize(width: self.size.width * 0.9, height: rowHeight - 10), 
                                     cornerRadius: 10)
        background.fillColor = .white.withAlphaComponent(0.1)
        background.strokeColor = .white.withAlphaComponent(0.3)
        container.addChild(background)
        
        // Avatar
        let avatarColors: [UIColor] = [
            .systemRed, .systemBlue, .systemGreen, .systemOrange,
            .systemPurple, .systemPink, .systemYellow, .systemCyan
        ]
        let avatar = SKShapeNode(circleOfRadius: 25)
        avatar.fillColor = avatarColors[min(friend.avatarIndex, avatarColors.count - 1)]
        avatar.strokeColor = .white
        avatar.lineWidth = 2
        avatar.position = CGPoint(x: -self.size.width * 0.35, y: 0)
        container.addChild(avatar)
        
        // Username
        let usernameLabel = SKLabelNode(text: friend.username)
        usernameLabel.fontName = "Helvetica-Bold"
        usernameLabel.fontSize = 18
        usernameLabel.fontColor = .white
        usernameLabel.horizontalAlignmentMode = .left
        usernameLabel.position = CGPoint(x: -self.size.width * 0.25, y: 10)
        container.addChild(usernameLabel)
        
        // Online status
        let statusText = friend.isOnline ? "Online" : "Offline"
        let statusColor: UIColor = friend.isOnline ? .systemGreen : .gray
        let statusLabel = SKLabelNode(text: statusText)
        statusLabel.fontName = "Helvetica"
        statusLabel.fontSize = 14
        statusLabel.fontColor = statusColor
        statusLabel.horizontalAlignmentMode = .left
        statusLabel.position = CGPoint(x: -self.size.width * 0.25, y: -15)
        container.addChild(statusLabel)
        
        // Invite button (if online)
        if friend.isOnline {
            let inviteButton = SKShapeNode(rectOf: CGSize(width: 80, height: 30), cornerRadius: 5)
            inviteButton.fillColor = .systemBlue
            inviteButton.strokeColor = .clear
            inviteButton.position = CGPoint(x: self.size.width * 0.3, y: 0)
            inviteButton.name = "invite_\(friend.id)"
            
            let inviteLabel = SKLabelNode(text: "Invite")
            inviteLabel.fontName = "Helvetica"
            inviteLabel.fontSize = 14
            inviteLabel.fontColor = .white
            inviteLabel.verticalAlignmentMode = .center
            inviteLabel.name = inviteButton.name
            inviteButton.addChild(inviteLabel)
            
            container.addChild(inviteButton)
        }
        
        // Remove friend button
        let removeButton = SKShapeNode(circleOfRadius: 15)
        removeButton.fillColor = .systemRed.withAlphaComponent(0.8)
        removeButton.strokeColor = .clear
        removeButton.position = CGPoint(x: self.size.width * 0.4, y: 0)
        removeButton.name = "remove_\(friend.id)"
        
        let xLabel = SKLabelNode(text: "✕")
        xLabel.fontSize = 16
        xLabel.fontColor = .white
        xLabel.verticalAlignmentMode = .center
        xLabel.name = removeButton.name
        removeButton.addChild(xLabel)
        
        container.addChild(removeButton)
        
        return container
    }
    
    private func showAddFriendDialog() {
        // Create overlay
        addFriendContainer = SKNode()
        addFriendContainer!.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
        
        // Background overlay
        let overlay = SKShapeNode(rectOf: self.size)
        overlay.fillColor = .black.withAlphaComponent(0.5)
        overlay.strokeColor = .clear
        overlay.position = .zero
        overlay.zPosition = 10
        overlay.name = "overlay"
        addFriendContainer!.addChild(overlay)
        
        // Dialog box
        let dialog = SKShapeNode(rectOf: CGSize(width: self.size.width * 0.8, height: 200), 
                                 cornerRadius: 15)
        dialog.fillColor = UIColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)
        dialog.strokeColor = .white
        dialog.lineWidth = 2
        dialog.zPosition = 11
        addFriendContainer!.addChild(dialog)
        
        // Title
        let titleLabel = SKLabelNode(text: "Add Friend")
        titleLabel.fontName = "Helvetica-Bold"
        titleLabel.fontSize = 24
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 60)
        titleLabel.zPosition = 12
        addFriendContainer!.addChild(titleLabel)
        
        // Instructions
        let instructionLabel = SKLabelNode(text: "Enter friend code:")
        instructionLabel.fontName = "Helvetica"
        instructionLabel.fontSize = 16
        instructionLabel.fontColor = .white
        instructionLabel.position = CGPoint(x: 0, y: 20)
        instructionLabel.zPosition = 12
        addFriendContainer!.addChild(instructionLabel)
        
        // Text field
        friendCodeField = UITextField()
        friendCodeField!.frame = CGRect(
            x: self.size.width * 0.1,
            y: self.size.height * 0.48,
            width: self.size.width * 0.8,
            height: 40
        )
        friendCodeField!.backgroundColor = .white
        friendCodeField!.textColor = .black
        friendCodeField!.font = UIFont.systemFont(ofSize: 18)
        friendCodeField!.borderStyle = .roundedRect
        friendCodeField!.placeholder = "XXXX-XXXX"
        friendCodeField!.textAlignment = .center
        friendCodeField!.autocapitalizationType = .allCharacters
        friendCodeField!.autocorrectionType = .no
        friendCodeField!.delegate = self
        friendCodeField!.returnKeyType = .done
        self.view?.addSubview(friendCodeField!)
        
        // Add button
        let addButton = SKShapeNode(rectOf: CGSize(width: 100, height: 40), cornerRadius: 8)
        addButton.fillColor = .systemGreen
        addButton.strokeColor = .clear
        addButton.position = CGPoint(x: -60, y: -60)
        addButton.zPosition = 12
        addButton.name = "confirmAddFriend"
        
        let addLabel = SKLabelNode(text: "Add")
        addLabel.fontName = "Helvetica-Bold"
        addLabel.fontSize = 18
        addLabel.fontColor = .white
        addLabel.verticalAlignmentMode = .center
        addLabel.name = "confirmAddFriend"
        addButton.addChild(addLabel)
        addFriendContainer!.addChild(addButton)
        
        // Cancel button
        let cancelButton = SKShapeNode(rectOf: CGSize(width: 100, height: 40), cornerRadius: 8)
        cancelButton.fillColor = .systemRed
        cancelButton.strokeColor = .clear
        cancelButton.position = CGPoint(x: 60, y: -60)
        cancelButton.zPosition = 12
        cancelButton.name = "cancelAddFriend"
        
        let cancelLabel = SKLabelNode(text: "Cancel")
        cancelLabel.fontName = "Helvetica-Bold"
        cancelLabel.fontSize = 18
        cancelLabel.fontColor = .white
        cancelLabel.verticalAlignmentMode = .center
        cancelLabel.name = "cancelAddFriend"
        cancelButton.addChild(cancelLabel)
        addFriendContainer!.addChild(cancelButton)
        
        self.addChild(addFriendContainer!)
    }
    
    private func hideAddFriendDialog() {
        friendCodeField?.removeFromSuperview()
        friendCodeField = nil
        addFriendContainer?.removeFromParent()
        addFriendContainer = nil
    }
    
    private func addFriend(withCode code: String) {
        // In a real app, this would verify the friend code with a server
        // For now, create a mock friend
        let newFriend = Friend(
            id: UUID().uuidString,
            username: "Player_\(code.suffix(4))",
            friendCode: code,
            avatarIndex: Int.random(in: 0..<8),
            isOnline: Bool.random(),
            lastSeen: Bool.random() ? nil : Date().addingTimeInterval(-Double.random(in: 0...86400))
        )
        
        friends.append(newFriend)
        saveFriends()
        displayFriends()
        
        // Show success message
        let successLabel = SKLabelNode(text: "Friend added!")
        successLabel.fontName = "Helvetica-Bold"
        successLabel.fontSize = 20
        successLabel.fontColor = .systemGreen
        successLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.8)
        self.addChild(successLabel)
        
        successLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
    
    private func removeFriend(withId id: String) {
        friends.removeAll { $0.id == id }
        saveFriends()
        displayFriends()
    }
    
    private func inviteFriend(withId id: String) {
        // In a real app, this would send an invitation through the network
        guard let friend = friends.first(where: { $0.id == id }) else { return }
        
        // Show invitation sent message
        let inviteLabel = SKLabelNode(text: "Invitation sent to \(friend.username)")
        inviteLabel.fontName = "Helvetica"
        inviteLabel.fontSize = 18
        inviteLabel.fontColor = .systemGreen
        inviteLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.1)
        self.addChild(inviteLabel)
        
        inviteLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.5),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
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
        friendCodeField?.resignFirstResponder()
        
        if let nodeName = node.name {
            if nodeName == "backButton" {
                let multiplayerMenuScene = MultiplayerMenuScene(size: self.size)
                multiplayerMenuScene.scaleMode = .aspectFill
                self.view?.presentScene(multiplayerMenuScene, transition: SKTransition.fade(withDuration: 0.5))
                
            } else if nodeName == "addFriendButton" {
                showAddFriendDialog()
                
            } else if nodeName == "confirmAddFriend" {
                if let code = friendCodeField?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !code.isEmpty {
                    addFriend(withCode: code)
                    hideAddFriendDialog()
                }
                
            } else if nodeName == "cancelAddFriend" || nodeName == "overlay" {
                hideAddFriendDialog()
                
            } else if nodeName.starts(with: "invite_") {
                let friendId = String(nodeName.dropFirst(7))
                inviteFriend(withId: friendId)
                
            } else if nodeName.starts(with: "remove_") {
                let friendId = String(nodeName.dropFirst(7))
                removeFriend(withId: friendId)
            }
        }
    }
    
    override func willMove(from view: SKView) {
        // Clean up text field when leaving scene
        friendCodeField?.removeFromSuperview()
    }
}