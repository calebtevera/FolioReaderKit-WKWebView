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

    @IBOutlet weak var verticalButton: UIButton!
    @IBOutlet weak var horizontalButton: UIButton!
    @IBOutlet weak var horizontalWithVerticalButton: UIButton!
    @IBOutlet weak var bookCoverImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!

    let folioReader = FolioReader()
    let sampleBook = Epub.bookOne // Using The Silver Chair as our demo book

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadBookCover()
    }

    private func setupUI() {
        // Set up the title and description
        titleLabel.text = "FolioReader Scroll Direction Demo"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center

        descriptionLabel.text = "Experience the same book with different scroll directions. Each mode offers a unique reading experience."
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0

        // Configure buttons
        setupButton(verticalButton, title: "📖 Vertical Scroll", subtitle: "Traditional top-to-bottom scrolling", color: UIColor.systemBlue)
        setupButton(horizontalButton, title: "📚 Horizontal Pages", subtitle: "Left-to-right page turning", color: UIColor.systemGreen)
        setupButton(horizontalWithVerticalButton, title: "📄 Hybrid Mode", subtitle: "Horizontal pages with vertical content", color: UIColor.systemPurple)
    }

    private func setupButton(_ button: UIButton, title: String, subtitle: String, color: UIColor) {
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.layer.cornerRadius = 12
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 4

        // Create attributed string for title and subtitle
        let attributedTitle = NSMutableAttributedString(string: title, attributes: [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.white
        ])

        attributedTitle.append(NSAttributedString(string: "\n\(subtitle)", attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9)
        ]))

        button.setAttributedTitle(attributedTitle, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
    }

    private func loadBookCover() {
        guard let bookPath = sampleBook.bookPath else { return }

        do {
            let image = try FolioReader.getCoverImage(bookPath)
            bookCoverImageView.image = image
            bookCoverImageView.contentMode = .scaleAspectFit
            bookCoverImageView.layer.cornerRadius = 8
            bookCoverImageView.layer.shadowColor = UIColor.black.cgColor
            bookCoverImageView.layer.shadowOffset = CGSize(width: 0, height: 4)
            bookCoverImageView.layer.shadowOpacity = 0.2
            bookCoverImageView.layer.shadowRadius = 8
        } catch {
            print("Error loading book cover: \(error.localizedDescription)")
        }
    }

    private func readerConfiguration(scrollDirection: FolioReaderScrollDirection) -> FolioReaderConfig {
        let config = FolioReaderConfig(withIdentifier: "SCROLL_DEMO_\(scrollDirection.rawValue)")

        // Set the scroll direction
        config.scrollDirection = scrollDirection

        // Enable all features for demonstration
        config.canChangeFontStyle = true
        config.canChangeScrollDirection = true // Allow users to switch modes within the reader
        config.displayTitle = true
        config.enableTTS = true
        config.allowSharing = true
        config.shouldHideNavigationOnTap = false

        // Configure colors for better experience
        config.tintColor = UIColor(red: 0.416, green: 0.8, blue: 0.314, alpha: 1.0) // #6ACC50
        config.menuBackgroundColor = UIColor.white
        config.menuTextColor = UIColor(red: 0.463, green: 0.463, blue: 0.463, alpha: 1.0) // #767676
        config.menuTextColorSelected = UIColor(red: 0.416, green: 0.8, blue: 0.314, alpha: 1.0) // #6ACC50

        // Dark mode colors
        config.nightModeBackground = UIColor(red: 0.075, green: 0.075, blue: 0.075, alpha: 1.0) // #131313
        config.nightModeMenuBackground = UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1.0) // #1E1E1E
        config.nightModeSeparatorColor = UIColor(white: 0.5, alpha: 0.2)

        return config
    }

    private func openBook(with scrollDirection: FolioReaderScrollDirection) {
        guard let bookPath = sampleBook.bookPath else {
            showAlert(title: "Error", message: "Could not find the sample book file.")
            return
        }

        let config = readerConfiguration(scrollDirection: scrollDirection)

        // Add a loading indicator
        let alert = UIAlertController(title: "Loading Book", message: "Preparing your reading experience...", preferredStyle: .alert)
        present(alert, animated: true)

        // Small delay to show the loading message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            alert.dismiss(animated: true) {
                self.folioReader.presentReader(
                    parentViewController: self,
                    withEpubPath: bookPath,
                    andConfig: config,
                    shouldRemoveEpub: false
                )
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - IBActions

    @IBAction func openVerticalMode(_ sender: UIButton) {
        sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform.identity
        }) { _ in
            self.openBook(with: .vertical)
        }
    }

    @IBAction func openHorizontalMode(_ sender: UIButton) {
        sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform.identity
        }) { _ in
            self.openBook(with: .horizontal)
        }
    }

    @IBAction func openHorizontalWithVerticalMode(_ sender: UIButton) {
        sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform.identity
        }) { _ in
            self.openBook(with: .horizontalWithVerticalContent)
        }
    }
}
