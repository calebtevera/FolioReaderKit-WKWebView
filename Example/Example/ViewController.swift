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

    @IBOutlet weak var bookOne: UIButton?
    @IBOutlet weak var bookTwo: UIButton?
    let folioReader = FolioReader()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.bookOne?.tag = Epub.bookOne.rawValue
        self.bookTwo?.tag = Epub.bookTwo.rawValue

        self.setCover(self.bookOne, index: 0)
        self.setCover(self.bookTwo, index: 1)
    }

    private func readerConfiguration(forEpub epub: Epub) -> FolioReaderConfig {
        let config = FolioReaderConfig(withIdentifier: epub.readerIdentifier)
        config.shouldHideNavigationOnTap = epub.shouldHideNavigationOnTap
        config.scrollDirection = epub.scrollDirection

        // Enable font style changes so users can select different fonts
        config.canChangeFontStyle = true

        // Enable dark/light mode switching
        config.canChangeScrollDirection = true

        // Display title in navigation bar
        config.displayTitle = true

        // Enable text-to-speech
        config.enableTTS = true
        // Allow sharing
        config.allowSharing = true
        // Configure colors for better dark/light mode experience
        config.tintColor = UIColor(red: 0.416, green: 0.8, blue: 0.314, alpha: 1.0) // #6ACC50
        config.menuBackgroundColor = UIColor.white
        config.menuTextColor = UIColor(red: 0.463, green: 0.463, blue: 0.463, alpha: 1.0) // #767676
        config.menuTextColorSelected = UIColor(red: 0.416, green: 0.8, blue: 0.314, alpha: 1.0) // #6ACC50

        // Dark mode colors
        config.nightModeBackground = UIColor(red: 0.075, green: 0.075, blue: 0.075, alpha: 1.0) // #131313
        config.nightModeMenuBackground = UIColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1.0) // #1E1E1E
        config.nightModeSeparatorColor = UIColor(white: 0.5, alpha: 0.2)

        // Custom sharing quote background
        config.quoteCustomBackgrounds = []
        if let image = UIImage(named: "demo-bg") {
            let customImageQuote = QuoteImage(withImage: image, alpha: 0.6, backgroundColor: UIColor.black)
            config.quoteCustomBackgrounds.append(customImageQuote)
        }

        let textColor = UIColor(red:0.86, green:0.73, blue:0.70, alpha:1.0)
        let customColor = UIColor(red:0.30, green:0.26, blue:0.20, alpha:1.0)
        let customQuote = QuoteImage(withColor: customColor, alpha: 1.0, textColor: textColor)
        config.quoteCustomBackgrounds.append(customQuote)

        return config
    }

    fileprivate func open(epub: Epub) {
        guard let bookPath = epub.bookPath else {
            return
        }

        let readerConfiguration = self.readerConfiguration(forEpub: epub)
        folioReader.presentReader(parentViewController: self, withEpubPath: bookPath, andConfig: readerConfiguration, shouldRemoveEpub: false)
    }

    private func setCover(_ button: UIButton?, index: Int) {
        guard
            let epub = Epub(rawValue: index),
            let bookPath = epub.bookPath else {
                return
        }

        do {
            let image = try FolioReader.getCoverImage(bookPath)

            button?.setBackgroundImage(image, for: .normal)
        } catch {
            print(error.localizedDescription)
        }
    }
}

// MARK: - IBAction

extension ViewController {
    
    @IBAction func didOpen(_ sender: AnyObject) {
        guard let epub = Epub(rawValue: sender.tag) else {
            return
        }

        self.open(epub: epub)
    }
}
