//
//  ViewController.swift
//  Example
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import FolioReaderKit

class ViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var verticalScrollButton: UIButton!
    @IBOutlet weak var horizontalScrollButton: UIButton!

    let folioReader = FolioReader()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        // Configure the UI to showcase both scroll mode fixes
        titleLabel.text = "Scroll Mode Demo"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center

        descriptionLabel.text = """
        This demo showcases the improved scrolling in FolioReaderKit for both modes:

        ✅ Complete content rendering (no trimming)
        ✅ Accurate slider/scrubber tracking
        ✅ Proper content sizing
        ✅ Dynamic size adjustments

        Try both modes and notice:
        • Slider accurately tracks your position
        • All content is accessible
        • Smooth scrolling experience
        • Font changes update content size
        """
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)

        // Setup buttons
        setupButton(verticalScrollButton, title: "📖 Vertical Scroll\n\"The Silver Chair\"", color: UIColor(red: 0.416, green: 0.8, blue: 0.314, alpha: 1.0))
        setupButton(horizontalScrollButton, title: "📚 Horizontal Scroll\n\"Sherlock Holmes\"", color: UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0))

        // Set cover images
        setCoverImages()
    }

    private func setupButton(_ button: UIButton, title: String, color: UIColor) {
        button.setTitle(title, for: .normal)
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
    }

    private func readerConfiguration(scrollDirection: FolioReaderScrollDirection, identifier: String) -> FolioReaderConfig {
        let config = FolioReaderConfig(withIdentifier: identifier)

        // Set the scroll direction
        config.scrollDirection = scrollDirection
        config.shouldHideNavigationOnTap = scrollDirection == .horizontal // Hide nav for horizontal for better demo

        // Enable features to showcase the reader capabilities
        config.canChangeFontStyle = true
        config.canChangeScrollDirection = true
        config.displayTitle = true
        config.enableTTS = true
        config.allowSharing = true

        // Configure colors for better experience
        let tintColor = scrollDirection == .vertical ?
            UIColor(red: 0.416, green: 0.8, blue: 0.314, alpha: 1.0) : // Green for vertical
            UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)       // Blue for horizontal

        config.tintColor = tintColor
        config.menuBackgroundColor = UIColor.white
        config.menuTextColor = UIColor(red: 0.463, green: 0.463, blue: 0.463, alpha: 1.0)
        config.menuTextColorSelected = tintColor

        // Dark mode colors
        config.nightModeBackground = UIColor(red: 0.075, green: 0.075, blue: 0.075, alpha: 1.0)
        config.nightModeMenuBackground = UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)
        config.nightModeSeparatorColor = UIColor(white: 0.5, alpha: 0.2)

        return config
    }

    private func setCoverImages() {
        // Set cover for vertical scroll book
        if let silverChairPath = Bundle.main.path(forResource: "The Silver Chair", ofType: "epub") {
            do {
                let image = try FolioReader.getCoverImage(silverChairPath)
                verticalScrollButton.setBackgroundImage(image, for: .normal)
                verticalScrollButton.imageView?.contentMode = .scaleAspectFit
                verticalScrollButton.imageView?.alpha = 0.3
            } catch {
                print("Error loading vertical scroll cover: \(error)")
            }
        }

        // Set cover for horizontal scroll book
        if let holmesPath = Bundle.main.path(forResource: "The Adventures Of Sherlock Holmes - Adventure I", ofType: "epub") {
            do {
                let image = try FolioReader.getCoverImage(holmesPath)
                horizontalScrollButton.setBackgroundImage(image, for: .normal)
                horizontalScrollButton.imageView?.contentMode = .scaleAspectFit
                horizontalScrollButton.imageView?.alpha = 0.3
            } catch {
                print("Error loading horizontal scroll cover: \(error)")
            }
        }
    }

    @IBAction func openVerticalScrollBook(_ sender: UIButton) {
        guard let bookPath = Bundle.main.path(forResource: "The Silver Chair", ofType: "epub") else {
            showAlert(title: "Book Not Found", message: "The Silver Chair.epub was not found in the app bundle.")
            return
        }

        let config = readerConfiguration(scrollDirection: .vertical, identifier: "VERTICAL_SCROLL_DEMO")
        folioReader.presentReader(parentViewController: self, withEpubPath: bookPath, andConfig: config, shouldRemoveEpub: false)
    }

    @IBAction func openHorizontalScrollBook(_ sender: UIButton) {
        guard let bookPath = Bundle.main.path(forResource: "The Adventures Of Sherlock Holmes - Adventure I", ofType: "epub") else {
            showAlert(title: "Book Not Found", message: "The Adventures Of Sherlock Holmes - Adventure I.epub was not found in the app bundle.")
            return
        }

        let config = readerConfiguration(scrollDirection: .horizontal, identifier: "HORIZONTAL_SCROLL_DEMO")
        folioReader.presentReader(parentViewController: self, withEpubPath: bookPath, andConfig: config, shouldRemoveEpub: false)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
