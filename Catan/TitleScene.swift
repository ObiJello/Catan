import SpriteKit
import UIKit  // for using UIImage (SF Symbols)

class TitleScene: SKScene {
    
    // Define node properties for easy access if needed
    private var singleplayerButton: SKShapeNode!
    private var multiplayerButton: SKShapeNode!
    
    override func didMove(to view: SKView) {
        // 1. Set background color
        self.backgroundColor = SKColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)  // #177EDC
        
        // 2. Add the title label at top-center
        let titleLabel = SKLabelNode(text: "CatanClone")
        titleLabel.fontName = "Helvetica-Bold"          // choose a bold font
        titleLabel.fontSize = self.size.width * 0.1     // scale font size relative to screen width
        titleLabel.fontColor = .white
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.75)
        // Centering with anchor at (0,0) scene: use half width and a percentage of height&#8203;:contentReference[oaicite:0]{index=0}
        self.addChild(titleLabel)
        
        // 3. Create Singleplayer and Multiplayer buttons (large rounded rectangles)
        let buttonWidth  = self.size.width * 0.7    // 70% of screen width
        let buttonHeight = self.size.width * 0.15   // 15% of screen width (gives a decent height)
        let cornerRadius: CGFloat = 10.0
        
        // Singleplayer button shape
        singleplayerButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: cornerRadius)
        singleplayerButton.fillColor = .white
        singleplayerButton.strokeColor = .clear    // no border
        singleplayerButton.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.5)
        singleplayerButton.name = "singleplayerButton"
        
        // Label for Singleplayer
        let singleLabel = SKLabelNode(text: "Singleplayer")
        singleLabel.fontName = "Helvetica"
        singleLabel.fontSize =  min(24, self.size.width * 0.07)  // cap at 24 or 7% of width
        singleLabel.fontColor = .black
        singleLabel.horizontalAlignmentMode = .center
        singleLabel.verticalAlignmentMode = .center
        singleLabel.position = .zero
        singleLabel.name = "singleplayerButton"
        singleplayerButton.addChild(singleLabel)
        
        self.addChild(singleplayerButton)
        
        // Multiplayer button shape
        multiplayerButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: cornerRadius)
        multiplayerButton.fillColor = .white
        multiplayerButton.strokeColor = .clear
        multiplayerButton.position = CGPoint(x: self.size.width/2, y: self.size.height * 0.35)
        multiplayerButton.name = "multiplayerButton"
        
        // Label for Multiplayer
        let multiLabel = SKLabelNode(text: "Multiplayer")
        multiLabel.fontName = "Helvetica"
        multiLabel.fontSize = min(24, self.size.width * 0.07)
        multiLabel.fontColor = .black
        multiLabel.horizontalAlignmentMode = .center
        multiLabel.verticalAlignmentMode = .center
        multiLabel.position = .zero
        multiLabel.name = "multiplayerButton"
        multiplayerButton.addChild(multiLabel)
        
        self.addChild(multiplayerButton)
        
        // 4. Create hexagon icon buttons for Settings, Shop, Profile
        // Define a hexagon shape path centered at (0,0)
        let hexRadius = self.size.width * 0.08   // radius relative to screen size (8% of width)
        func createHexagonShape(radius: CGFloat) -> SKShapeNode {
            // Create a hexagon CGPath with 6 points around a circle&#8203;:contentReference[oaicite:1]{index=1}
            let path = CGMutablePath()
            // Start at angle 0 (point to the right)
            path.move(to: CGPoint(x: radius, y: 0))
            for angle in stride(from: 60.0, through: 300.0, by: 60.0) {
                let radians = CGFloat(angle) * .pi / 180.0
                path.addLine(to: CGPoint(x: cos(radians) * radius, y: sin(radians) * radius))
            }
            path.closeSubpath()
            // Create an SKShapeNode from the path
            let shape = SKShapeNode(path: path)
            shape.fillColor = .white
            shape.strokeColor = .white
            return shape
        }
        
        // Helper to create an icon sprite from SF Symbols (returns black icon by default)
        func iconSprite(systemName: String, size: CGSize) -> SKSpriteNode? {
            if let image = UIImage(systemName: systemName) {
                // Optionally, to ensure the symbol renders with color, use alwaysOriginal rendering
                let coloredImage = image.withTintColor(.black, renderingMode: .alwaysOriginal)
                let texture = SKTexture(image: coloredImage)
                let icon = SKSpriteNode(texture: texture)
                icon.size = size
                return icon
            }
            return nil
        }
        
        // Settings icon (gear) at bottom-right
        let settingsButton = createHexagonShape(radius: hexRadius)
        settingsButton.position = CGPoint(x: self.size.width - hexRadius - 20, y: hexRadius + 20)
        settingsButton.name = "settingsButton"
        if let gearIcon = iconSprite(systemName: "gearshape.fill", size: CGSize(width: hexRadius, height: hexRadius)) {
            gearIcon.position = .zero
            settingsButton.addChild(gearIcon)
        }
        self.addChild(settingsButton)
        
        // Shop icon (cart) at top-right
        let shopButton = createHexagonShape(radius: hexRadius)
        shopButton.position = CGPoint(x: self.size.width - hexRadius - 20, y: self.size.height - hexRadius - 20)
        shopButton.name = "shopButton"
        if let cartIcon = iconSprite(systemName: "cart.fill", size: CGSize(width: hexRadius, height: hexRadius)) {
            cartIcon.position = .zero
            shopButton.addChild(cartIcon)
        }
        self.addChild(shopButton)
        
        // Profile icon (user) at top-left
        let profileButton = createHexagonShape(radius: hexRadius)
        profileButton.position = CGPoint(x: hexRadius + 20, y: self.size.height - hexRadius - 20)
        profileButton.name = "profileButton"
        if let userIcon = iconSprite(systemName: "person.fill", size: CGSize(width: hexRadius, height: hexRadius)) {
            userIcon.position = .zero
            profileButton.addChild(userIcon)
        }
        self.addChild(profileButton)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let node = self.atPoint(location) 
        
        // Check which node was tapped by name
        if let nodeName = node.name {
            /*if nodeName == "singleplayerButton" {
                // Transition to the main GameScene when Singleplayer is tapped
                let gameScene = GameScene(size: self.size)   // instantiate game scene with same size
                gameScene.scaleMode = .aspectFill
                let transition = SKTransition.fade(withDuration: 0.5)
                self.view?.presentScene(gameScene, transition: transition)
                // Use view?.presentScene to switch scenes&#8203;:contentReference[oaicite:2]{index=2}
            }*/
            if node.name == "singleplayerButton" {
                let configScene = GameConfigScene(size: self.size)
                configScene.scaleMode = .aspectFill
                self.view?.presentScene(configScene, transition: SKTransition.fade(withDuration: 0.5))
            } else if nodeName == "multiplayerButton" {
                // Navigate to Multiplayer Menu Scene
                let multiplayerMenuScene = MultiplayerMenuScene(size: self.size)
                multiplayerMenuScene.scaleMode = .aspectFill
                self.view?.presentScene(multiplayerMenuScene, transition: SKTransition.fade(withDuration: 0.5))
            }
            // (Optional) you could handle settingsButton, shopButton, profileButton taps here in the future
        }
    }
}
