import SpriteKit
import UIKit

class GameConfigScene: SKScene, UITextFieldDelegate {
    // Color options for players (player and bots)
    private let colorOptions = ["black", "blue", "bronze", "gold", "green",
                                "mysticblue", "orange", "pink", "purple",
                                "red", "silver", "white"]
    
    // Currently selected colors (store names of colors)
    private var selectedPlayerColorName: String = "black"
    private var selectedBotColorNames: [String] = ["orange", "red", "blue"]
    
    // UI components
    private var titleLabel: UILabel!
    private var playerColorLabel: UILabel!
    private var botColorLabels: [UILabel] = []
    private var playerColorButton: UIButton!
    private var botColorButtons: [UIButton] = []
    private var victoryLabel: UILabel!
    private var victoryPointsField: UITextField!
    private var victorySlider: UISlider!
    private var discardLabel: UILabel!
    private var discardField: UITextField!
    private var discardSlider: UISlider!
    private var startButton: UIButton!
    
    // Configuration value ranges and defaults
    private let victoryMin = 3, victoryMax = 20, victoryDefault = 10
    private let discardMin = 3, discardMax = 20, discardDefault = 7
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        // Set background color for contrast
        self.backgroundColor = SKColor(red: 23/255, green: 126/255, blue: 220/255, alpha: 1)

        // Calculate layout metrics
        let margin: CGFloat = 20
        let width = view.bounds.size.width
        let height = view.bounds.size.height
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        let safeTop = safeFrame.minY
        let safeBottom = height - safeFrame.maxY
        
        // Determine max label width for alignment (to align all control start positions)
        let labelTexts = ["Player Color:", "Bot 1 Color:", "Bot 2 Color:", "Bot 3 Color:",
                          "Victory Point Goal:", "Card Discard Limit:"]
        var maxLabelWidth: CGFloat = 0
        for text in labelTexts {
            let size = (text as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 17)])
            if size.width > maxLabelWidth {
                maxLabelWidth = size.width
            }
        }
        let controlX = margin + maxLabelWidth + 10  // X position where controls (dropdowns/fields) start
        let controlHeight: CGFloat = 30            // Standard height for controls (buttons, text fields)
        
        // MARK: - Title Section
        titleLabel = UILabel()
        titleLabel.text = "Game Configuration"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .white
        // Position title at top-center
        titleLabel.frame = CGRect(x: 0, y: safeTop + 20, width: width, height: 30)
        view.addSubview(titleLabel)
        
        // Start placing form elements below the title
        var currentY = titleLabel.frame.maxY + 20
        
        // MARK: - 1. Player Color Selection (Dropdown)
        playerColorLabel = UILabel()
        playerColorLabel.text = "Player Color:"
        playerColorLabel.font = UIFont.systemFont(ofSize: 17)
        playerColorLabel.textColor = .white
        playerColorLabel.textAlignment = .right
        playerColorLabel.frame = CGRect(x: margin, y: currentY,
                                        width: maxLabelWidth, height: controlHeight)
        view.addSubview(playerColorLabel)
        
        playerColorButton = UIButton(type: .system)
        playerColorButton.frame = CGRect(x: controlX, y: currentY, width: 140, height: controlHeight)
        playerColorButton.setTitle(selectedPlayerColorName.capitalized, for: .normal)
        playerColorButton.setTitleColor(.white, for: .normal)
        // Style the dropdown button to look like an input field
        playerColorButton.layer.borderWidth = 1
        playerColorButton.layer.borderColor = UIColor.white.cgColor
        playerColorButton.layer.cornerRadius = 5
        playerColorButton.contentHorizontalAlignment = .left
        // Create dropdown menu for color options
        var playerMenuActions: [UIAction] = []
        for color in colorOptions {
            let action = UIAction(title: color.capitalized) { [weak self] _ in
                guard let self = self else { return }
                self.selectedPlayerColorName = color
                self.playerColorButton.setTitle(color.capitalized, for: .normal)
            }
            playerMenuActions.append(action)
        }
        playerColorButton.menu = UIMenu(children: playerMenuActions)
        playerColorButton.showsMenuAsPrimaryAction = true
        view.addSubview(playerColorButton)
        
        currentY += controlHeight + 15  // move down for next section
        
        // MARK: - 2. Bot Players Color Selection (Dropdowns)
        botColorButtons = []
        botColorLabels = []
        for i in 1...3 {
            let botLabel = UILabel()
            botLabel.text = "Bot \(i) Color:"
            botLabel.font = UIFont.systemFont(ofSize: 17)
            botLabel.textColor = .white
            botLabel.textAlignment = .right
            botLabel.frame = CGRect(x: margin, y: currentY,
                                     width: maxLabelWidth, height: controlHeight)
            view.addSubview(botLabel)
            botColorLabels.append(botLabel)
            
            let botButton = UIButton(type: .system)
            botButton.frame = CGRect(x: controlX, y: currentY, width: 140, height: controlHeight)
            // Set initial selection for this bot (use default list or first option)
            let defaultColor = (i-1 < selectedBotColorNames.count)
                                ? selectedBotColorNames[i-1]
                                : colorOptions.first!
            selectedBotColorNames[i-1] = defaultColor
            botButton.setTitle(defaultColor.capitalized, for: .normal)
            botButton.setTitleColor(.white, for: .normal)
            botButton.layer.borderWidth = 1
            botButton.layer.borderColor = UIColor.white.cgColor
            botButton.layer.cornerRadius = 5
            botButton.contentHorizontalAlignment = .left
            // Create dropdown menu for bot color options
            var botMenuActions: [UIAction] = []
            for color in colorOptions {
                let action = UIAction(title: color.capitalized) { [weak self] _ in
                    guard let self = self else { return }
                    self.selectedBotColorNames[i-1] = color
                    botButton.setTitle(color.capitalized, for: .normal)
                }
                botMenuActions.append(action)
            }
            botButton.menu = UIMenu(children: botMenuActions)
            botButton.showsMenuAsPrimaryAction = true
            view.addSubview(botButton)
            botColorButtons.append(botButton)
            
            currentY += controlHeight + 15
        }
        
        // MARK: - 3. Victory Point Goal (Number Input + Slider)
        victoryLabel = UILabel()
        victoryLabel.text = "Victory Point Goal:"
        victoryLabel.font = UIFont.systemFont(ofSize: 17)
        victoryLabel.textColor = .white
        victoryLabel.textAlignment = .right
        victoryLabel.frame = CGRect(x: margin, y: currentY,
                                     width: maxLabelWidth, height: controlHeight)
        view.addSubview(victoryLabel)
        
        victoryPointsField = UITextField()
        victoryPointsField.frame = CGRect(x: controlX, y: currentY, width: 50, height: controlHeight)
        victoryPointsField.borderStyle = .roundedRect
        victoryPointsField.keyboardType = .numberPad
        victoryPointsField.text = "\(victoryDefault)"
        victoryPointsField.textColor = .black
        victoryPointsField.backgroundColor = .white
        victoryPointsField.delegate = self
        view.addSubview(victoryPointsField)
        
        // Slider positioned to the right of the number field
        let sliderX = controlX + 50 + 10  // text field width (50) + gap
        let sliderWidth = width - margin - sliderX
        victorySlider = UISlider()
        victorySlider.frame = CGRect(x: sliderX, y: currentY, width: sliderWidth, height: controlHeight)
        victorySlider.minimumValue = Float(victoryMin)
        victorySlider.maximumValue = Float(victoryMax)
        victorySlider.value = Float(victoryDefault)
        victorySlider.minimumTrackTintColor = .green
        victorySlider.thumbTintColor = .green
        victorySlider.isContinuous = true
        victorySlider.addTarget(self, action: #selector(victorySliderChanged(_:)), for: .valueChanged)
        view.addSubview(victorySlider)
        
        currentY += controlHeight + 15
        
        // MARK: - 4. Card Discard Limit (Number Input + Slider)
        discardLabel = UILabel()
        discardLabel.text = "Card Discard Limit:"
        discardLabel.font = UIFont.systemFont(ofSize: 17)
        discardLabel.textColor = .white
        discardLabel.textAlignment = .right
        discardLabel.frame = CGRect(x: margin, y: currentY,
                                     width: maxLabelWidth, height: controlHeight)
        view.addSubview(discardLabel)
        
        discardField = UITextField()
        discardField.frame = CGRect(x: controlX, y: currentY, width: 50, height: controlHeight)
        discardField.borderStyle = .roundedRect
        discardField.keyboardType = .numberPad
        discardField.text = "\(discardDefault)"
        discardField.textColor = .black
        discardField.backgroundColor = .white
        discardField.delegate = self
        view.addSubview(discardField)
        
        discardSlider = UISlider()
        discardSlider.frame = CGRect(x: sliderX, y: currentY, width: sliderWidth, height: controlHeight)
        discardSlider.minimumValue = Float(discardMin)
        discardSlider.maximumValue = Float(discardMax)
        discardSlider.value = Float(discardDefault)
        discardSlider.minimumTrackTintColor = .green
        discardSlider.thumbTintColor = .green
        discardSlider.isContinuous = true
        discardSlider.addTarget(self, action: #selector(discardSliderChanged(_:)), for: .valueChanged)
        view.addSubview(discardSlider)
        
        currentY += controlHeight + 30  // extra gap before the start button
        
        // MARK: - 5. Start Game Button
        startButton = UIButton(type: .system)
        startButton.setTitle("Start Game", for: .normal)
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = .systemBlue
        startButton.layer.cornerRadius = 5
        let buttonWidth: CGFloat = 160
        let buttonHeight: CGFloat = 44
        // Center the button at the bottom, above the safe area
        startButton.frame = CGRect(x: (width - buttonWidth) / 2,
                                   y: height - safeBottom - 20 - buttonHeight,
                                   width: buttonWidth, height: buttonHeight)
        startButton.addTarget(self, action: #selector(startGamePressed), for: .touchUpInside)
        view.addSubview(startButton)
    }
    
    // MARK: - UISlider Actions (sync slider with text field)
    @objc private func victorySliderChanged(_ sender: UISlider) {
        // Round slider value to nearest integer and update text field
        let val = Int(sender.value.rounded())
        sender.value = Float(val)
        victoryPointsField.text = "\(val)"
    }
    
    @objc private func discardSliderChanged(_ sender: UISlider) {
        let val = Int(sender.value.rounded())
        sender.value = Float(val)
        discardField.text = "\(val)"
    }
    
    // MARK: - UITextFieldDelegate (sync text field with slider)
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        // Only allow numeric characters in the text fields
        if string.isEmpty { return true }  // allow backspace
        return string.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // Clamp the value within allowed range and update the corresponding slider
        if textField == victoryPointsField {
            let value = Int(textField.text ?? "") ?? victoryDefault
            let clamped = max(victoryMin, min(victoryMax, value))
            textField.text = "\(clamped)"
            victorySlider.value = Float(clamped)
        } else if textField == discardField {
            let value = Int(textField.text ?? "") ?? discardDefault
            let clamped = max(discardMin, min(discardMax, value))
            textField.text = "\(clamped)"
            discardSlider.value = Float(clamped)
        }
    }
    
    // MARK: - Start Game: Transition to GameScene with selected settings
    @objc private func startGamePressed() {
        // Dismiss keyboard (if a text field was active)
        self.view?.endEditing(true)
        // Gather selected settings
        let playerColor = selectedPlayerColorName
        let botColors = selectedBotColorNames
        let victoryGoal = Int(victorySlider.value.rounded())
        let discardLimit = Int(discardSlider.value.rounded())
        // Transition to the main GameScene, passing the configuration
        if let gameScene = GameScene(fileNamed: "GameScene") {
            // Pass selected settings via userData dictionary (or set properties if defined)
            gameScene.userData = NSMutableDictionary()
            gameScene.userData?["playerColor"] = playerColor
            gameScene.userData?["botColors"] = botColors
            gameScene.userData?["victoryPointGoal"] = victoryGoal
            gameScene.userData?["discardLimit"] = discardLimit
            // Present the game scene
            self.view?.presentScene(gameScene, transition: SKTransition.crossFade(withDuration: 0.5))
        }
    }
    
    // MARK: - Cleanup when leaving this scene
    override func willMove(from view: SKView) {
        super.willMove(from: view)
        // Remove all UI subviews that were added to the view
        titleLabel?.removeFromSuperview()
        playerColorLabel?.removeFromSuperview()
        botColorLabels.forEach { $0.removeFromSuperview() }
        victoryLabel?.removeFromSuperview()
        discardLabel?.removeFromSuperview()
        playerColorButton?.removeFromSuperview()
        botColorButtons.forEach { $0.removeFromSuperview() }
        victoryPointsField?.removeFromSuperview()
        victorySlider?.removeFromSuperview()
        discardField?.removeFromSuperview()
        discardSlider?.removeFromSuperview()
        startButton?.removeFromSuperview()
    }
    
    // MARK: - Dismiss keyboard on background tap
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view?.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
}
