//
//  FolioReaderWebView.swift
//  FolioReaderKit
//
//  Created by Hans Seiffert on 21.09.16.
//  Copyright (c) 2016 Folio Reader. All rights reserved.
//

import WebKit

public typealias JSCallback = ((String?) ->())

/// The custom WebView used in each page
open class FolioReaderWebView: WKWebView {
    
    var isColors = false
    var isShare = false
    var isOneWord = false

    fileprivate weak var readerContainer: FolioReaderContainer?

    fileprivate var readerConfig: FolioReaderConfig {
        guard let readerContainer = readerContainer else { return FolioReaderConfig() }
        return readerContainer.readerConfig
    }

    fileprivate var book: FRBook {
        guard let readerContainer = readerContainer else { return FRBook() }
        return readerContainer.book
    }

    fileprivate var folioReader: FolioReader {
        guard let readerContainer = readerContainer else { return FolioReader() }
        return readerContainer.folioReader
    }
    
    init(frame: CGRect, readerContainer: FolioReaderContainer) {
        self.readerContainer = readerContainer
        
        let configuration = WKWebViewConfiguration()

        // Security: Configure data detectors
        if #available(iOS 10.0, *) {
            configuration.dataDetectorTypes = .link
        } else {
            // Fallback on earlier versions
            assertionFailure("unsupported iOS version")
        }

        // Security: Restrict media playback - require user action for all media
        if #available(iOS 10.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = .all
        } else {
            configuration.requiresUserActionForMediaPlayback = true
        }

        // Security: Control inline media playback
        configuration.allowsInlineMediaPlayback = false

        // Security: Disable picture-in-picture for better control
        if #available(iOS 9.0, *) {
            configuration.allowsPictureInPictureMediaPlayback = false
        }

        // Security: Configure preferences
        let preferences = WKPreferences()
        // Note: JavaScript is required for EPUB functionality
        // Additional JS validation is handled in the js() method
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.preferences = preferences

        // Security: Disable web page preview
        if #available(iOS 13.0, *) {
            configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        }

        // Real Device Fix: Enable local file access for EPUB resources
        // This is critical for loading images and resources on real devices
        if #available(iOS 9.0, *) {
            configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        }

        super.init(frame: frame, configuration: configuration)

        // Real Device Fix: Additional configuration for local resource loading
        if #available(iOS 11.0, *) {
            // Allow access to local files (needed for EPUB content on real devices)
            self.configuration.preferences.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UIMenuController

    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard readerConfig.useReaderMenuController else {
            return super.canPerformAction(action, withSender: sender)
        }

        if isShare {
            return false
        } else if isColors {
            return false
        } else {
            if action == #selector(highlight(_:))
                || action == #selector(highlightWithNote(_:))
                || action == #selector(updateHighlightNote(_:))
                || (action == #selector(define(_:)) && isOneWord)
                || (action == #selector(play(_:)) && (book.hasAudio || readerConfig.enableTTS))
                || (action == #selector(share(_:)) && readerConfig.allowSharing)
                || (action == #selector(copy(_:)) && readerConfig.allowSharing) {
                return true
            }
            return false
        }
    }

    // MARK: - UIMenuController - Actions

    @objc func share(_ sender: UIMenuController) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let shareImage = UIAlertAction(title: self.readerConfig.localizedShareImageQuote, style: .default, handler: { (action) -> Void in
            if self.isShare {
                self.js("getHighlightContent()") { textToShare in
                    guard let textToShare = textToShare else { return }
                    self.folioReader.readerCenter?.presentQuoteShare(textToShare)
                }
            } else {
                self.js("getSelectedText()") { textToShare in
                    guard let textToShare = textToShare else { return }
                    self.folioReader.readerCenter?.presentQuoteShare(textToShare)
                    
                    self.clearTextSelection()
                }
            }
            self.setMenuVisible(false)
        })

        // let shareText = UIAlertAction(title: self.readerConfig.localizedShareTextQuote, style: .default) { (action) -> Void in
        //     if self.isShare {
        //         self.js("getHighlightContent()") { textToShare in
        //             guard let textToShare = textToShare else { return }
        //             self.folioReader.readerCenter?.shareHighlight(textToShare, rect: sender.menuFrame)
        //         }
        //     } else {
        //         self.js("getSelectedText()") { textToShare in
        //             guard let textToShare = textToShare else { return }
        //             self.folioReader.readerCenter?.shareHighlight(textToShare, rect: sender.menuFrame)
        //         }
        //     }
        //     self.setMenuVisible(false)
        // }

        let cancel = UIAlertAction(title: self.readerConfig.localizedCancel, style: .cancel, handler: nil)

        alertController.addAction(shareImage)
        // alertController.addAction(shareText)
        alertController.addAction(cancel)

        if let alert = alertController.popoverPresentationController {
            alert.sourceView = self.folioReader.readerCenter?.currentPage
            alert.sourceRect = sender.menuFrame
        }

        self.folioReader.readerCenter?.present(alertController, animated: true, completion: nil)
    }

    func colors(_ sender: UIMenuController?) {
        isColors = true
        createMenu(options: false)
        setMenuVisible(true)
    }

    func remove(_ sender: UIMenuController?) {
        
        js("removeThisHighlight()") { removedId in
            guard let removedId = removedId else { return }
            Highlight.removeById(withConfiguration: self.readerConfig, highlightId: removedId)
        }

        setMenuVisible(false)
    }

    @objc func highlight(_ sender: UIMenuController?) {
        
        js("highlightString('\(HighlightStyle.classForStyle(self.folioReader.currentHighlightStyle))')") { highlightAndReturn in
            let jsonData = highlightAndReturn?.data(using: String.Encoding.utf8)
            
            do {
                let json = try JSONSerialization.jsonObject(with: jsonData!, options: []) as! NSArray
                let dic = json.firstObject as! [String: String]
                let rect = NSCoder.cgRect(for: dic["rect"]!)
                guard let startOffset = dic["startOffset"] else {
                    return
                }
                guard let endOffset = dic["endOffset"] else {
                    return
                }
                
                self.createMenu(options: true)
                self.setMenuVisible(true, andRect: rect)
                
                
                // Persist
                self.js("getHTML()") { html in
                    
                    guard let html = html, let identifier = dic["id"], let bookId = (self.book.name as NSString?)?.deletingPathExtension
                        else {
                            return
                    }
                    let pageNumber = self.folioReader.readerCenter?.currentPageNumber ?? 0
                    let match = Highlight.MatchingHighlight(text: html, id: identifier, startOffset: startOffset, endOffset: endOffset, bookId: bookId, currentPage: pageNumber)
                    let highlight = Highlight.matchHighlight(match)
                    highlight?.persist(withConfiguration: self.readerConfig)
                }
                
            } catch {
                print("Could not receive JSON")
            }
            
        }
        
    }
    
    @objc func highlightWithNote(_ sender: UIMenuController?) {
        
        js("highlightStringWithNote('\(HighlightStyle.classForStyle(self.folioReader.currentHighlightStyle))')") { highlightAndReturn in
            
            guard let highlightAndReturn = highlightAndReturn,
                  let jsonData = highlightAndReturn.data(using: String.Encoding.utf8) else {
                print("Error: Could not get highlight data")
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? NSArray,
                      let dic = json.firstObject as? [String: String],
                      let startOffset = dic["startOffset"],
                      let endOffset = dic["endOffset"],
                      let identifier = dic["id"] else {
                    print("Error: Invalid highlight data format")
                    return
                }

                self.clearTextSelection()
                
                self.js("getHTML()") { html in
                    
                    guard let html = html,
                          let bookId = (self.book.name as NSString?)?.deletingPathExtension else {
                        print("Error: Could not get HTML or book ID")
                        return
                    }
                    
                    let pageNumber = self.folioReader.readerCenter?.currentPageNumber ?? 0
                    let match = Highlight.MatchingHighlight(text: html, id: identifier, startOffset: startOffset, endOffset: endOffset, bookId: bookId, currentPage: pageNumber)

                    if let highlight = Highlight.matchHighlight(match) {
                        DispatchQueue.main.async {
                            self.folioReader.readerCenter?.presentAddHighlightNote(highlight, edit: false)
                        }
                    } else {
                        print("Error: Could not match highlight")
                    }
                }
            } catch {
                print("Could not parse JSON: \(error)")
            }
        }
    }
    
    @objc func updateHighlightNote (_ sender: UIMenuController?) {
        
        js("getHighlightId()") { highlightId in
            guard let highlightId = highlightId, let highlightNote = Highlight.getById(withConfiguration: self.readerConfig, highlightId: highlightId) else { return }
            self.folioReader.readerCenter?.presentAddHighlightNote(highlightNote, edit: true)
        }
   
    }

    @objc func define(_ sender: UIMenuController?) {
        
        js("getSelectedText()") { selectedText in
            
            guard let selectedText = selectedText else { return }
            
            self.setMenuVisible(false)
            self.clearTextSelection()
            
            let vc = UIReferenceLibraryViewController(term: selectedText)
            vc.view.tintColor = self.readerConfig.tintColor
            guard let readerContainer = self.readerContainer else { return }
            readerContainer.show(vc, sender: nil)
            
        }

    }

    @objc func play(_ sender: UIMenuController?) {
        self.folioReader.readerAudioPlayer?.play()

        self.clearTextSelection()
    }

    func setYellow(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .yellow)
    }

    func setGreen(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .green)
    }

    func setBlue(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .blue)
    }

    func setPink(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .pink)
    }

    func setUnderline(_ sender: UIMenuController?) {
        changeHighlightStyle(sender, style: .underline)
    }

    func changeHighlightStyle(_ sender: UIMenuController?, style: HighlightStyle) {
        self.folioReader.currentHighlightStyle = style.rawValue

        js("setHighlightStyle('\(HighlightStyle.classForStyle(style.rawValue))')") { updateId in
            guard let updateId = updateId else { return }
            Highlight.updateById(withConfiguration: self.readerConfig, highlightId: updateId, type: style)
        }
        
        //FIX: https://github.com/FolioReader/FolioReaderKit/issues/316
        setMenuVisible(false)
    }

    // MARK: - Create and show menu

    func createMenu(options: Bool) {
        guard (self.readerConfig.useReaderMenuController == true) else {
            return
        }

        isShare = options

        let colors = UIImage(readerImageNamed: "colors-marker")
        let share = UIImage(readerImageNamed: "share-marker")
        let remove = UIImage(readerImageNamed: "no-marker")
        let yellow = UIImage(readerImageNamed: "yellow-marker")
        let green = UIImage(readerImageNamed: "green-marker")
        let blue = UIImage(readerImageNamed: "blue-marker")
        let pink = UIImage(readerImageNamed: "pink-marker")
        let underline = UIImage(readerImageNamed: "underline-marker")

        let menuController = UIMenuController.shared

        let highlightItem = UIMenuItem(title: self.readerConfig.localizedHighlightMenu, action: #selector(highlight(_:)))
        let highlightNoteItem = UIMenuItem(title: self.readerConfig.localizedHighlightNote, action: #selector(highlightWithNote(_:)))
        let editNoteItem = UIMenuItem(title: self.readerConfig.localizedHighlightNote, action: #selector(updateHighlightNote(_:)))
        let playAudioItem = UIMenuItem(title: self.readerConfig.localizedPlayMenu, action: #selector(play(_:)))
        let defineItem = UIMenuItem(title: self.readerConfig.localizedDefineMenu, action: #selector(define(_:)))
        let colorsItem = UIMenuItem(title: "C", image: colors) { [weak self] _ in
            self?.colors(menuController)
        }
        let shareItem = UIMenuItem(title: "S", image: share) { [weak self] _ in
            self?.share(menuController)
        }
        let removeItem = UIMenuItem(title: "R", image: remove) { [weak self] _ in
            self?.remove(menuController)
        }
        let yellowItem = UIMenuItem(title: "Y", image: yellow) { [weak self] _ in
            self?.setYellow(menuController)
        }
        let greenItem = UIMenuItem(title: "G", image: green) { [weak self] _ in
            self?.setGreen(menuController)
        }
        let blueItem = UIMenuItem(title: "B", image: blue) { [weak self] _ in
            self?.setBlue(menuController)
        }
        let pinkItem = UIMenuItem(title: "P", image: pink) { [weak self] _ in
            self?.setPink(menuController)
        }
        let underlineItem = UIMenuItem(title: "U", image: underline) { [weak self] _ in
            self?.setUnderline(menuController)
        }

        var menuItems: [UIMenuItem] = []

        // menu on existing highlight
        if isShare {
            menuItems = [colorsItem, editNoteItem, removeItem]
            
            if (self.readerConfig.allowSharing == true) {
                menuItems.append(shareItem)
            }
            
            isShare = false
        } else if isColors {
            // menu for selecting highlight color
            menuItems = [yellowItem, greenItem, blueItem, pinkItem, underlineItem]
        } else {
            // default menu
            menuItems = [highlightItem, defineItem, highlightNoteItem]

            if self.book.hasAudio || self.readerConfig.enableTTS {
                menuItems.insert(playAudioItem, at: 0)
            }

            if (self.readerConfig.allowSharing == true) {
                menuItems.append(shareItem)
            }
        }
        
        menuController.menuItems = menuItems
    }
    
    open func setMenuVisible(_ menuVisible: Bool, animated: Bool = true, andRect rect: CGRect = CGRect.zero) {
        if !menuVisible && isShare || !menuVisible && isColors {
            isColors = false
            isShare = false
        }
        
        if menuVisible  {
            if !rect.equalTo(CGRect.zero) {
                UIMenuController.shared.setTargetRect(rect, in: self)
            }
        }
        
        UIMenuController.shared.setMenuVisible(menuVisible, animated: animated)
    }
    
    // MARK: - Java Script Bridge
    
    open func js(_ script: String, completion: @escaping JSCallback) {
        // Security: Validate JavaScript before execution
        guard validateJavaScript(script) else {
            print("Security: Blocked potentially unsafe JavaScript execution")
            completion(nil)
            return
        }

        self.evaluateJavaScript(script) { (result, error) in
            if let error = error {
                print("JavaScript execution error: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(result as? String)
            }
        }
    }

    // MARK: - Security Methods (Section 3)

    /// Validates JavaScript code before execution
    private func validateJavaScript(_ script: String) -> Bool {
        // Security: Check for empty or whitespace-only scripts
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // Security: Length limit to prevent excessively large scripts
        let maxScriptLength = 50000 // 50KB
        guard script.count <= maxScriptLength else {
            print("Security: JavaScript exceeds maximum length")
            return false
        }

        // Security: Whitelist of allowed function prefixes
        let allowedPrefixes = [
            "document.",
            "window.getSelection",
            "highlightString",
            "highlightStringWithNote",
            "removeThisHighlight",
            "removeHighlightById",
            "setHighlightStyle",
            "getHighlightContent",
            "getSelectedText",
            "getHTML",
            "nightMode",
            "setFontName",
            "setFontSize",
            "getReadingTime",
            "wrappingSentencesWithinPTags",
            "setMediaOverlayStyleColors",
            "addClassBasedOnClickListener",
            "playAudio",
            "pauseAudio",
            "addClass",
            "removeClass"
        ]

        // Check if script starts with an allowed prefix or is a simple property access
        let trimmedScript = script.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAllowed = allowedPrefixes.contains { prefix in
            trimmedScript.hasPrefix(prefix)
        }

        if !isAllowed {
            print("Security: JavaScript function not in whitelist: \(String(trimmedScript.prefix(50)))")
        }

        // Security: Block dangerous JavaScript patterns
        let dangerousPatterns = [
            "eval(",
            "Function(",
            "setTimeout(",
            "setInterval(",
            "XMLHttpRequest",
            "fetch(",
            ".innerHTML =",
            "document.write",
            "document.cookie",
            "localStorage.",
            "sessionStorage.",
            "indexedDB",
            "<script",
            "javascript:",
            "data:",
            "vbscript:",
            "file:",
            "chrome:",
            "webkit:"
        ]

        let lowerScript = script.lowercased()
        for pattern in dangerousPatterns {
            if lowerScript.contains(pattern.lowercased()) {
                print("Security: Blocked JavaScript with dangerous pattern: \(pattern)")
                return false
            }
        }

        return isAllowed
    }
    
    // MARK: WebView
    
    func clearTextSelection() {
        // Forces text selection clearing
        // @NOTE: this doesn't seem to always work
        
        self.isUserInteractionEnabled = false
        self.isUserInteractionEnabled = true
    }
    
    /// Sets up the scroll direction and paging behavior for the web view
    @objc open func setupScrollDirection() {
        switch self.readerConfig.scrollDirection {
        case .vertical, .defaultVertical:
            // Traditional vertical scrolling - no paging, continuous scroll
            scrollView.isPagingEnabled = false
            scrollView.bounces = true
            scrollView.alwaysBounceVertical = true
            scrollView.alwaysBounceHorizontal = false
            scrollView.showsVerticalScrollIndicator = true
            scrollView.showsHorizontalScrollIndicator = false

            // Apply vertical CSS class and remove any column styling
            self.evaluateJavaScript("""
                // Add vertical class for CSS styling
                document.documentElement.className = document.documentElement.className.replace(/\\b(horizontal|horizontalWithVerticalContent)\\b/g, '').trim();
                document.documentElement.classList.add('vertical');
                document.body.className = document.body.className.replace(/\\b(horizontal|horizontalWithVerticalContent)\\b/g, '').trim();
                document.body.classList.add('vertical');

                // Remove any column layout
                document.documentElement.style.webkitColumnCount = 'auto';
                document.documentElement.style.webkitColumnWidth = 'auto';
                document.documentElement.style.webkitColumnGap = '0px';
                document.body.style.webkitColumnCount = 'auto';
                document.body.style.webkitColumnWidth = 'auto';
                document.body.style.webkitColumnGap = '0px';

                // Ensure full width and natural height
                document.documentElement.style.width = '100%';
                document.documentElement.style.height = 'auto';
                document.body.style.width = '100%';
                document.body.style.maxWidth = '100%';
                document.body.style.height = 'auto';
                document.body.style.margin = '0';
                document.body.style.padding = '40px 20px';
                document.body.style.boxSizing = 'border-box';
            """, completionHandler: nil)
            break

        case .horizontal:
            // Traditional horizontal paging - content flows in columns
            scrollView.isPagingEnabled = true
            scrollView.bounces = false
            scrollView.alwaysBounceVertical = false
            scrollView.alwaysBounceHorizontal = true
            scrollView.showsVerticalScrollIndicator = false
            scrollView.showsHorizontalScrollIndicator = false

            let pageWidth = Int(self.frame.width - 80) // Account for padding
            let columnGap = 40

            self.evaluateJavaScript("""
                // Add horizontal class for CSS styling
                document.documentElement.className = document.documentElement.className.replace(/\\b(vertical|horizontalWithVerticalContent)\\b/g, '').trim();
                document.documentElement.classList.add('horizontal');
                document.body.className = document.body.className.replace(/\\b(vertical|horizontalWithVerticalContent)\\b/g, '').trim();
                document.body.classList.add('horizontal');

                // Set up column layout
                document.documentElement.style.webkitColumnWidth = '\(pageWidth)px';
                document.documentElement.style.webkitColumnGap = '\(columnGap)px';
                document.documentElement.style.webkitColumnFill = 'auto';
                document.body.style.webkitColumnWidth = '\(pageWidth)px';
                document.body.style.webkitColumnGap = '\(columnGap)px';
                document.body.style.webkitColumnFill = 'auto';

                document.body.style.margin = '0';
                document.body.style.padding = '40px 20px';
            """, completionHandler: nil)
            break

        case .horizontalWithVerticalContent:
            // Hybrid mode - vertical scrolling content within horizontal page navigation
            scrollView.isPagingEnabled = false
            scrollView.bounces = true
            scrollView.alwaysBounceVertical = true
            scrollView.alwaysBounceHorizontal = false
            scrollView.showsVerticalScrollIndicator = true
            scrollView.showsHorizontalScrollIndicator = false

            self.evaluateJavaScript("""
                // Add horizontalWithVerticalContent class for CSS styling
                document.documentElement.className = document.documentElement.className.replace(/\\b(vertical|horizontal)\\b/g, '').trim();
                document.documentElement.classList.add('horizontalWithVerticalContent');
                document.body.className = document.body.className.replace(/\\b(vertical|horizontal)\\b/g, '').trim();
                document.body.classList.add('horizontalWithVerticalContent');

                // Remove any column layout for vertical flow
                document.documentElement.style.webkitColumnCount = 'auto';
                document.documentElement.style.webkitColumnWidth = 'auto';
                document.documentElement.style.webkitColumnGap = '0px';
                document.body.style.webkitColumnCount = 'auto';
                document.body.style.webkitColumnWidth = 'auto';
                document.body.style.webkitColumnGap = '0px';

                // Set up full-width vertical content flow
                document.documentElement.style.width = '100%';
                document.documentElement.style.height = 'auto';
                document.body.style.width = '100%';
                document.body.style.maxWidth = '100%';
                document.body.style.height = 'auto';
                document.body.style.margin = '0';
                document.body.style.padding = '40px 20px';
                document.body.style.boxSizing = 'border-box';

                // Ensure proper text wrapping
                document.body.style.wordWrap = 'break-word';
                document.body.style.overflowWrap = 'break-word';
            """, completionHandler: nil)
            break
        }
    }
}
