import UserNotifications

let HoldNotificationCategoryIdentifier = "NYPLHoldToReserveNotificationCategory"
let CheckOutActionIdentifier = "NYPLCheckOutNotificationAction"
let DefaultActionIdentifier = "UNNotificationDefaultActionIdentifier"

@available (iOS 10.0, *)
@objcMembers class NYPLUserNotifications: NSObject
{
  let unCenter = UNUserNotificationCenter.current()

  /// If a user has not yet been presented with Notifications authorization,
  /// defer the presentation for later to maximize acceptance rate. Otherwise,
  /// Apple documents authorization to be preformed at app-launch to correctly
  /// enable the delegate.
  func authorizeIfNeeded()
  {
    unCenter.delegate = self
    unCenter.getNotificationSettings { (settings) in
      if settings.authorizationStatus == .notDetermined {
        Log.info(#file, "Deferring first-time UN Auth to a later time.")
      } else {
        self.registerNotificationCategories()
        NYPLUserNotifications.requestAuthorization()
      }
    }
  }

  class func requestAuthorization()
  {
    let unCenter = UNUserNotificationCenter.current()
    unCenter.requestAuthorization(options: [.badge,.sound,.alert]) { (granted, error) in
      Log.info(#file, "Notification Authorization Results: 'Granted': \(granted)." +
        " 'Error': \(error?.localizedDescription ?? "nil")")
    }
  }

  /// Create a local notification if a book has moved from the "holds queue" to
  /// the "reserved queue", and is available for the patron to checkout.
  class func compareAvailability(cachedRecord:NYPLBookRegistryRecord, andNewBook newBook:NYPLBook)
  {
    var wasOnHold = false
    var isNowReady = false
    let oldAvail = cachedRecord.book.defaultAcquisition()?.availability
    oldAvail?.matchUnavailable(nil,
                               limited: nil,
                               unlimited: nil,
                               reserved: { _ in wasOnHold = true },
                               ready: nil)
    let newAvail = newBook.defaultAcquisition()?.availability
    newAvail?.matchUnavailable(nil,
                               limited: nil,
                               unlimited: nil,
                               reserved: nil,
                               ready: { _ in isNowReady = true })

    if (wasOnHold && isNowReady) {
      createNotificationForReadyCheckout(book: newBook)
    }
  }

  class func updateAppIconBadge(heldBooks: [NYPLBook])
  {
    var readyBooks = 0
    for book in heldBooks {
      book.defaultAcquisition()?.availability.matchUnavailable(nil,
                                                               limited: nil,
                                                               unlimited: nil,
                                                               reserved: nil,
                                                               ready: { _ in readyBooks += 1 })
    }
    if UIApplication.shared.applicationIconBadgeNumber != readyBooks {
      UIApplication.shared.applicationIconBadgeNumber = readyBooks
    }
  }

  private class func createNotificationForReadyCheckout(book: NYPLBook)
  {
    let unCenter = UNUserNotificationCenter.current()
    unCenter.getNotificationSettings { (settings) in
      guard settings.authorizationStatus == .authorized else { return }

      let title = NSLocalizedString("Ready for Download", comment: "")
      let content = UNMutableNotificationContent()
      if let bookTitle = book.title {
        content.body = NSLocalizedString("The title you reserved, \(bookTitle), is available.", comment: "")
      } else {
        content.body = NSLocalizedString("The title you reserved is available.", comment: "")
      }
      content.title = title
      content.sound = UNNotificationSound.default
      content.categoryIdentifier = HoldNotificationCategoryIdentifier
      content.userInfo = ["bookID" : book.identifier]

      let request = UNNotificationRequest.init(identifier: book.identifier,
                                               content: content,
                                               trigger: nil)
      unCenter.add(request) { error in
        if (error != nil) {
          Log.error(#file, "Error creating notification for: \(book.title ?? "--")." +
            "Reason: \(error?.localizedDescription ?? "nil")")
        }
      }
    }
  }

  @objc class func testSyncStarted() {
    let unCenter = UNUserNotificationCenter.current()
    unCenter.getNotificationSettings { (settings) in
      guard settings.authorizationStatus == .authorized else { return }

      let title = NSLocalizedString("BETA TEST", comment: "")
      let content = UNMutableNotificationContent()
      content.body = NSLocalizedString("Background Sync Began", comment: "")

      content.title = title
      content.sound = UNNotificationSound.default
      content.categoryIdentifier = HoldNotificationCategoryIdentifier


      let request = UNNotificationRequest.init(identifier: UUID.init().uuidString,
                                               content: content,
                                               trigger: nil)
      unCenter.add(request) { error in
        if (error != nil) {
          Log.error(#file, "Error creating BETA TEST notification.")
        }
      }
    }
  }

  @objc class func testSyncEnded(status: Int) {
    let unCenter = UNUserNotificationCenter.current()
    unCenter.getNotificationSettings { (settings) in
      guard settings.authorizationStatus == .authorized else { return }

      let title = NSLocalizedString("BETA TEST", comment: "")
      let content = UNMutableNotificationContent()
      content.body = NSLocalizedString("Background Sync Ended with Status: \(status)", comment: "")

      content.title = title
      content.sound = UNNotificationSound.default
      content.categoryIdentifier = HoldNotificationCategoryIdentifier


      let request = UNNotificationRequest.init(identifier: UUID.init().uuidString,
                                               content: content,
                                               trigger: nil)
      unCenter.add(request) { error in
        if (error != nil) {
          Log.error(#file, "Error creating BETA TEST notification.")
        }
      }
    }
  }

  @objc class func testSyncEndedAlreadySyncing() {
    let unCenter = UNUserNotificationCenter.current()
    unCenter.getNotificationSettings { (settings) in
      guard settings.authorizationStatus == .authorized else { return }

      let title = NSLocalizedString("BETA TEST", comment: "")
      let content = UNMutableNotificationContent()
      content.body = NSLocalizedString("Sync Ended (ALREADY SYNCING).", comment: "")

      content.title = title
      content.sound = UNNotificationSound.default

      let request = UNNotificationRequest.init(identifier: UUID.init().uuidString,
                                               content: content,
                                               trigger: nil)
      unCenter.add(request) { error in
        if (error != nil) {
          Log.error(#file, "Error creating BETA TEST notification.")
        }
      }
    }
  }

  @objc class func testSyncEndedNoCreds() {
    let unCenter = UNUserNotificationCenter.current()
    unCenter.getNotificationSettings { (settings) in
      guard settings.authorizationStatus == .authorized else { return }

      let title = NSLocalizedString("BETA TEST", comment: "")
      let content = UNMutableNotificationContent()
      content.body = NSLocalizedString("Sync Ended (NO FOUND CREDENTIALS).", comment: "")

      content.title = title
      content.sound = UNNotificationSound.default

      let request = UNNotificationRequest.init(identifier: UUID.init().uuidString,
                                               content: content,
                                               trigger: nil)
      unCenter.add(request) { error in
        if (error != nil) {
          Log.error(#file, "Error creating BETA TEST notification.")
        }
      }
    }
  }

  @objc class func testSyncEndedResetOccurred() {
    let unCenter = UNUserNotificationCenter.current()
    unCenter.getNotificationSettings { (settings) in
      guard settings.authorizationStatus == .authorized else { return }

      let title = NSLocalizedString("BETA TEST", comment: "")
      let content = UNMutableNotificationContent()
      content.body = NSLocalizedString("Sync Ended (A RESET HAS OCCURRED).", comment: "")

      content.title = title
      content.sound = UNNotificationSound.default

      let request = UNNotificationRequest.init(identifier: UUID.init().uuidString,
                                               content: content,
                                               trigger: nil)
      unCenter.add(request) { error in
        if (error != nil) {
          Log.error(#file, "Error creating BETA TEST notification.")
        }
      }
    }
  }

  class func testSyncActionItemFinished() {
    let unCenter = UNUserNotificationCenter.current()
    unCenter.getNotificationSettings { (settings) in
      guard settings.authorizationStatus == .authorized else { return }

      let title = NSLocalizedString("BETA TEST", comment: "")
      let content = UNMutableNotificationContent()
      content.body = NSLocalizedString("Notification Action Finished.", comment: "")

      content.title = title
      content.sound = UNNotificationSound.default

      let request = UNNotificationRequest.init(identifier: UUID.init().uuidString,
                                               content: content,
                                               trigger: nil)
      unCenter.add(request) { error in
        if (error != nil) {
          Log.error(#file, "Error creating BETA TEST notification.")
        }
      }
    }
  }

  @objc class func testSyncExpired() {
    let unCenter = UNUserNotificationCenter.current()
    unCenter.getNotificationSettings { (settings) in
      guard settings.authorizationStatus == .authorized else { return }

      let title = NSLocalizedString("BETA TEST", comment: "")
      let content = UNMutableNotificationContent()
      content.body = NSLocalizedString("Error: Background Sync expired before completing", comment: "")

      content.title = title
      content.sound = UNNotificationSound.default

      let request = UNNotificationRequest.init(identifier: UUID.init().uuidString,
                                               content: content,
                                               trigger: nil)
      unCenter.add(request) { error in
        if (error != nil) {
          Log.error(#file, "Error creating BETA TEST notification.")
        }
      }
    }
  }

  private func registerNotificationCategories()
  {
    let checkOutNotificationAction = UNNotificationAction(identifier: CheckOutActionIdentifier,
                                                          title: NSLocalizedString("Check Out", comment: ""),
                                                          options: [])
    let holdToReserveCategory = UNNotificationCategory(identifier: HoldNotificationCategoryIdentifier,
                                                       actions: [checkOutNotificationAction],
                                                       intentIdentifiers: [],
                                                       options: [])
    UNUserNotificationCenter.current().setNotificationCategories([holdToReserveCategory])
  }
}

@available (iOS 10.0, *)
extension NYPLUserNotifications: UNUserNotificationCenterDelegate
{
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
  {
    completionHandler([.alert])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void)
  {
    if response.actionIdentifier == DefaultActionIdentifier {
      let currentAccount = AccountsManager.shared.currentAccount
      if currentAccount.supportsReservations {
        if let holdsTab = NYPLRootTabBarController.shared()?.viewControllers?[2],
        holdsTab.isKind(of: NYPLHoldsNavigationController.self) {
          NYPLRootTabBarController.shared()?.selectedIndex = 2
        } else {
          Log.error(#file, "Error moving to Holds tab from notification.")
        }
      }
      completionHandler()
    }
    else if response.actionIdentifier == CheckOutActionIdentifier {
      Log.debug(#file, "'Check Out' Notification Action.")
      let userInfo = response.notification.request.content.userInfo
      guard let bookID = userInfo["bookID"] as? String else {
        Log.error(#file, "Bad user info in Local Notification. UserInfo: \n\(userInfo)")
        return
      }
      guard let downloadCenter = NYPLMyBooksDownloadCenter.shared(),
        let book = NYPLBookRegistry.shared()?.book(forIdentifier: bookID) else {
          Log.error(#file, "Problem creating book or download center singleton. BookID: \(bookID)")
          return
      }

      // Asynchronous network task in the background app state.
      let bgTask = UIApplication.shared.beginBackgroundTask {
        Log.error(#file, "Background task expired before borrow action could complete.")
        completionHandler()
      }
      downloadCenter.startBorrow(for: book, attemptDownload: false) {
        Log.debug(#file, "Borrow has completed.")
        NYPLUserNotifications.testSyncActionItemFinished()
        completionHandler()
        UIApplication.shared.endBackgroundTask(bgTask)
      }
    }
  }
}
