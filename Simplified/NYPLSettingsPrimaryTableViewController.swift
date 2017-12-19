@objc enum PrimaryTableViewStaticCellType: Int {
  case newAccount
  case about
  case eula
  case helpStack
  case customFeedUrl
  case softwareLicenses
}

fileprivate func stringFor(_ cellType: PrimaryTableViewStaticCellType) -> String {
  switch cellType {
  case .newAccount:
    return "Add a Library"
  case .about:
    return "AboutApp"
  case .eula:
    return "EULA"
  case .helpStack:
    return "Help"
  case .customFeedUrl:
    return "Custom Feed URL"
  case .softwareLicenses:
    return "SoftwareLicenses"
  }
}

@objc protocol NYPLSettingsAccountsTableViewControllerDelegate {
  func didSelect(staticCell: PrimaryTableViewStaticCellType,
                 atPath path: IndexPath,
                 fromPrimaryViewController primaryVC: NYPLSettingsPrimaryTableViewController)
  func didSelect(library: Int,
                 atPath path: IndexPath,
                 fromPrimaryViewController primaryVC: NYPLSettingsPrimaryTableViewController)
}

/// Primary view of Settings Split View Controller that shows list of
/// user-added libraries as well as various other Settings-related cells.
final class NYPLSettingsPrimaryTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {

  weak var delegate: NYPLSettingsAccountsTableViewControllerDelegate?
  weak var tableView: UITableView!
  
  fileprivate var accounts: [Int]
  fileprivate var libraryAccounts: [Account]
  fileprivate var userAddedSecondaryAccounts: [Int]
  fileprivate let manager: AccountsManager
  fileprivate var staticTableViewSections: [[PrimaryTableViewStaticCellType]]!
  
  fileprivate var infoLabel: UILabel?
  
  // MARK: -
  
  required init(accounts: [Int]) {
    self.accounts = accounts
    self.userAddedSecondaryAccounts = accounts.filter { $0 != AccountsManager.shared.currentAccount.id }
    self.manager = AccountsManager.shared
    self.libraryAccounts = manager.accounts
    
    self.staticTableViewSections = [
      [.helpStack],
      [.about,
       .eula,
       .softwareLicenses]
    ]

    super.init(nibName:nil, bundle:nil)
  }

  @available(*, unavailable)
  required init(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  // MARK: - UIViewController
  
  override func loadView() {
    view = UITableView(frame: CGRect.zero, style: .grouped)
    tableView = self.view as! UITableView
    tableView.delegate = self
    tableView.dataSource = self
    
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "accountListCell")
    
    title = NSLocalizedString("Settings", comment:"")
    view.backgroundColor = NYPLConfiguration.backgroundColor()
    
    // Filter out any libraries that are not currently in Accounts.json
    // FIXME: Remove when Library Registry is implemented
    accounts = accounts.filter { AccountsManager.shared.account($0) != nil }
    
    updateNYPLSettingsAccountList()
    
    tableView.selectRow(at: IndexPath.init(row: 0, section: 0), animated: false, scrollPosition: .top)
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(reloadAfterAccountChange),
                                           name: NSNotification.Name(rawValue: NYPLCurrentAccountDidChangeNotification),
                                           object: nil)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if splitViewController?.traitCollection.horizontalSizeClass == .compact {
      if let selectedRow = tableView.indexPathForSelectedRow {
        tableView.deselectRow(at: selectedRow, animated: true)
      }
    }
  }
  
  func addALibrary() {
    
    let accountsToAdd = libraryAccounts.filter {
      !userAddedSecondaryAccounts.contains($0.id) && $0.id != manager.currentAccount.id
    }
    let libraryChooser = NYPLAccountListChooser(accounts: accountsToAdd) { chosenAccount in
      self.userAddedSecondaryAccounts.append(chosenAccount.id)
      self.updateNYPLSettingsAccountList()
      let rowPosition = self.userAddedSecondaryAccounts.count - 1
      let indexPathForInsertion = IndexPath.init(row: rowPosition, section: 1)
      self.tableView.insertRows(at: [indexPathForInsertion], with: .left)
    }
    
    let navVC = UINavigationController(rootViewController: libraryChooser)
    self.splitViewController?.showDetailViewController(navVC, sender: self)
  }
  
  func reloadAfterAccountChange() {
    accounts = NYPLSettings.shared().settingsAccountsList as! [Int]
    userAddedSecondaryAccounts = accounts.filter { $0 != manager.currentAccount.id }
    tableView.reloadData()
  }
  
  func updateNYPLSettingsAccountList() {
    var array = userAddedSecondaryAccounts
    array.append(manager.currentAccount.id)
    NYPLSettings.shared().settingsAccountsList = array
  }
  
  // MARK: - UITableViewDataSource
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      return 1
    } else if section == 1 {
      return userAddedSecondaryAccounts.count + 1
    } else if section > 1 && section < staticTableViewSections.count + 2 {
      return staticTableViewSections[section-2].count
    } else {
      return 0
    }
  }
  
  func numberOfSections(in tableView: UITableView) -> Int {
    return staticTableViewSections.count + 2
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    
    var cellType: PrimaryTableViewStaticCellType?
    if indexPath.section > 1 {
      cellType = staticTableViewSections[indexPath.section - 2][indexPath.row]
    }
    
    if indexPath.section == 0 {
      return cellForLibrary(self.manager.currentAccount, indexPath)
    } else if indexPath.section == 1 {
      if indexPath.row < userAddedSecondaryAccounts.count {
        return cellForLibrary(AccountsManager.shared.account(
          userAddedSecondaryAccounts[indexPath.row])!, indexPath)
      } else {
        return tableViewCell(withString: "Add a Library")
      }
    } else if cellType == .customFeedUrl {
      return customFeedURLCell()
    } else {
      return staticTableViewCell(indexPath)
    }
  }
  
  private func staticTableViewCell(_ path: IndexPath) -> UITableViewCell {
    let cellString = stringFor(staticTableViewSections[path.section-2][path.row])
    return tableViewCell(withString: cellString)
  }
  
  private func customFeedURLCell() -> UITableViewCell {
    let cell = UITableViewCell.init(style: .default, reuseIdentifier: nil)
    let textField = UITextField.init(frame: CGRect.init(x: 15, y: 0, width: cell.frame.size.width-30, height: cell.frame.size.height))
    textField.autoresizingMask = .flexibleWidth
    textField.delegate = self
    textField.text = NYPLSettings.shared().customMainFeedURL?.absoluteString
    textField.placeholder = "Custom HTTP(S) OPDS URL"
    textField.keyboardType = .URL
    textField.returnKeyType = .done
    textField.clearButtonMode = .whileEditing
    textField.spellCheckingType = .no
    textField.autocorrectionType = .no
    textField.autocapitalizationType = .none
    cell.contentView.addSubview(textField)
    return cell
  }
  
  func tableViewCell(withString string: String) -> UITableViewCell {
    let cell = UITableViewCell.init(style: .default, reuseIdentifier: nil)
    cell.textLabel?.text = NSLocalizedString(string, comment: "")
    cell.textLabel?.font = UIFont.customFont(forTextStyle: .body)
    if splitViewController?.traitCollection.horizontalSizeClass == .compact {
      cell.accessoryType = .disclosureIndicator
    } else {
      cell.accessoryType = .none
    }
    return cell
  }
  
  func cellForLibrary(_ account: Account, _ indexPath: IndexPath) -> UITableViewCell {

    let cell = NYPLLibraryTableViewCell(library: account, style: .subtitle, reuseID: "cell")
    
    if splitViewController?.traitCollection.horizontalSizeClass == .compact {
      cell.accessoryType = .disclosureIndicator
    } else {
      cell.accessoryType = .none
    }
    
    return cell
  }
  
  // MARK: UITableViewDelegate
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    var account: Int
    if (indexPath.section == 0) {
      account = self.manager.currentAccount.id
      delegate?.didSelect(library: account, atPath: indexPath, fromPrimaryViewController: self)
    } else if (indexPath.section == 1) {
      if indexPath.row < userAddedSecondaryAccounts.count {
        account = userAddedSecondaryAccounts[indexPath.row]
        delegate?.didSelect(library: account, atPath: indexPath, fromPrimaryViewController: self)
      } else {
        addALibrary()
      }
    } else {
      delegate?.didSelect(staticCell: staticTableViewSections[indexPath.section - 2][indexPath.row], atPath: indexPath, fromPrimaryViewController: self)
    }
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return UITableViewAutomaticDimension
  }
  
  func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
    return 80
  }
  
  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    if indexPath.section == 0 {
      return false
    } else {
      return true
    }
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {    
    if (editingStyle == .delete && indexPath.section == 2 &&
    staticTableViewSections[indexPath.section - 2][indexPath.row] == .customFeedUrl) {
      NYPLSettings.shared().customMainFeedURL = nil
      self.tableView.reloadData()
      exitApp()
    } else if editingStyle == .delete {
      userAddedSecondaryAccounts.remove(at: indexPath.row)
      tableView.deleteRows(at: [indexPath], with: .fade)
      updateNYPLSettingsAccountList()
      self.tableView.reloadData()
    }
  }
  
  func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
    if indexPath.section == 1 && indexPath.row < userAddedSecondaryAccounts.count {
      return .delete
    } else {
      return .none
    }
  }
  
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    if section == 0 {
      return NSLocalizedString("Primary Account", comment: "")
    } else {
      return nil
    }
  }
  
  func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    if section == 0 {
      return NSLocalizedString("See your books and browse the catalog from this library. You may switch to another library at any time.", comment: "")
    } else {
      return nil
    }
  }
  
  func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
    
    let sectionCount = tableView.numberOfSections
    if section != sectionCount - 1 {
      return nil
    }
    if infoLabel == nil {
      infoLabel = UILabel()
      infoLabel?.font = UIFont.customFont(forTextStyle: .caption1)
      let product = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      let build = Bundle.main.object(forInfoDictionaryKey: String(kCFBundleVersionKey)) as? String
      
      infoLabel?.text = "\(product ?? "") version \(version ?? "") (\(build ?? ""))"
      infoLabel?.textAlignment = .center
      
      let tap = UITapGestureRecognizer.init(target: self, action: #selector(revealCustomOPDSFeedCell))
      tap.numberOfTapsRequired = 7
      infoLabel?.isUserInteractionEnabled = true
      infoLabel?.addGestureRecognizer(tap)
    }
    let container = UIView()
    container.addSubview(infoLabel!)
    infoLabel?.autoPinEdgesToSuperviewEdges(with: UIEdgeInsetsMake(16, 0, 0, 0))
    return container
  }
  
  func revealCustomOPDSFeedCell() {
    staticTableViewSections.append([.customFeedUrl])
    tableView.reloadData()
  }
  
  // MARK: - UITextFieldDelegate
  
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
  
  func textFieldDidEndEditing(_ textField: UITextField) {
    let feed = textField.text?.trimmingCharacters(in: .whitespaces)
    if let feed = feed, !feed.isEmpty {
      NYPLSettings.shared().customMainFeedURL = URL(string:feed)!
    } else {
      NYPLSettings.shared().customMainFeedURL = nil
    }
    exitApp()
  }
  
  func exitApp() {
    let title = NSLocalizedString("Restart Required", comment: "")
    let message = NSLocalizedString("You need to restart the app to use a new OPDS feed. Select Exit and then restart the app from the home screen.", comment: "")
    let alert = NYPLAlertController.init(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction.init(title: NSLocalizedString("Not Now", comment: ""), style: .default, handler: nil))
    alert.addAction(UIAlertAction.init(title: NSLocalizedString("Exit", comment: ""), style: .default, handler: { (action) in
      exit(0)
    }))
    alert.present(fromViewControllerOrNil: nil, animated: true, completion: nil)
  }
}

