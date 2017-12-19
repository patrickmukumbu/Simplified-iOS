import UIKit

/// Table view cells that display a library name and subtitle
class NYPLLibraryTableViewCell: UITableViewCell {
  
  required init(library: Account, style: UITableViewCellStyle, reuseID: String?) {

    super.init(style: style, reuseIdentifier: reuseID)
    
    imageView?.contentMode = .scaleAspectFit
    if let logo = library.logo {
      imageView?.image = UIImage.init(named: logo)
    } else {
      imageView?.image = #imageLiteral(resourceName: "LibraryLogoMagic")
    }
    
    textLabel?.font = UIFont.customFont(forTextStyle: .body)
    textLabel?.text = library.name
    textLabel?.numberOfLines = 2
    
    detailTextLabel?.font = UIFont(name: "AvenirNext-Regular", size: 12)
    detailTextLabel?.text = library.subtitle
    detailTextLabel?.numberOfLines = 3
  }
  
  required init?(coder aDecoder: NSCoder) {
    Log.error(#file, "Class should only be initialized from code, not a storyboard.")
    return nil
  }
  
  // iOS bug ignores detail text label when dynamically creating cell height
  override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                        verticalFittingPriority: UILayoutPriority) -> CGSize {
    
    if #available(iOS 11.0, *) {
      return super.systemLayoutSizeFitting(targetSize,
                                           withHorizontalFittingPriority: horizontalFittingPriority,
                                           verticalFittingPriority: verticalFittingPriority)
    }
    
    layoutIfNeeded()
    var size = super.systemLayoutSizeFitting(targetSize,
                                             withHorizontalFittingPriority: horizontalFittingPriority,
                                             verticalFittingPriority: verticalFittingPriority)
    
    guard let detailTextLabel = self.detailTextLabel, let textLabel = self.textLabel else {
      return size
    }
    
    let detailHeight = detailTextLabel.frame.height
    if (detailHeight != 0) {
      if (detailTextLabel.frame.minX > textLabel.frame.minX) {
        let textHeight = textLabel.frame.height
        if (detailHeight > textHeight) {
          size.height += detailHeight - textHeight
        }
      } else {
        size.height += detailHeight
      }
    }
    
    return size
  }
}
