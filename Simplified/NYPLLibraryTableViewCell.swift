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
    
    textLabel?.font = UIFont.systemFont(ofSize: 14)
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
}
