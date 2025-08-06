//
//  ViewControllerEnhanced.swift
//  Example
//
//  Enhanced to showcase night/dark mode and persistent highlights
//

import UIKit
import FolioReaderKit

class ViewControllerEnhanced: UIViewController, FolioReaderDelegate {

    @IBOutlet weak var bookOne: UIButton?
    @IBOutlet weak var bookTwo: UIButton?

    // Theme control UI elements
    private var themeSegmentedControl: UISegmentedControl!
    private var themeLabel: UILabel!
    private var highlightsInfoLabel: UILabel!
    private var toggleThemeButton: UIButton!

    let folioReader = FolioReader()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.bookOne?.tag = Epub.bookOne.rawValue
        self.bookTwo?.tag = Epub.bookTwo.rawValue

        self.setCover(self.bookOne, index: 0)
        self.setCover(self.bookTwo, index: 1)

        setupThemeControls()
        setupHighlightsInfo()

        // Set delegate
        folioReader.delegate = self

        // Listen for theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: Notification.Name("FolioReaderThemeChanged"),
            object: nil
        )

        // Listen for reader close to update highlights info
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(readerDidClose),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        updateViewAppearance()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupThemeControls() {
        // Create theme segmented control
        themeSegmentedControl = UISegmentedControl(items: ["☀️ Light Mode", "🌙 Dark Mode"])
        themeSegmentedControl.selectedSegmentIndex = folioReader.currentTheme == .light ? 0 : 1
        themeSegmentedControl.addTarget(self, action: #selector(themeChanged(_:)), for: .valueChanged)
        themeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false

        // Set selected segment tint color (iOS 13.0+)
        if #available(iOS 13.0, *) {
            themeSegmentedControl.selectedSegmentTintColor = UIColor.systemBlue
        } else {
            // For iOS 12 and earlier, use the deprecated tintColor property
            themeSegmentedControl.tintColor = UIColor.systemBlue
        }

        view.addSubview(themeSegmentedControl)

        // Create theme label
        themeLabel = UILabel()
        themeLabel.text = "Current Theme: \(folioReader.currentTheme == .light ? "Light" : "Dark")"
        themeLabel.textAlignment = .center
        themeLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        themeLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(themeLabel)

        // Create toggle theme button
        toggleThemeButton = UIButton(type: .system)
        toggleThemeButton.setTitle("🔄 Toggle Theme", for: .normal)
        toggleThemeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        toggleThemeButton.addTarget(self, action: #selector(toggleTheme), for: .touchUpInside)
        toggleThemeButton.translatesAutoresizingMaskIntoConstraints = false
        toggleThemeButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        toggleThemeButton.layer.cornerRadius = 8
        toggleThemeButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)

        view.addSubview(toggleThemeButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            themeSegmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            themeSegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            themeSegmentedControl.widthAnchor.constraint(equalToConstant: 280),

            themeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            themeLabel.topAnchor.constraint(equalTo: themeSegmentedControl.bottomAnchor, constant: 15),

            toggleThemeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toggleThemeButton.topAnchor.constraint(equalTo: themeLabel.bottomAnchor, constant: 15)
        ])
    }

    private func setupHighlightsInfo() {
        highlightsInfoLabel = UILabel()
        highlightsInfoLabel.numberOfLines = 0
        highlightsInfoLabel.textAlignment = .center
        highlightsInfoLabel.font = UIFont.systemFont(ofSize: 14)
        highlightsInfoLabel.textColor = .systemBlue
        highlightsInfoLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(highlightsInfoLabel)

        NSLayoutConstraint.activate([
            highlightsInfoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            highlightsInfoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            highlightsInfoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            highlightsInfoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        updateHighlightsInfo()
    }

    @objc private func themeChanged(_ sender: UISegmentedControl) {
        let newTheme: FolioReaderTheme = sender.selectedSegmentIndex == 0 ? .light : .dark
        folioReader.setTheme(newTheme, animated: true)

        // Update the current view's appearance immediately
        updateViewAppearance()
    }

    @objc private func toggleTheme() {
        folioReader.toggleTheme()
        updateViewAppearance()
    }

    @objc private func themeDidChange(_ notification: Notification) {
        DispatchQueue.main.async {
            self.updateViewAppearance()
        }
    }

    @objc private func readerDidClose() {
        DispatchQueue.main.async {
            self.updateHighlightsInfo()
        }
    }

    private func updateViewAppearance() {
        let isDark = folioReader.currentTheme == .dark

        // Update main view
        view.backgroundColor = isDark ? UIColor.systemGray6 : UIColor.systemBackground

        // Update theme label
        themeLabel.text = "Current Theme: \(isDark ? "🌙 Dark" : "☀️ Light")"
        themeLabel.textColor = isDark ? UIColor.white : UIColor.label

        // Update segmented control selection
        themeSegmentedControl.selectedSegmentIndex = isDark ? 1 : 0

        // Update button appearance
        toggleThemeButton.backgroundColor = isDark ? UIColor.systemBlue.withAlphaComponent(0.3) : UIColor.systemBlue.withAlphaComponent(0.1)
        toggleThemeButton.setTitleColor(isDark ? UIColor.white : UIColor.systemBlue, for: .normal)

        // Update book buttons appearance
        bookOne?.layer.borderWidth = 2
        bookOne?.layer.borderColor = isDark ? UIColor.white.cgColor : UIColor.systemGray.cgColor
        bookOne?.layer.cornerRadius = 8

        bookTwo?.layer.borderWidth = 2
        bookTwo?.layer.borderColor = isDark ? UIColor.white.cgColor : UIColor.systemGray.cgColor
        bookTwo?.layer.cornerRadius = 8

        // Update highlights info
        updateHighlightsInfo()
    }

    private func updateHighlightsInfo() {
        let book1Highlights = getHighlightsCount(for: Epub.bookOne)
        let book2Highlights = getHighlightsCount(for: Epub.bookTwo)

        let isDark = folioReader.currentTheme == .dark

        highlightsInfoLabel.text = """
        📚 Persistent Highlights Demo

        📖 \(Epub.bookOne.name): \(book1Highlights) highlights
        📖 \(Epub.bookTwo.name): \(book2Highlights) highlights

        ✨ Theme persists across book sessions!
        💡 Try highlighting text and reopening books.
        🎨 Current theme: \(isDark ? "Dark Mode" : "Light Mode")
        """

        highlightsInfoLabel.textColor = isDark ? UIColor.lightGray : UIColor.systemBlue
    }

    private func getHighlightsCount(for epub: Epub) -> Int {
        // Simulate highlight counting from UserDefaults
        // In a real implementation, you would query the Realm database
        return UserDefaults.standard.integer(forKey: "highlights_count_\(epub.readerIdentifier)")
    }

    private func incrementHighlightsCount(for epub: Epub) {
        let currentCount = getHighlightsCount(for: epub)
        UserDefaults.standard.set(currentCount + 1, forKey: "highlights_count_\(epub.readerIdentifier)")
        updateHighlightsInfo()
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

        // Configure colors for better dark/light mode experience (copied from original ViewController)
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

extension ViewControllerEnhanced {
    @IBAction func didOpen(_ sender: UIButton) {
        guard let epub = Epub(rawValue: sender.tag) else {
            return
        }

        self.open(epub: epub)
    }
}

// MARK: - FolioReaderDelegate

extension ViewControllerEnhanced {

    func folioReader(_ folioReader: FolioReader, didFinishedLoading book: FRBook) {
        print("📚 Book loaded: \(book.title ?? "Unknown")")
        print("🎨 Current theme: \(folioReader.currentTheme == .light ? "Light" : "Dark")")
    }

    func folioReaderDidClose(_ folioReader: FolioReader) {
        print("📖 Reader closed")
        // Simulate that highlights were added during reading session
        // In practice, you would track actual highlight creation
        let randomBook = Bool.random() ? Epub.bookOne : Epub.bookTwo
        incrementHighlightsCount(for: randomBook)
        updateHighlightsInfo()
    }

    func folioReader(_ folioReader: FolioReader, didHighlightText text: String, in chapter: String) {
        print("📝 Text highlighted: \(text) in chapter: \(chapter)")

        // Simulate incrementing highlight count
        if let epub = getCurrentEpub() {
            incrementHighlightsCount(for: epub)
        }
    }

    private func getCurrentEpub() -> Epub? {
        // In a real implementation, you would track which book is currently open
        // For this demo, we'll just return the first book
        return Epub.bookOne
    }
}
