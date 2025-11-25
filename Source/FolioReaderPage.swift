//
//  FolioReaderPage.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 10/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import SafariServices
import MenuItemKit
import WebKit

/// Protocol which is used from `FolioReaderPage`s.
@objc public protocol FolioReaderPageDelegate: class {

    /**
     Notify that the page will be loaded. Note: The webview content itself is already loaded at this moment. But some java script operations like the adding of class based on click listeners will happen right after this method. If you want to perform custom java script before this happens this method is the right choice. If you want to modify the html content (and not run java script) you have to use `htmlContentForPage()` from the `FolioReaderCenterDelegate`.

     - parameter page: The loaded page
     */
    @objc optional func pageWillLoad(_ page: FolioReaderPage)

    /**
     Notifies that page did load. A page load doesn't mean that this page is displayed right away, use `pageDidAppear` to get informed about the appearance of a page.

     - parameter page: The loaded page
     */
    @objc optional func pageDidLoad(_ page: FolioReaderPage)
    
    /**
     Notifies that page receive tap gesture.
     
     - parameter recognizer: The tap recognizer
     */
    @objc optional func pageTap(_ recognizer: UITapGestureRecognizer)
}

open class FolioReaderPage: UICollectionViewCell, WKNavigationDelegate, UIGestureRecognizerDelegate {
    weak var delegate: FolioReaderPageDelegate?
    var readerContainer: FolioReaderContainer?

    /// The index of the current page. Note: The index start at 1!
    open var pageNumber: Int!
    open var webView: FolioReaderWebView?

    fileprivate var colorView: UIView!
    fileprivate var shouldShowBar = true
    fileprivate var menuIsVisible = false

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

    // MARK: - View life cicle

    public override init(frame: CGRect) {
        // Init explicit attributes with a default value. The `setup` function MUST be called to configure the current object with valid attributes.
        self.readerContainer = FolioReaderContainer(withConfig: FolioReaderConfig(), folioReader: FolioReader(), epubPath: "")
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear

        NotificationCenter.default.addObserver(self, selector: #selector(refreshPageMode), name: NSNotification.Name(rawValue: "needRefreshPageMode"), object: nil)
    }

    public func setup(withReaderContainer readerContainer: FolioReaderContainer) {
        self.readerContainer = readerContainer
        guard let readerContainer = self.readerContainer else { return }

        if webView == nil {
            webView = FolioReaderWebView(frame: webViewFrame(), readerContainer: readerContainer)
            webView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            // Don't disable scroll indicators here - let setupScrollDirection handle this
            webView?.backgroundColor = .clear
            self.contentView.addSubview(webView!)
        }
        webView?.navigationDelegate = self

        if colorView == nil {
            colorView = UIView()
            colorView.backgroundColor = self.readerConfig.nightModeBackground
            webView?.scrollView.addSubview(colorView)
        }

        // Remove all gestures before adding new one
        webView?.gestureRecognizers?.forEach({ gesture in
            webView?.removeGestureRecognizer(gesture)
        })
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.delegate = self
        webView?.addGestureRecognizer(tapGestureRecognizer)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("storyboards are incompatible with truth and beauty")
    }

    deinit {
        webView?.scrollView.delegate = nil
        webView?.navigationDelegate = nil
        NotificationCenter.default.removeObserver(self)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        webView?.frame = webViewFrame()
    }

    func webViewFrame() -> CGRect {
        guard (self.readerConfig.hideBars == false) else {
            return bounds
        }

        let statusbarHeight = UIApplication.shared.statusBarFrame.size.height
        let navBarHeight = self.folioReader.readerCenter?.navigationController?.navigationBar.frame.size.height ?? CGFloat(0)
        let navTotal = self.readerConfig.shouldHideNavigationOnTap ? 0 : statusbarHeight + navBarHeight
        let paddingTop: CGFloat = 20
        let paddingBottom: CGFloat = 30

        return CGRect(
            x: bounds.origin.x,
            y: self.readerConfig.isDirection(bounds.origin.y + navTotal, bounds.origin.y + navTotal + paddingTop, bounds.origin.y + navTotal),
            width: bounds.width,
            height: self.readerConfig.isDirection(bounds.height - navTotal, bounds.height - navTotal - paddingTop - paddingBottom, bounds.height - navTotal)
        )
    }

    func loadHTMLString(_ htmlContent: String!, baseURL: URL!) {
        // Insert the stored highlights to the HTML
        let tempHtmlContent = htmlContentWithInsertHighlights(htmlContent)
        // Load the html into the webview
        webView?.alpha = 0

        // Check if improved file loading is enabled
        guard readerConfig.useImprovedFileLoading else {
            // Use legacy loading method
            webView?.loadHTMLString(tempHtmlContent, baseURL: baseURL)
            return
        }

        // iOS 9+ requires loadFileURL for proper local file access on real devices
        // WKWebView security prevents loadHTMLString from accessing local resources on physical devices
        if #available(iOS 9.0, *) {
            // Write HTML to a temporary file in the same directory as the EPUB content
            // This ensures relative paths work correctly
            let baseDirectory = baseURL.deletingLastPathComponent()
            let tempFileName = "temp_folio_\(UUID().uuidString).html"
            let tempHtmlFile = baseDirectory.appendingPathComponent(tempFileName)

            do {
                try tempHtmlContent.write(to: tempHtmlFile, atomically: true, encoding: .utf8)

                // ⭐ CRITICAL: Grant read access to the ENTIRE FOLDER, not just the file
                // iOS MUST be allowed to read the whole folder to access images/CSS/fonts
                let folder = tempHtmlFile.deletingLastPathComponent()

                // Try to find the EPUB root directory for even broader access
                let epubRootDirectory = self.findEpubRootDirectory(from: folder)

                // Choose the best read-access directory. If the found root is the app bundle
                // (e.g. ends with .app) or otherwise looks invalid, fall back to the folder
                // containing the temp HTML file to avoid sandbox extension failures.
                let fileManager = FileManager.default
                var readAccessURL = epubRootDirectory

                // If the found root is the app bundle or does not contain META-INF, fallback to using a temp copy
                var shouldUseTempCopy = false
                if epubRootDirectory.pathExtension.lowercased() == "app" || epubRootDirectory.path.contains("/Bundle/") {
                    shouldUseTempCopy = true
                } else {
                    // Verify META-INF exists at the found root; if not, fallback
                    let metaInfPath = epubRootDirectory.appendingPathComponent("META-INF").path
                    if !fileManager.fileExists(atPath: metaInfPath) {
                        shouldUseTempCopy = true
                    }
                }

                if shouldUseTempCopy {
                    // Create a unique temporary folder for this EPUB copy
                    let tempRoot = fileManager.temporaryDirectory.appendingPathComponent("FolioReader/").appendingPathComponent(UUID().uuidString)
                    do {
                        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true, attributes: nil)

                        // Copy EPUB contents (children of epubRootDirectory) into tempRoot
                        let items = try fileManager.contentsOfDirectory(atPath: epubRootDirectory.path)
                        for item in items {
                            let src = epubRootDirectory.appendingPathComponent(item)
                            let dst = tempRoot.appendingPathComponent(item)
                            // If item already exists at destination, remove first
                            if fileManager.fileExists(atPath: dst.path) {
                                try? fileManager.removeItem(at: dst)
                            }
                            try fileManager.copyItem(at: src, to: dst)
                        }

                        // After copying, sanitize text assets inside the tempRoot to remove any file:// references to the app bundle or other private paths
                        let textExtensions: Set<String> = ["html", "htm", "xhtml", "css", "js", "svg", "xml", "json", "txt"]
                        var totalReplacements = 0
                        if let enumerator = fileManager.enumerator(at: tempRoot, includingPropertiesForKeys: nil) {
                            for case let fileURL as URL in enumerator {
                                let ext = fileURL.pathExtension.lowercased()
                                if textExtensions.contains(ext) {
                                    do {
                                        var content = try String(contentsOf: fileURL, encoding: .utf8)
                                        var fileReplacements = 0

                                        // Replace occurrences of the app bundle path
                                        let bundlePath = Bundle.main.bundlePath
                                        let bundleFilePrefix = "file://\(bundlePath)"
                                        if content.contains(bundleFilePrefix) {
                                            content = content.replacingOccurrences(of: bundleFilePrefix, with: "")
                                            fileReplacements += 1
                                        }

                                        // Replace absolute bundle file references like file:///var/containers/Bundle/Application
                                        let bundleContainersPrefix = "file:///var/containers/Bundle/Application"
                                        if content.contains(bundleContainersPrefix) {
                                            content = content.replacingOccurrences(of: bundleContainersPrefix, with: "")
                                            fileReplacements += 1
                                        }

                                        // Remove any file:/// references that contain ".app/" which are likely pointing into the bundle
                                        if content.contains(".app/") {
                                            content = content.replacingOccurrences(of: "file://", with: "")
                                            fileReplacements += 1
                                        }

                                        // Also remove leading slashes from resource attributes so they become relative paths
                                        // e.g. src="/images/x.png" -> src="images/x.png" to avoid resolving to the filesystem root or app bundle
                                        let attributesToFix = ["src", "href", "poster", "data-src", "srcset"]
                                        for attr in attributesToFix {
                                            content = content.replacingOccurrences(of: "\(attr)=\"/", with: "\(attr)=\"")
                                            content = content.replacingOccurrences(of: "\(attr)='/", with: "\(attr)='")
                                            // Also fix occurrences with single quotes inside srcset values or data- attributes
                                            content = content.replacingOccurrences(of: " \(attr)=\"/", with: " \(attr)=\"")
                                            content = content.replacingOccurrences(of: " \(attr)='/", with: " \(attr)='")
                                        }

                                        // Fix CSS url(/...) patterns
                                        content = content.replacingOccurrences(of: "url(\"/", with: "url(\"")
                                        content = content.replacingOccurrences(of: "url('/", with: "url('")
                                        content = content.replacingOccurrences(of: "url(/", with: "url(")

                                        // Run regex-based sanitizer to remove any remaining absolute file references
                                        content = sanitizeFileReferences(in: content)

                                        if fileReplacements > 0 {
                                            try content.write(to: fileURL, atomically: true, encoding: .utf8)
                                            totalReplacements += fileReplacements
                                        }
                                    } catch {
                                        // Ignore file read/write errors for binary or locked files
                                    }
                                }
                            }
                        }

                        if totalReplacements > 0 {
                            print("FolioReader: sanitized temp copy assets, total replacements=\(totalReplacements)")
                        }

                        // Move the temp HTML we already wrote into the tempRoot
                        let newTempHtml = tempRoot.appendingPathComponent(tempFileName)

                        // Sanitize the HTML to avoid references to the app bundle or other private file paths
                        var sanitizedHtml = tempHtmlContent
                        var replacements = 0

                        // Run regex sanitizer first to catch any tricky absolute paths
                        sanitizedHtml = sanitizeFileReferences(in: sanitizedHtml)

                        // Replace occurrences of file://<app bundle path> which cause WebContent to request access to the .app bundle
                        let bundlePath = Bundle.main.bundlePath
                        let bundleFilePrefix = "file://\(bundlePath)"
                        if sanitizedHtml.contains(bundleFilePrefix) {
                            sanitizedHtml = sanitizedHtml.replacingOccurrences(of: bundleFilePrefix, with: "")
                            replacements += 1
                        }

                        // Replace common absolute bundle file references (defensive)
                        let bundleContainersPrefix = "file:///var/containers/Bundle/Application"
                        if sanitizedHtml.contains(bundleContainersPrefix) {
                            sanitizedHtml = sanitizedHtml.replacingOccurrences(of: bundleContainersPrefix, with: "")
                            replacements += 1
                        }

                        // Also remove any direct file:/// references that contain ".app/" which are likely pointing into the bundle
                        if sanitizedHtml.contains(".app/") {
                            // Replace occurrences like file:///.../.app/ with just the path after the .app/ (best-effort)
                            sanitizedHtml = sanitizedHtml.replacingOccurrences(of: "file://", with: "")
                            replacements += 1
                        }

                        if fileManager.fileExists(atPath: tempHtmlFile.path) {
                            // If move fails, try copy
                            do {
                                // Write sanitized HTML into the destination (prefer write over move to ensure content is updated)
                                try sanitizedHtml.write(to: newTempHtml, atomically: true, encoding: .utf8)
                                // Remove original tempHtmlFile
                                try? fileManager.removeItem(at: tempHtmlFile)
                            } catch {
                                // If write fails, fallback to moving/copying original file
                                do {
                                    try fileManager.moveItem(at: tempHtmlFile, to: newTempHtml)
                                } catch {
                                    try? fileManager.copyItem(at: tempHtmlFile, to: newTempHtml)
                                    try? fileManager.removeItem(at: tempHtmlFile)
                                }
                            }
                        } else {
                            // As a fallback write the html into the tempRoot
                            try sanitizedHtml.write(to: newTempHtml, atomically: true, encoding: .utf8)
                        }

                        readAccessURL = tempRoot

                        print("FolioReader: loadFileURL (using temp copy) tempHtmlFile=\(newTempHtml.path) allowingReadAccessTo=\(readAccessURL.path)")

                        // Load file and allow reading the temporary copy directory
                        webView?.loadFileURL(newTempHtml, allowingReadAccessTo: readAccessURL)

                        // Clean up temp copy after a delay to ensure it has loaded
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                            try? fileManager.removeItem(at: tempRoot)
                        }
                    } catch {
                        print("FolioReader: Failed to create temp EPUB copy, falling back. Error: \(error)")
                        // Fallback to original folder read access (best effort)
                        readAccessURL = folder
                        print("FolioReader: loadFileURL tempHtmlFile=\(tempHtmlFile.path) allowingReadAccessTo=\(readAccessURL.path)")
                        webView?.loadFileURL(tempHtmlFile, allowingReadAccessTo: readAccessURL)

                        // Clean up temp file after a delay to ensure it has loaded
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            try? fileManager.removeItem(at: tempHtmlFile)
                        }
                    }
                } else {
                    // Verify META-INF exists; otherwise fallback to folder
                    let metaInfPath = epubRootDirectory.appendingPathComponent("META-INF").path
                    if !fileManager.fileExists(atPath: metaInfPath) {
                        readAccessURL = folder
                    }

                    print("FolioReader: loadFileURL tempHtmlFile=\(tempHtmlFile.path) allowingReadAccessTo=\(readAccessURL.path)")

                    // Load file and allow reading the appropriate directory tree
                    webView?.loadFileURL(tempHtmlFile, allowingReadAccessTo: readAccessURL)

                    // Clean up temp file after a delay to ensure it has loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        try? fileManager.removeItem(at: tempHtmlFile)
                    }
                }
            } catch {
                print("FolioReader: Failed to write temp HTML file, falling back to loadHTMLString: \(error)")
                webView?.loadHTMLString(tempHtmlContent, baseURL: baseURL)
            }
        } else {
            // Fallback for iOS 8
            webView?.loadHTMLString(tempHtmlContent, baseURL: baseURL)
        }
    }

    /// Find the EPUB root directory by traversing up until we find a directory containing META-INF
    private func findEpubRootDirectory(from url: URL) -> URL {
        var currentURL = url
        let fileManager = FileManager.default

        // Traverse up to find the EPUB root (contains META-INF folder)
        for _ in 0..<10 { // Limit iterations to prevent infinite loop
            let metaInfPath = currentURL.appendingPathComponent("META-INF")
            if fileManager.fileExists(atPath: metaInfPath.path) {
                return currentURL
            }

            let parentURL = currentURL.deletingLastPathComponent()
            if parentURL.path == currentURL.path {
                break // Reached root of filesystem
            }
            currentURL = parentURL
        }

        // If META-INF not found, return the original URL (best effort)
        return url
    }

    // MARK: - Highlights

    fileprivate func htmlContentWithInsertHighlights(_ htmlContent: String) -> String {
        var tempHtmlContent = htmlContent as NSString
        // Restore highlights
        guard let bookId = (self.book.name as NSString?)?.deletingPathExtension else {
            return tempHtmlContent as String
        }

        let highlights = Highlight.allByBookId(withConfiguration: self.readerConfig, bookId: bookId, andPage: pageNumber as NSNumber?)

        if (highlights.count > 0) {
            for item in highlights {
                let style = HighlightStyle.classForStyle(item.type)
                
                var tag = ""
                if let _ = item.noteForHighlight {
                    tag = "<highlight id=\"\(item.highlightId!)\" onclick=\"callHighlightWithNoteURL(this);\" class=\"\(style)\">\(item.content!)</highlight>"
                } else {
                    tag = "<highlight id=\"\(item.highlightId!)\" onclick=\"callHighlightURL(this);\" class=\"\(style)\">\(item.content!)</highlight>"
                }
                
                var locator = item.contentPre + item.content
                locator += item.contentPost
                locator = Highlight.removeSentenceSpam(locator) /// Fix for Highlights
                
                let range: NSRange = tempHtmlContent.range(of: locator, options: .literal)
                
                if range.location != NSNotFound {
                    let newRange = NSRange(location: range.location + item.contentPre.count, length: item.content.count)
                    tempHtmlContent = tempHtmlContent.replacingCharacters(in: newRange, with: tag) as NSString
                } else {
                    print("highlight range not found")
                }
            }
        }
        return tempHtmlContent as String
    }
    
    // MARK: - WKNavigationDelegate
    
    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard let webView = webView as? FolioReaderWebView else {
            return
        }
        
        delegate?.pageWillLoad?(self)
        
        // Add the custom class based onClick listener
        self.setupClassBasedOnClickListeners()
        
        refreshPageMode()
        
        if self.readerConfig.enableTTS && !self.book.hasAudio {
            webView.js("wrappingSentencesWithinPTags()") { _ in }
            
            if let audioPlayer = self.folioReader.readerAudioPlayer, (audioPlayer.isPlaying() == true) {
                audioPlayer.readCurrentSentence()
            }
        }
        
        let direction: ScrollDirection = self.folioReader.needsRTLChange ? .positive(withConfiguration: self.readerConfig) : .negative(withConfiguration: self.readerConfig)
        
        if (self.folioReader.readerCenter?.pageScrollDirection == direction &&
            self.folioReader.readerCenter?.isScrolling == true &&
            self.readerConfig.scrollDirection != .horizontalWithVerticalContent) {
            scrollPageToBottom()
        }
        
        UIView.animate(withDuration: 0.2, animations: {webView.alpha = 1}, completion: { finished in
            webView.isColors = false
            self.webView?.createMenu(options: false)
        })
    }

    open func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let webView = webView as? FolioReaderWebView else { return }

        // Setup scroll direction after content is fully loaded
        delay(0.1) {
            webView.setupScrollDirection()
            self.delegate?.pageDidLoad?(self)
        }
    }

    open func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        let request = navigationAction.request
        guard
            let webView = webView as? FolioReaderWebView,
            let scheme = request.url?.scheme else {
                decisionHandler(WKNavigationActionPolicy.allow)
                return
        }
        
        guard let url = request.url
            else {
                decisionHandler(WKNavigationActionPolicy.cancel)
                return
        }
        
        if scheme == "highlight" || scheme == "highlight-with-note" {
            shouldShowBar = false
            
            guard let decoded = url.absoluteString.removingPercentEncoding
                else {
                    decisionHandler(WKNavigationActionPolicy.cancel)
                    return
            }
            let index = decoded.index(decoded.startIndex, offsetBy: 12)
            let rect = NSCoder.cgRect(for: String(decoded[index...]))
            
            webView.createMenu(options: true)
            webView.setMenuVisible(true, andRect: rect)
            menuIsVisible = true
            decisionHandler(WKNavigationActionPolicy.cancel)
            return
        } else if scheme == "play-audio" {
            guard let decoded = url.absoluteString.removingPercentEncoding
                else {
                    decisionHandler(WKNavigationActionPolicy.cancel)
                    return
            }
            let index = decoded.index(decoded.startIndex, offsetBy: 13)
            let playID = String(decoded[index...])
            let chapter = self.folioReader.readerCenter?.getCurrentChapter()
            let href = chapter?.href ?? ""
            self.folioReader.readerAudioPlayer?.playAudio(href, fragmentID: playID)
            
            decisionHandler(WKNavigationActionPolicy.cancel)
            return
        } else if scheme == "file" {
            
            let anchorFromURL = url.fragment
            
            // Handle internal url
            if !url.pathExtension.isEmpty {
                let pathComponent = (self.book.opfResource.href as NSString?)?.deletingLastPathComponent
                guard let base = ((pathComponent == nil || pathComponent?.isEmpty == true) ? self.book.name : pathComponent) else {
                    decisionHandler(WKNavigationActionPolicy.allow)
                    return
                }
                
                let path = url.path
                let splitedPath = path.components(separatedBy: base)
                
                // Return to avoid crash
                if (splitedPath.count <= 1 || splitedPath[1].isEmpty) {
                    decisionHandler(WKNavigationActionPolicy.allow)
                    return
                }
                
                let href = splitedPath[1].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let hrefPage = (self.folioReader.readerCenter?.findPageByHref(href) ?? 0) + 1
                
                if (hrefPage == pageNumber) {
                    // Handle internal #anchor
                    if anchorFromURL != nil {
                        handleAnchor(anchorFromURL!, avoidBeginningAnchors: false, animated: true)
                        decisionHandler(WKNavigationActionPolicy.cancel)
                        return
                    }
                } else {
                    self.folioReader.readerCenter?.changePageWith(href: href, animated: true)
                }
               decisionHandler(WKNavigationActionPolicy.cancel)
                return
            }
            
            // Handle internal #anchor
            if anchorFromURL != nil {
                handleAnchor(anchorFromURL!, avoidBeginningAnchors: false, animated: true)
                decisionHandler(WKNavigationActionPolicy.cancel)
                return
            }
            
            decisionHandler(WKNavigationActionPolicy.allow)
            return
            
        } else if scheme == "mailto" {
            print("Email")
            decisionHandler(WKNavigationActionPolicy.allow)
            return
        } else if url.absoluteString != "about:blank" && scheme.contains("http") && navigationAction.navigationType == .linkActivated {
            let safariVC = SFSafariViewController(url: request.url!)
            safariVC.view.tintColor = self.readerConfig.tintColor
            self.folioReader.readerCenter?.present(safariVC, animated: true, completion: nil)
            decisionHandler(WKNavigationActionPolicy.cancel)
            return
        } else {
            // Check if the url is a custom class based onClick listerner
            var isClassBasedOnClickListenerScheme = false
            for listener in self.readerConfig.classBasedOnClickListeners {
                
                if scheme == listener.schemeName,
                    let absoluteURLString = request.url?.absoluteString,
                    let range = absoluteURLString.range(of: "/clientX=") {
                    let baseURL = String(absoluteURLString[..<range.lowerBound])
                    let positionString = String(absoluteURLString[range.lowerBound...])
                    if let point = getEventTouchPoint(fromPositionParameterString: positionString) {
                        let attributeContentString = (baseURL.replacingOccurrences(of: "\(scheme)://", with: "").removingPercentEncoding)
                        // Call the on click action block
                        listener.onClickAction(attributeContentString, point)
                        // Mark the scheme as class based click listener scheme
                        isClassBasedOnClickListenerScheme = true
                    }
                }
            }
            
            if isClassBasedOnClickListenerScheme == false {
                // Try to open the url with the system if it wasn't a custom class based click listener
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.openURL(url)
                    decisionHandler(WKNavigationActionPolicy.cancel)
                    return
                }
            } else {
                decisionHandler(WKNavigationActionPolicy.cancel)
                return
            }
        }
        
        decisionHandler(WKNavigationActionPolicy.allow)
        
    }
   
    fileprivate func getEventTouchPoint(fromPositionParameterString positionParameterString: String) -> CGPoint? {
        // Remove the parameter names: "/clientX=188&clientY=292" -> "188&292"
        var positionParameterString = positionParameterString.replacingOccurrences(of: "/clientX=", with: "")
        positionParameterString = positionParameterString.replacingOccurrences(of: "clientY=", with: "")
        // Separate both position values into an array: "188&292" -> [188],[292]
        let positionStringValues = positionParameterString.components(separatedBy: "&")
        // Multiply the raw positions with the screen scale and return them as CGPoint
        if
            positionStringValues.count == 2,
            let xPos = Int(positionStringValues[0]),
            let yPos = Int(positionStringValues[1]) {
            return CGPoint(x: xPos, y: yPos)
        }
        return nil
    }

    // MARK: Gesture recognizer

    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.view is FolioReaderWebView {
            if otherGestureRecognizer is UILongPressGestureRecognizer {
                if UIMenuController.shared.isMenuVisible {
                    webView?.setMenuVisible(false)
                }
                return false
            }
            return true
        }
        return false
    }

    @objc open func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        self.delegate?.pageTap?(recognizer)
        
        if let _navigationController = self.folioReader.readerCenter?.navigationController, (_navigationController.isNavigationBarHidden == true) {
            
            
            webView?.js("getSelectedText()") { selected in
                
                guard (selected == nil || selected?.isEmpty == true) else {
                    return
                }
                
                let delay = 0.4 * Double(NSEC_PER_SEC) // 0.4 seconds * nanoseconds per seconds
                let dispatchTime = (DispatchTime.now() + (Double(Int64(delay)) / Double(NSEC_PER_SEC)))
                
                DispatchQueue.main.asyncAfter(deadline: dispatchTime, execute: {
                    if (self.shouldShowBar == true && self.menuIsVisible == false) {
                        self.folioReader.readerCenter?.toggleBars()
                    }
                })
            }
            
        } else if (self.readerConfig.shouldHideNavigationOnTap == true) {
            self.folioReader.readerCenter?.hideBars()
            self.menuIsVisible = false
        }
    }

    // MARK: - Public scroll postion setter

    /**
     Scrolls the page to a given offset

     - parameter offset:   The offset to scroll
     - parameter animated: Enable or not scrolling animation
     */
    open func scrollPageToOffset(_ offset: CGFloat, animated: Bool) {
        let pageOffsetPoint = self.readerConfig.isDirection(CGPoint(x: 0, y: offset), CGPoint(x: offset, y: 0), CGPoint(x: 0, y: offset))
        webView?.scrollView.setContentOffset(pageOffsetPoint, animated: animated)
    }

    /**
     Scrolls the page to bottom
     */
    open func scrollPageToBottom() {
        guard let webView = webView else { return }
        let bottomOffset = self.readerConfig.isDirection(
            CGPoint(x: 0, y: webView.scrollView.contentSize.height - webView.scrollView.bounds.height),
            CGPoint(x: webView.scrollView.contentSize.width - webView.scrollView.bounds.width, y: 0),
            CGPoint(x: webView.scrollView.contentSize.width - webView.scrollView.bounds.width, y: 0)
        )

        if bottomOffset.forDirection(withConfiguration: self.readerConfig) >= 0 {
            DispatchQueue.main.async {
                self.webView?.scrollView.setContentOffset(bottomOffset, animated: false)
            }
        }
    }

    /**
     Handdle #anchors in html, get the offset and scroll to it

     - parameter anchor:                The #anchor
     - parameter avoidBeginningAnchors: Sometimes the anchor is on the beggining of the text, there is not need to scroll
     - parameter animated:              Enable or not scrolling animation
     */
    open func handleAnchor(_ anchor: String,  avoidBeginningAnchors: Bool, animated: Bool) {
        if !anchor.isEmpty {
            getAnchorOffset(anchor) { offset in
                
                switch self.readerConfig.scrollDirection {
                case .vertical, .defaultVertical:
                    let isBeginning = (offset < self.frame.forDirection(withConfiguration: self.readerConfig) * 0.5)
                    
                    if !avoidBeginningAnchors {
                        self.scrollPageToOffset(offset, animated: animated)
                    } else if avoidBeginningAnchors && !isBeginning {
                        self.scrollPageToOffset(offset, animated: animated)
                    }
                case .horizontal, .horizontalWithVerticalContent:
                    self.scrollPageToOffset(offset, animated: animated)
                }
                
            }
        }
    }

    // MARK: Helper

    /**
     Get the #anchor offset in the page

     - parameter anchor: The #anchor id
     - returns: The element offset ready to scroll
     */
    func getAnchorOffset(_ anchor: String, completion: @escaping ((CGFloat) -> ())) {
        let horizontal = self.readerConfig.scrollDirection == .horizontal
        
        webView?.js("getAnchorOffset('\(anchor)', \(horizontal.description))") { strOffset in
            guard let strOffset = strOffset else {
                completion(CGFloat(0))
                return }
            completion(CGFloat((strOffset as NSString).floatValue))
        }
        
    }

    // MARK: Mark ID

    /**
     Audio Mark ID - marks an element with an ID with the given class and scrolls to it

     - parameter identifier: The identifier
     */
    func audioMarkID(_ identifier: String) {
        guard let currentPage = self.folioReader.readerCenter?.currentPage else {
            return
        }

        let playbackActiveClass = self.book.playbackActiveClass
        currentPage.webView?.js("audioMarkID('\(playbackActiveClass)','\(identifier)')") { _ in }
    }

    // MARK: UIMenu visibility

    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard let webView = webView else { return false }

        if UIMenuController.shared.menuItems?.count == 0 {
            webView.isColors = false
            webView.createMenu(options: false)
        }

        if !webView.isShare && !webView.isColors {
            
            webView.js("getSelectedText()") { result in
                
                guard let result = result, result.components(separatedBy: " ").count == 1 else {
                    webView.isOneWord = false
                    return
                }
                
                webView.isOneWord = true
                webView.createMenu(options: false)
                
            }
        }

        return super.canPerformAction(action, withSender: sender)
    }

    // MARK: ColorView fix for horizontal layout
    @objc func refreshPageMode() {
        guard let webView = webView else { return }
        
        if (self.folioReader.nightMode == true) {
            // omit create webView and colorView
            let script = "document.documentElement.offsetHeight"
            
            webView.js(script) { contentHeight in
                
                guard let contentHeight = Int(contentHeight ?? "") else {
                    self.colorView.frame = CGRect.zero
                    return
                }
                
                let frameHeight = webView.frame.height
//                let lastPageHeight = frameHeight * CGFloat(webView.pageCount) - CGFloat(Double(contentHeight!)!)
//                colorView.frame = CGRect(x: webView.frame.width * CGFloat(webView.pageCount-1), y: webView.frame.height - lastPageHeight, width: webView.frame.width, height: lastPageHeight)
                
            }
            
        }
    }
    
    
    // MARK: - Class based click listener
    
    fileprivate func setupClassBasedOnClickListeners() {
        for listener in self.readerConfig.classBasedOnClickListeners {
            self.webView?.js("addClassBasedOnClickListener(\"\(listener.schemeName)\", \"\(listener.querySelector)\", \"\(listener.attributeName)\", \"\(listener.selectAll)\")") { _ in }
        }
    }
    
    /// Sanitize a string by removing absolute file:// and bundle references (best-effort).
    /// This prevents WKWebView from requesting resources inside the .app bundle or other protected paths.
    private func sanitizeFileReferences(in input: String) -> String {
        var result = input
        let fullRange = NSRange(location: 0, length: (result as NSString).length)

        // Remove file://... occurrences
        if let fileRegex = try? NSRegularExpression(pattern: "file://[^\"'\s)]+", options: [.caseInsensitive]) {
            result = fileRegex.stringByReplacingMatches(in: result, options: [], range: fullRange, withTemplate: "")
        }

        // Remove /var/containers/Bundle/Application... occurrences
        if let bundleRegex = try? NSRegularExpression(pattern: "/var/containers/Bundle/Application[^\"'\s)]*", options: []) {
            result = bundleRegex.stringByReplacingMatches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length), withTemplate: "")
        }

        // Remove direct bundle path occurrences
        let bundlePath = Bundle.main.bundlePath
        if !bundlePath.isEmpty {
            result = result.replacingOccurrences(of: bundlePath, with: "")
            result = result.replacingOccurrences(of: "file://\(bundlePath)", with: "")
        }

        return result
    }

}
