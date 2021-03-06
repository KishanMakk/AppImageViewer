//
//  AppImageViewer
//
//  Created by Karthik on 1/27/18.
//

import UIKit

open class ViewerZoomingScrollView: UIScrollView {
    
    var photo: ViewerImageProtocol! {
        didSet {
            imageView.image = nil
            if photo != nil && photo.underlyingImage != nil {
                displayImage()
            }
        }
    }
    
    fileprivate(set) var imageView: TapDetectingImageView!
    fileprivate weak var browser: AppImageViewer?
    fileprivate var tapView: TapDetectingView!
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    convenience init(frame: CGRect, browser: AppImageViewer) {
        self.init(frame: frame)
        self.browser = browser
        setup()
    }
    
    deinit {
        browser = nil
    }
    
    func setup() {
        // tap
        tapView = TapDetectingView(frame: bounds)
        tapView.delegate = self
        tapView.backgroundColor = .clear
        tapView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        addSubview(tapView)
        
        // image
        imageView = TapDetectingImageView(frame: frame)
        imageView.delegate = self
        imageView.contentMode = .bottom
        imageView.backgroundColor = .clear
        addSubview(imageView)
        
        // self
        backgroundColor = .clear
        delegate = self
        showsHorizontalScrollIndicator = true
        showsVerticalScrollIndicator = true
        decelerationRate = UIScrollViewDecelerationRateFast
        autoresizingMask = [.flexibleWidth, .flexibleTopMargin, .flexibleBottomMargin, .flexibleRightMargin, .flexibleLeftMargin]
    }
    
    // MARK: - override
    
    open override func layoutSubviews() {
        
        tapView.frame = bounds
        
        super.layoutSubviews()
        
        let boundsSize = bounds.size
        var frameToCenter = imageView.frame
        
        // horizon
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = floor((boundsSize.width - frameToCenter.size.width) / 2)
        } else {
            frameToCenter.origin.x = 0
        }
        // vertical
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = floor((boundsSize.height - frameToCenter.size.height) / 2)
        } else {
            frameToCenter.origin.y = 0
        }
        
        // Center
        if !imageView.frame.equalTo(frameToCenter) {
            imageView.frame = frameToCenter
        }
    }
    
    open func setMaxMinZoomScalesForCurrentBounds() {
        
        maximumZoomScale = 1
        minimumZoomScale = 1
        zoomScale = 1
        
        guard let imageView = imageView else {
            return
        }
        
        let boundsSize = bounds.size
        let imageSize = imageView.frame.size
        
        let xScale = boundsSize.width / imageSize.width
        let yScale = boundsSize.height / imageSize.height
        let minScale: CGFloat = min(xScale, yScale)
        var maxScale: CGFloat = 1.0
        
        let scale = max(UIScreen.main.scale, 2.0)
        let deviceScreenWidth = UIScreen.main.bounds.width * scale // width in pixels. scale needs to remove if to use the old algorithm
        let deviceScreenHeight = UIScreen.main.bounds.height * scale // height in pixels. scale needs to remove if to use the old algorithm
        
        if imageView.frame.width < deviceScreenWidth {
            // I think that we should to get coefficient between device screen width and image width and assign it to maxScale. I made two mode that we will get the same result for different device orientations.
            if UIApplication.shared.statusBarOrientation.isPortrait {
                maxScale = deviceScreenHeight / imageView.frame.width
            } else {
                maxScale = deviceScreenWidth / imageView.frame.width
            }
        } else if imageView.frame.width > deviceScreenWidth {
            maxScale = 1.0
        } else {
            // here if imageView.frame.width == deviceScreenWidth
            maxScale = 2.5
        }
    
        maximumZoomScale = maxScale
        minimumZoomScale = minScale
        zoomScale = minScale
        
        // on high resolution screens we have double the pixel density, so we will be seeing every pixel if we limit the
        // maximum zoom scale to 0.5
        // After changing this value, we still never use more
        /*
        maxScale = maxScale / scale 
        if maxScale < minScale {
            maxScale = minScale * 2
        }
        */
        
        // reset position
        imageView.frame = CGRect(x: 0, y: 0, width: imageView.frame.size.width, height: imageView.frame.size.height)
        setNeedsLayout()
    }
    
    open func prepareForReuse() {
        photo = nil        
    }
    
    // MARK: - image
    open func displayImage() {
        // reset scale
        maximumZoomScale = 1
        minimumZoomScale = 1
        zoomScale = 1
        contentSize = CGSize.zero
        
        if let image = photo.underlyingImage, photo != nil {
            // image
            imageView.image = image
            imageView.contentMode = photo.contentMode

            var imageViewFrame: CGRect = .zero
            imageViewFrame.origin = .zero
            imageViewFrame.size = image.size

            imageView.frame = imageViewFrame

            contentSize = imageViewFrame.size
            
            setMaxMinZoomScalesForCurrentBounds()
        }
        
        setNeedsLayout()
    }

    // MARK: - handle tap
    open func handleDoubleTap(_ touchPoint: CGPoint) {
        if let browser = browser {
            NSObject.cancelPreviousPerformRequests(withTarget: browser)
        }
        
        if zoomScale > minimumZoomScale {
            // zoom out
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            // zoom in
            // I think that the result should be the same after double touch or pinch
           /* var newZoom: CGFloat = zoomScale * 3.13
            if newZoom >= maximumZoomScale {
                newZoom = maximumZoomScale
            }
            */
            let zoomRect = zoomRectForScrollViewWith(maximumZoomScale, touchPoint: touchPoint)
            zoom(to: zoomRect, animated: true)
        }
        
        // delay control
        // browser?.hideControlsAfterDelay()
    }
}

// MARK: - UIScrollViewDelegate

extension ViewerZoomingScrollView: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        browser?.cancelControlHiding()
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        setNeedsLayout()
        layoutIfNeeded()
    }
}

// MARK: > Tap Detecting view delegate
extension ViewerZoomingScrollView: TapDetectingViewDelegate {
    
    func handleSingleTap(_ view: UIView, touch: UITouch) {
        
        guard let browser = browser, browser.enableZoomBlackArea == true else {
            return
        }
        
        browser.toggleControls()
    }
    
    func handleDoubleTap(_ view: UIView, touch: UITouch) {
        
        guard let browser = browser, browser.enableZoomBlackArea == true else {
            return
        }
        
        let needPoint = getViewFramePercent(view, touch: touch)
        handleDoubleTap(needPoint)
    }
}

// MARK: > Tap Detecting imageview delegate
extension ViewerZoomingScrollView: TapDetectingImageViewDelegate {
    
    func handleImageViewSingleTap(_ touchPoint: CGPoint) {
        guard let browser = browser else {
            return
        }
        
        browser.toggleControls()
    }
    
    func handleImageViewDoubleTap(_ touchPoint: CGPoint) {
        handleDoubleTap(touchPoint)
    }
}

private extension ViewerZoomingScrollView {
    
    func getViewFramePercent(_ view: UIView, touch: UITouch) -> CGPoint {
        
        let oneWidthViewPercent = view.bounds.width / 100
        let viewTouchPoint = touch.location(in: view)
        let viewWidthTouch = viewTouchPoint.x
        let viewPercentTouch = viewWidthTouch / oneWidthViewPercent
        let photoWidth = imageView.bounds.width
        let onePhotoPercent = photoWidth / 100
        let needPoint = viewPercentTouch * onePhotoPercent
        
        var Y: CGFloat!
        
        if viewTouchPoint.y < view.bounds.height / 2 {
            Y = 0
        } else {
            Y = imageView.bounds.height
        }
        let allPoint = CGPoint(x: needPoint, y: Y)
        return allPoint
    }
    
    func zoomRectForScrollViewWith(_ scale: CGFloat, touchPoint: CGPoint) -> CGRect {
        let w = frame.size.width / scale
        let h = frame.size.height / scale
        let x = touchPoint.x - (h / max(UIScreen.main.scale, 2.0))
        let y = touchPoint.y - (w / max(UIScreen.main.scale, 2.0))
        
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
