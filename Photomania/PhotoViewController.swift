//
//  PhotoViewController.swift
//  Photomania
//
//  Created by Harvey Zhang on 12/16/15.
//  Copyright © 2015 HappyGuy. All rights reserved.
//

import UIKit
import MobileCoreServices
import Alamofire

// Will show the specified photo
class PhotoViewController: UIViewController
{
    var photoID: Int?       // What's the photo id, use to download the photo and detail info
    var imageURL: NSURL?    // use to store the local downloaded photo path
    
    @IBOutlet weak var deletePhotoBarButtonItem: UIBarButtonItem!   // will unwind to delete a photo
    
    private let scrollView = UIScrollView() // use to scroll the photo when zoom it in
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
    
    private var photoInfo: PhotoInfo?   // will get the photo info via photo id

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupView()
        loadPhoto()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if photoInfo != nil {
            navigationController?.setToolbarHidden(false, animated: true)
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    func setupView()
    {
        // Spinner view
        spinner.center = CGPoint(x: view.center.x, y: view.center.y)
        spinner.hidesWhenStopped = true
        spinner.startAnimating()
        view.addSubview(spinner)
        
        // Scroll view
        scrollView.frame = view.bounds    // same as below line
        //scrollView.contentSize = CGSize(width: view.bounds.width, height: view.bounds.height)
        scrollView.minimumZoomScale = 1.0   // default is 1.0
        scrollView.maximumZoomScale = 3.0   // max must greater than min
        scrollView.delegate = self
        view.addSubview(scrollView)
        
        // Image ivew - its frame based on image size
        imageView.contentMode = UIViewContentMode.ScaleAspectFill
        scrollView.addSubview(imageView)
        
        // Double tap gesture - to zoom in or out the photo
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(PhotoViewController.togglePhotoZoom(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.numberOfTouchesRequired = 1
        scrollView.addGestureRecognizer(doubleTap)
        
        // Hide delete photo bar button item
        deletePhotoBarButtonItem.enabled = false
        deletePhotoBarButtonItem.title = nil
    }
    
    func loadPhoto()
    {
        if let pID = photoID    // photo id come from popular collection vc
        {
            Alamofire.request(Five100px.Router.SpecialPhoto(pID, .Large)).responseObject({ (response :Response<PhotoInfo, NSError>) -> Void in
                if response.result.error == nil
                {
                    self.photoInfo = response.result.value
                
                    dispatch_async(dispatch_get_main_queue()) {
                        self.addBottomBar()     // add bottom toolbar and items
                        self.title = self.photoInfo?.name
                    }
                    
                    Alamofire.request(.GET, self.photoInfo!.url).validate().responseImage({ (response: Response<UIImage, NSError>) -> Void in
                        if response.result.error == nil {
                            dispatch_async(dispatch_get_main_queue()) {
                                self.imageView.image = response.result.value
                                self.imageView.frame = self.centerFrameFromImage(response.result.value)
                                
                                self.spinner.stopAnimating()
                                self.centerScrollViewContents()
                            }
                        }
                    })
                }
            })
        }
        
        if let imgURL = imageURL // image url come from downloaded collection vc
        {
            // Show delete photo bar button item
            deletePhotoBarButtonItem.enabled = true
            deletePhotoBarButtonItem.title = "Delete Photo"
            
            let image = UIImage(data: NSData(contentsOfURL: imgURL)! )
            self.imageView.image = image
            self.imageView.frame = self.centerFrameFromImage(image)
            
            self.spinner.stopAnimating()
            self.centerScrollViewContents()
        }
        
    }
    
    func addBottomBar()
    {
        var items = [UIBarButtonItem]()
        
        let detailHamburger = barButtonItemWithImageNamed("hamburger", title: nil, action: #selector(PhotoViewController.showPhotoDetail))
        items.append(detailHamburger)
        if photoInfo?.commentsCount > 0 {
            let comment = barButtonItemWithImageNamed("bubble", title: "\(photoInfo?.commentsCount ?? 0)", action: #selector(PhotoViewController.showComment))
            items.append(comment)
        }
        
        let flexible = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: nil, action: nil)
        items.append(flexible)
        
        let download = UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: #selector(PhotoViewController.showActions))
        items.append(download)
        items.append(flexible)
        
        let likes = barButtonItemWithImageNamed("like", title: "\(photoInfo?.votesCount ?? 0)")
        let hearts = barButtonItemWithImageNamed("heart", title: "\(photoInfo?.favoritesCount ?? 0)")
        items.append(likes)
        items.append(hearts)
        
        // Here no need to create a tool bar anymore, navigation view controller already have one
        self.setToolbarItems(items, animated: true) // only need set up bar button items
        // navigationController: If this view controller has been pushed onto a navigation controller, return it.
        navigationController?.setToolbarHidden(false, animated: true)
    }
    
    func barButtonItemWithImageNamed(imageName: String?, title: String?, action: Selector? = nil) -> UIBarButtonItem
    {
        let button = UIButton(type: .Custom)
        
        // Step-1: button image
        if let imgName = imageName {
            button.setImage(UIImage(named: imgName)?.imageWithRenderingMode(.AlwaysTemplate), forState: .Normal)
        }
        
        // Step-2: button title
        if let bTitle = title {
            button.setTitle(bTitle, forState: .Normal)
            button.titleEdgeInsets = UIEdgeInsets(top: 0.0, left: 10.0, bottom: 0.0, right: 0.0)
            
            let font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
            button.titleLabel?.font = font
        }
        
        // Step-3: button size
        let bSize = button.sizeThatFits(CGSize(width: 90.0, height: 30.0))
        button.frame.size = CGSize(width: min(bSize.width + 10.0, 60), height: bSize.height)
        
        // Step-4: button action
        if let bAction = action {
            button.addTarget(self, action: bAction, forControlEvents: .TouchUpInside)
        }
        
        let barButtonItem = UIBarButtonItem(customView: button)
        return barButtonItem
    }
    
    func showPhotoDetail()
    {
        if presentedViewController != nil { // Dismiss Comment or Actions VC if visible
            dismissViewControllerAnimated(true, completion: nil)
        }
        
        let photoDetailVC = storyboard?.instantiateViewControllerWithIdentifier(Constant.PhotoDetailVC) as? PhotoDetailViewController
        photoDetailVC?.modalPresentationStyle = .OverCurrentContext     // .OverCurrentContext better than .FullScreen
        photoDetailVC?.modalTransitionStyle = .CoverVertical
        photoDetailVC?.photoInfo = self.photoInfo
        
        self.presentViewController(photoDetailVC!, animated: true, completion: nil)
    }
    
    func showComment()
    {
        if presentedViewController != nil { // Dismiss Comment VC if visible
            dismissViewControllerAnimated(true, completion: nil)
        }
        
        let commentTVC = storyboard?.instantiateViewControllerWithIdentifier(Constant.PhotoCommentsTVC) as? PhotoCommentsTableViewController
        commentTVC?.modalPresentationStyle = .Popover   // .Popover
        commentTVC?.modalTransitionStyle = .CoverVertical
        commentTVC?.photoInfo = self.photoInfo
        commentTVC?.popoverPresentationController?.delegate = self      // here is required for iPhone
        commentTVC?.popoverPresentationController?.barButtonItem = self.toolbarItems![1]
        
        self.presentViewController(commentTVC!, animated: true, completion: nil)
    }
    
    func showActions()
    {
        if presentedViewController != nil { // Dismiss Comment VC if visible
            dismissViewControllerAnimated(true, completion: nil)
        }
        
        let alertController = UIAlertController(title: "What's your action?", message: nil, preferredStyle: .ActionSheet)
        
        weak var weakSelf = self
        let downloadPhoto = UIAlertAction(title: "Download Photo", style: .Default) { (_) -> Void in
            weakSelf?.downloadPhoto()   // download photo
        }
        let savePhotoToAlbum = UIAlertAction(title: "Save Photo To Album", style: .Default) { (_) -> Void in
            weakSelf?.savePhotoToAlbum()     // save the photo to Album
        }
        let cancel = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        
        alertController.addAction(downloadPhoto)
        alertController.addAction(savePhotoToAlbum)
        alertController.addAction(cancel)
        
        if let ppc = alertController.popoverPresentationController
        {
            if photoInfo?.commentsCount > 0 {
                ppc.barButtonItem = self.toolbarItems![3]
            } else {
                ppc.barButtonItem = self.toolbarItems![2]
            }
        }
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func downloadPhoto()
    {
        Alamofire.request(Five100px.Router.SpecialPhoto(self.photoInfo!.id, .XLarge)).responseObject { (response:Response<PhotoInfo, NSError>) -> Void in
            if response.result.error == nil
            {
                let imageURL = (response.result.value)!.url
                
                // public typealias DownloadFileDestination = (NSURL, NSHTTPURLResponse) -> NSURL
                let dest = Alamofire.Request.suggestedDownloadDestination(directory: .DocumentDirectory, domain: .UserDomainMask)
                
                //Alamofire.download(.GET, imageURL, destination: dest)   // simple way
                
                // new way - download with progress view
                let progressView = UIProgressView(frame: CGRect(x: 0, y: 80, width: self.view.bounds.width, height: 10.0))
                progressView.tintColor = UIColor.blueColor()
                self.view.addSubview(progressView)
                
                Alamofire.download(.GET, imageURL, destination: dest).progress(){ _, totalBytesRead, totalBytesExpectedToRead in
                    dispatch_async(dispatch_get_main_queue()) {
                        progressView.setProgress(Float(totalBytesRead)/Float(totalBytesExpectedToRead), animated: true)
                        if totalBytesRead == totalBytesExpectedToRead {
                            progressView.removeFromSuperview()
                        }
                    }
                }//Download
                
            }
        }//responseObject
    }
    
    func savePhotoToAlbum()
    {
        Alamofire.request(Five100px.Router.SpecialPhoto(self.photoInfo!.id, .XLarge)).responseObject { (response:Response<PhotoInfo, NSError>) -> Void in
            if response.result.error == nil
            {
                let imageURL = (response.result.value)!.url
                
                // new way - download with progress view
                let progressView = UIProgressView(frame: CGRect(x: 0, y: 80, width: self.view.bounds.width, height: 10.0))
                progressView.tintColor = UIColor.blueColor()
                self.view.addSubview(progressView)
                
                Alamofire.request(.GET, imageURL).responseImage({ (resp:Response<UIImage, NSError>) -> Void in
                    if resp.result.error == nil {
                        UIImageWriteToSavedPhotosAlbum(resp.result.value!, self, #selector(PhotoViewController.imageSaved(_:didFinishSavingWithError:context:)), nil)
                    }
                }).progress({ (_, totalBytesRead, totalBytesExpectedToRead) -> Void in
                    dispatch_async(dispatch_get_main_queue()) {
                        progressView.setProgress(Float(totalBytesRead)/Float(totalBytesExpectedToRead), animated: true)
                        if totalBytesRead == totalBytesExpectedToRead {
                            progressView.removeFromSuperview()
                        }
                    }
                })
            }
        }//responseObject
    }
    
    // - (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;
    func imageSaved(image: UIImage, didFinishSavingWithError error: NSError?, context: UnsafeMutablePointer<()>)
    {
        if let theError = error {
            print("An error happened while saving the image = \(theError)")
        } else {
            print("Image was saved successfully")
        }
    }
    
    func togglePhotoZoom(tap: UITapGestureRecognizer)
    {
        let pointInImageView = tap.locationInView(self.imageView)
        self.zoomInZoomOut(pointInImageView)
    }
    
    func zoomInZoomOut(point: CGPoint)
    {
        // zoomScale -- This value determines how much the content is currently scaled. The default value is 1.0
        let newZoomScale = scrollView.zoomScale > scrollView.maximumZoomScale/2 ? scrollView.minimumZoomScale : scrollView.maximumZoomScale
        
        let scrollViewSize = scrollView.bounds.size
        
        let width = scrollViewSize.width / newZoomScale
        let height = scrollViewSize.height / newZoomScale
        
        let x = point.x - (width/2)
        let y = point.y - (height/2)
        
        let rectToZoom = CGRect(x: x, y: y, width: width, height: height)
        
        // This method zooms so that the content view becomes the area defined by rect, adjusting the zoomScale as necessary.
        self.scrollView.zoomToRect(rectToZoom, animated: true)
    }
    
    // MARK: - Scroll view
    
    func centerFrameFromImage(image: UIImage?) -> CGRect
    {
        if image == nil { return CGRectZero }
        
        let scaleFactor = scrollView.frame.size.width / image!.size.width
        let newHeight = image!.size.height * scaleFactor
        
        let newImageSize = CGSize(width: scrollView.frame.size.width, height: min(scrollView.frame.size.height, newHeight))
        
        let centerFrame = CGRect(x: 0, y: scrollView.frame.size.height/2 - newImageSize.height/2, width: newImageSize.width, height: newImageSize.height)
        return centerFrame
    }
    
    func centerScrollViewContents()
    {
        let boundsSize = scrollView.frame
        var contentsFrame = self.imageView.frame
        
        // Width
        if contentsFrame.size.width < boundsSize.width {
            contentsFrame.origin.x = (boundsSize.width - contentsFrame.size.width) / 2
        } else {
            contentsFrame.origin.x = 0
        }
        
        // Height
        if contentsFrame.size.height < boundsSize.height {
            contentsFrame.origin.y = (boundsSize.height - contentsFrame.size.height) / 2
        } else {
            contentsFrame.origin.y = 0
        }
        
        self.imageView.frame = contentsFrame
    }
    
    // Handle device change orientation
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        self.scrollView.frame = CGRect(origin: CGPointZero, size: size)
        self.imageView.frame = self.centerFrameFromImage(self.imageView.image)
        centerScrollViewContents()
    }

}

extension PhotoViewController: UIScrollViewDelegate
{
    func scrollViewDidScroll(scrollView: UIScrollView) {
        centerScrollViewContents()
    }
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
}

// Popover
extension PhotoViewController: UIPopoverPresentationControllerDelegate
{
//    // not help to fix popover view background color for iPad
//    func presentationController(presentationController: UIPresentationController, willPresentWithAdaptiveStyle style: UIModalPresentationStyle, transitionCoordinator: UIViewControllerTransitionCoordinator?)
//    {
//        guard let commentTVC = presentationController.presentedViewController as? PhotoCommentsTableViewController else { return }
//        print("something set")
//        //commentTVC.tableView.contentSize = CGSize(width: 320, height: 680)
//        commentTVC.tableView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
//        if let ppc = commentTVC.popoverPresentationController {
//            ppc.backgroundColor = UIColor.blackColor()
//            print("set ppc bg black")
//        } else {
//            print("ppc is nil")
//        }
//        
//        commentTVC.tableView.backgroundColor = UIColor.blackColor()
//    }
    
    // The following two methods will be invoked on iPhone, not on iPad
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle
    {
        return UIModalPresentationStyle.OverCurrentContext
    }
    
    // When present the comment table view controller need this for iPhone only
    // The view controller to display in place of the existing presented view controller.
    func presentationController(controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController?
    {
        return UINavigationController(rootViewController: controller.presentedViewController)
    }

}
