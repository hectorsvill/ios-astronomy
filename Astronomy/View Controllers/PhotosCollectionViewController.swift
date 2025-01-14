//
//  PhotosCollectionViewController.swift
//  Astronomy
//
//  Created by Andrew R Madsen on 9/5/18.
//  Copyright © 2018 Lambda School. All rights reserved.
//

import UIKit

class PhotosCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        client.fetchMarsRover(named: "curiosity") { (rover, error) in
            if let error = error {
                NSLog("Error fetching info for curiosity: \(error)")
                return
            }
            self.roverInfo = rover

        }
		photoFetchQueue.name = "com.Astronomy.PhotoFetchQueue"
    }
    
    // UICollectionViewDataSource/Delegate
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return photoReferences.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
      //  let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as? ImageCollectionViewCell ?? ImageCollectionViewCell()
		
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath)
		guard let imageCell = cell as? ImageCollectionViewCell else { return cell}
		
		
		
        loadImage(forCell: imageCell, forItemAt: indexPath)
        
        return imageCell
    }
	
	// MARK: - Private
	
	private func loadImage(forCell cell: ImageCollectionViewCell, forItemAt indexPath: IndexPath) {
		let photoReference = photoReferences[indexPath.item]
		
		if let imageData = imageCache.value(for: photoReference.id) {
			cell.imageView.image = UIImage(data: imageData)
			return
		}
		
		let fetchImageOP = FetchPhotoOperation(marsPhotoReference: photoReference)

		let storeToCache = BlockOperation {
			if let imageDate = fetchImageOP.imageData {
				self.imageCache.cache(value: imageDate, for: photoReference.id)
			}
		}
		
		let cellReusedCheck = BlockOperation {
			if  self.collectionView.indexPath(for: cell)  == indexPath {
				print("here \(indexPath.item)")
				guard let imageData = fetchImageOP.imageData else { return }
				cell.imageView.image = UIImage(data: imageData)
			}
		}
		
		storeToCache.addDependency(fetchImageOP)
		cellReusedCheck.addDependency(fetchImageOP)
		
		photoFetchQueue.addOperations([fetchImageOP, storeToCache], waitUntilFinished: false)
		OperationQueue.main.addOperation(cellReusedCheck)
		fetchPhotoOperations[photoReference.id] = fetchImageOP
	}
	
	
	func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		let photoReference = photoReferences[indexPath.item]
		fetchPhotoOperations[photoReference.id]?.cancel()
	}
	
	
	
    // Make collection view cells fill as much available width as possible
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let flowLayout = collectionViewLayout as! UICollectionViewFlowLayout
        var totalUsableWidth = collectionView.frame.width
        let inset = self.collectionView(collectionView, layout: collectionViewLayout, insetForSectionAt: indexPath.section)
        totalUsableWidth -= inset.left + inset.right
        
        let minWidth: CGFloat = 150.0
        let numberOfItemsInOneRow = Int(totalUsableWidth / minWidth)
        totalUsableWidth -= CGFloat(numberOfItemsInOneRow - 1) * flowLayout.minimumInteritemSpacing
        let width = totalUsableWidth / CGFloat(numberOfItemsInOneRow)
        return CGSize(width: width, height: width)
    }
    
    // Add margins to the left and right side
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 10.0, bottom: 0, right: 10.0)
    }
    
	
    
    // Properties
    
    private let client = MarsRoverClient()
    
    private var roverInfo: MarsRover? {
        didSet {
            solDescription = roverInfo?.solDescriptions[3]
        }
    }
    private var solDescription: SolDescription? {
        didSet {
            if let rover = roverInfo,
                let sol = solDescription?.sol {
                client.fetchPhotos(from: rover, onSol: sol) { (photoRefs, error) in
                    if let e = error { NSLog("Error fetching photos for \(rover.name) on sol \(sol): \(e)"); return }
                    self.photoReferences = photoRefs ?? []
                }
            }
        }
    }
    private var photoReferences = [MarsPhotoReference]() {
        didSet {
			DispatchQueue.main.async { self.collectionView?.reloadData() }
        }
    }
    
    @IBOutlet var collectionView: UICollectionView!
	
	var imageCache = Cache<Int, Data>()
	private let photoFetchQueue = OperationQueue()
	var fetchPhotoOperations: [Int: FetchPhotoOperation] = [:]
}
