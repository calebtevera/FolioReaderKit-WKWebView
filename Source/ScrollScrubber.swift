//
//  ScrollScrubber.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 7/14/16.
//  Copyright © 2016 FolioReader. All rights reserved.
//

import UIKit

func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}

enum ScrollType: Int {
    case page
    // `chapter` is only for the collection view if vertical with horizontal content is used
    case chapter
}

enum ScrollDirection: Int {
    case none
    case right
    case left
    case up
    case down

    init() {
        self = .none
    }
}

class ScrollScrubber: NSObject, UIScrollViewDelegate {
    weak var delegate: FolioReaderCenter?
    var showSpeed = 0.6
    var hideSpeed = 0.6
    var hideDelay = 1.0

    var visible = false
    var usingSlider = false
    var slider: UISlider!
    var hideTimer: Timer!
    var scrollStart: CGFloat!
    var scrollDelta: CGFloat!
    var scrollDeltaTimer: Timer!

    fileprivate weak var readerContainer: FolioReaderContainer?

    fileprivate var readerConfig: FolioReaderConfig {
        guard let readerContainer = readerContainer else { return FolioReaderConfig() }
        return readerContainer.readerConfig
    }

    fileprivate var folioReader: FolioReader {
        guard let readerContainer = readerContainer else { return FolioReader() }
        return readerContainer.folioReader
    }

    var frame: CGRect {
        didSet {
            self.slider.frame = frame
        }
    }

    init(frame:CGRect, withReaderContainer readerContainer: FolioReaderContainer) {
        self.frame = frame
        self.readerContainer = readerContainer

        super.init()

        slider = UISlider()
        slider.layer.anchorPoint = CGPoint(x: 0, y: 0)
        slider.transform = CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2))
        slider.alpha = 0
        self.reloadColors()

        // less obtrusive knob and fixes jump: http://stackoverflow.com/a/22301039/484780
        let thumbImg = UIImage(readerImageNamed: "knob")
        let thumbImgColor = thumbImg?.imageTintColor(readerConfig.tintColor)?.withRenderingMode(.alwaysOriginal)
        slider.setThumbImage(thumbImgColor, for: UIControl.State())
        slider.setThumbImage(thumbImgColor, for: .selected)
        slider.setThumbImage(thumbImgColor, for: .highlighted)

        slider.addTarget(self, action: #selector(ScrollScrubber.sliderChange(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(ScrollScrubber.sliderTouchDown(_:)), for: .touchDown)
        slider.addTarget(self, action: #selector(ScrollScrubber.sliderTouchUp(_:)), for: .touchUpInside)
        slider.addTarget(self, action: #selector(ScrollScrubber.sliderTouchUp(_:)), for: .touchUpOutside)

        // Listen for content size change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentSizeChanged(_:)),
            name: NSNotification.Name("FolioReaderContentSizeChanged"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func contentSizeChanged(_ notification: Notification) {
        // Update slider when content size changes for any scroll mode
        if visible && !usingSlider {
            DispatchQueue.main.async { [weak self] in
                self?.setSliderVal()
            }
        }
    }

    func reloadColors() {
        slider.minimumTrackTintColor = readerConfig.tintColor
        slider.maximumTrackTintColor = folioReader.isNight(readerConfig.nightModeSeparatorColor, readerConfig.menuSeparatorColor)
    }

    // MARK: - slider events

    @objc func sliderTouchDown(_ slider:UISlider) {
        usingSlider = true
        show()
    }

    @objc func sliderTouchUp(_ slider:UISlider) {
        usingSlider = false
        hideAfterDelay()
    }

    @objc func sliderChange(_ slider:UISlider) {
        let movePosition = (height() * CGFloat(slider.value))
        let offset = readerConfig.isDirection(CGPoint(x: 0, y: movePosition), CGPoint(x: movePosition, y: 0), CGPoint(x: 0, y: movePosition))
        scrollView()?.setContentOffset(offset, animated: false)
    }

    // MARK: - show / hide

    func show() {
        cancelHide()

        visible = true

        if slider.alpha <= 0 {
            UIView.animate(withDuration: showSpeed, animations: {

                self.slider.alpha = 1

            }, completion: { (Bool) -> Void in
                self.hideAfterDelay()
            })
        } else {
            slider.alpha = 1
            if usingSlider == false {
                hideAfterDelay()
            }
        }
    }


    @objc func hide() {
        visible = false
        resetScrollDelta()
        UIView.animate(withDuration: hideSpeed, animations: {
            self.slider.alpha = 0
        })
    }

    func hideAfterDelay() {
        cancelHide()
        hideTimer = Timer.scheduledTimer(timeInterval: hideDelay, target: self, selector: #selector(ScrollScrubber.hide), userInfo: nil, repeats: false)
    }

    func cancelHide() {

        if hideTimer != nil {
            hideTimer.invalidate()
            hideTimer = nil
        }

        if visible == false {
            slider.layer.removeAllAnimations()
        }

        visible = true
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {

        if scrollDeltaTimer != nil {
            scrollDeltaTimer.invalidate()
            scrollDeltaTimer = nil
        }

        if scrollStart == nil {
            scrollStart = scrollView.contentOffset.forDirection(withConfiguration: readerConfig)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Handle both vertical and horizontal scroll modes
        guard (readerConfig.scrollDirection == .vertical ||
            readerConfig.scrollDirection == .defaultVertical ||
            readerConfig.scrollDirection == .horizontalWithVerticalContent ||
            readerConfig.scrollDirection == .horizontal) else {
                return
        }

        if visible && usingSlider == false {
            setSliderVal()
        }

        if (slider.alpha > 0) {
            self.show()
        } else if delegate?.currentPage != nil && scrollStart != nil {
            scrollDelta = scrollView.contentOffset.forDirection(withConfiguration: readerConfig) - scrollStart

            guard let pageHeight = folioReader.readerCenter?.pageHeight,
                (scrollDeltaTimer == nil && scrollDelta > (pageHeight * 0.2 ) || (scrollDelta * -1) > (pageHeight * 0.2)) else {
                    return
            }

            self.show()
            self.resetScrollDelta()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        resetScrollDelta()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollDeltaTimer = Timer(timeInterval:0.5, target: self, selector: #selector(ScrollScrubber.resetScrollDelta), userInfo: nil, repeats: false)
        RunLoop.current.add(scrollDeltaTimer, forMode: RunLoop.Mode.common)
    }

    @objc func resetScrollDelta() {
        if scrollDeltaTimer != nil {
            scrollDeltaTimer.invalidate()
            scrollDeltaTimer = nil
        }

        scrollStart = (scrollView()?.contentOffset.forDirection(withConfiguration: readerConfig) ?? 0)
        scrollDelta = 0
    }

    func setSliderVal() {
        slider.value = Float(scrollTop() / height())
    }

    // MARK: - utility methods

    fileprivate func scrollView() -> UIScrollView? {
        return delegate?.currentPage?.webView?.scrollView
    }

    fileprivate func height() -> CGFloat {
        guard let currentPage = delegate?.currentPage,
            let pageHeight = folioReader.readerCenter?.pageHeight,
            let webView = currentPage.webView else {
                return 0
        }

        // Calculate scrollable area based on scroll direction
        switch readerConfig.scrollDirection {
        case .vertical, .defaultVertical:
            // For vertical scroll, use content height minus viewport height
            let contentHeight = webView.scrollView.contentSize.height
            let scrollableHeight = max(0, contentHeight - pageHeight)
            return scrollableHeight

        case .horizontal:
            // For horizontal scroll, use content width minus viewport width
            let contentWidth = webView.scrollView.contentSize.width
            let viewportWidth = webView.bounds.width
            let scrollableWidth = max(0, contentWidth - viewportWidth)
            return scrollableWidth

        case .horizontalWithVerticalContent:
            // For horizontal with vertical content, use the appropriate dimension
            // This mode typically uses height for slider tracking
            let contentHeight = webView.scrollView.contentSize.height
            let scrollableHeight = max(0, contentHeight - pageHeight)
            return scrollableHeight
        }
    }
    
    fileprivate func scrollTop() -> CGFloat {
        guard let currentPage = delegate?.currentPage, let webView = currentPage.webView else {
            return 0
        }
        return webView.scrollView.contentOffset.forDirection(withConfiguration: readerConfig)
    }
}
