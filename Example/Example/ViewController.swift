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
    @IBOutlet weak var openBookButton: UIButton!

    let folioReader = FolioReader()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        // Configure the UI with simplified messaging
        titleLabel.text = "Enhanced Reader"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textAlignment = .center

        descriptionLabel.text = "Enhanced Reader"
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        descriptionLabel.font = UIFont.systemFont(ofSize: 18)

        // Setup single book button
        openBookButton.setTitle("📖 Open Book\n\"The Silver Chair\"", for: .normal)
        openBookButton.backgroundColor = UIColor(red: 0.416, green: 0.8, blue: 0.314, alpha: 1.0) // #6ACC50
        openBookButton.setTitleColor(.white, for: .normal)
        openBookButton.layer.cornerRadius = 12
        openBookButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        openBookButton.titleLabel?.numberOfLines = 0
        openBookButton.titleLabel?.textAlignment = .center

        // Set cover image
        setCoverImage()
    }

    private func readerConfiguration() -> FolioReaderConfig {
        let config = FolioReaderConfig(withIdentifier: "ENHANCED_READER_DEMO")

        // Start with vertical scroll, but allow users to change it in settings
        config.scrollDirection = .vertical
        config.shouldHideNavigationOnTap = false

        // Enable scroll direction switching - this is the key feature
        config.canChangeScrollDirection = true

        // Enable all reader features
        config.canChangeFontStyle = true
        config.displayTitle = true
        config.enableTTS = true
        config.allowSharing = true

        // Configure colors for the enhanced reader
        config.tintColor = UIColor(red: 0.416, green: 0.8, blue: 0.314, alpha: 1.0) // #6ACC50
        config.menuBackgroundColor = UIColor.white
        config.menuTextColor = UIColor(red: 0.463, green: 0.463, blue: 0.463, alpha: 1.0)
        config.menuTextColorSelected = UIColor(red: 0.416, green: 0.8, blue: 0.314, alpha: 1.0)

        // Dark mode colors
        config.nightModeBackground = UIColor(red: 0.075, green: 0.075, blue: 0.075, alpha: 1.0)
        config.nightModeMenuBackground = UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)
        config.nightModeSeparatorColor = UIColor(white: 0.5, alpha: 0.2)

        return config
    }

    private func setCoverImage() {
        // Set cover for the single book
        if let bookPath = Bundle.main.path(forResource: "The Silver Chair", ofType: "epub") {
            do {
                let image = try FolioReader.getCoverImage(bookPath)
                openBookButton.setBackgroundImage(image, for: .normal)
                openBookButton.imageView?.contentMode = .scaleAspectFit
                openBookButton.imageView?.alpha = 0.2
            } catch {
                print("Error loading book cover: \(error)")
            }
        }
    }

    @IBAction func openBook(_ sender: UIButton) {
        guard let bookPath = Bundle.main.path(forResource: "The Silver Chair", ofType: "epub") else {
            showAlert(title: "Book Not Found", message: "The Silver Chair.epub was not found in the app bundle.")
            return
        }

        let config = readerConfiguration()
        folioReader.presentReader(parentViewController: self, withEpubPath: bookPath, andConfig: config, shouldRemoveEpub: false)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
