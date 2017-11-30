#import "NYPLReadiumViewSyncManager.h"

#import "NSDate+NYPLDateAdditions.h"
#import "NYPLAccount.h"
#import "NYPLBook.h"
#import "NYPLBookLocation.h"
#import "NYPLBookRegistry.h"
#import "NYPLConfiguration.h"
#import "NYPLJSON.h"
#import "NYPLReachability.h"
#import "NYPLReaderSettings.h"
#import "NYPLRootTabBarController.h"
#import "SimplyE-Swift.h"


@interface NYPLReadiumViewSyncManager ()

@property (nonatomic) NSString *bookID;
@property (nonatomic) NSURL *annotationsURL;
@property (nonatomic) NSDictionary *bookMapDictionary;
@property (nonatomic, weak) id<NYPLReadiumViewSyncManagerDelegate> delegate;

@end

@implementation NYPLReadiumViewSyncManager

- (instancetype) initWithBookID:(NSString *)bookID
                 annotationsURL:(NSURL *)URL
                        bookMap:(NSDictionary *)map
                       delegate:(id)delegate
{
  self = [super init];
  if (self) {
    self.bookID = bookID;
    self.annotationsURL = URL;
    self.bookMapDictionary = map;
    self.delegate = delegate;
  }
  return self;
}

- (void)syncAnnotationsWithPermissionForAccount:(Account *)account
                                withPackageDict:(NSDictionary *)packageDict
{
  if (account.syncPermissionGranted) {

    NSMutableDictionary *const dictionary = [NSMutableDictionary dictionary];
    dictionary[@"package"] = packageDict;
    dictionary[@"settings"] = [[NYPLReaderSettings sharedSettings] readiumSettingsRepresentation];
    NYPLBookLocation *const location = [[NYPLBookRegistry sharedRegistry]
                                        locationForIdentifier:self.bookID];
    
    [self syncReadingPositionForBook:self.bookID
                          atLocation:location
                               toURL:self.annotationsURL
                         withPackage:dictionary];
    
    [self syncBookmarksWithCompletion:^(BOOL success, NSArray<NYPLReaderBookmarkElement *> *bookmarks) {
      if ([self.delegate respondsToSelector:@selector(didCompleteBookmarkSync:withBookmarks:)]) {
        [self.delegate didCompleteBookmarkSync:success withBookmarks:bookmarks];
      }
    }];
  }
}

- (void)syncReadingPositionForBook:(NSString *)bookID
                        atLocation:(NYPLBookLocation *)location
                             toURL:(NSURL *)URL
                       withPackage:(NSMutableDictionary *)dictionary
{
  [NYPLAnnotations syncReadingPositionOfBook:bookID toURL:URL completionHandler:^(NSDictionary * _Nullable responseObject) {

    if (!responseObject) {
      NYPLLOG(@"No Server Annotation for this book exists.");
      [self shouldPostLastRead:YES];
      return;
    }

    NSDictionary *responseJSON = [NSJSONSerialization JSONObjectWithData:[responseObject[@"serverCFI"] dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    NSString* deviceIDString = responseObject[@"device"];
    NSString* serverLocationString = responseObject[@"serverCFI"];
    NSString* currentLocationString = location.locationString;
    NYPLLOG_F(@"serverLocationString %@",serverLocationString);
    NYPLLOG_F(@"currentLocationString %@",currentLocationString);

    NSDictionary *spineItemDetails = self.bookMapDictionary[responseJSON[@"idref"]];
    NSString *elementTitle = spineItemDetails[@"tocElementTitle"];
    if (!elementTitle) {
      elementTitle = @"";
    }
                
    NSString *message = [NSString stringWithFormat:@"Would you like to go to the latest page read?\n\nChapter:\n\"%@\"",elementTitle];

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Sync Reading Position"
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    [alertController addAction:
     [UIAlertAction actionWithTitle:NSLocalizedString(@"NO", nil)
                              style:UIAlertActionStyleCancel
                            handler:^(__attribute__((unused))UIAlertAction * _Nonnull action) {
                              if ([self.delegate respondsToSelector:@selector(patronDecidedNavigation:withNavDict:)]) {
                                [self.delegate patronDecidedNavigation:NO withNavDict:nil];
                              }
                            }]];

    [alertController addAction:
     [UIAlertAction actionWithTitle:NSLocalizedString(@"YES", nil)
                              style:UIAlertActionStyleDefault
                            handler:^(__attribute__((unused))UIAlertAction * _Nonnull action) {

                              [self shouldPostLastRead:YES];

                              NSDictionary *const locationDictionary =
                              NYPLJSONObjectFromData([serverLocationString dataUsingEncoding:NSUTF8StringEncoding]);

                              NSString *contentCFI = locationDictionary[@"contentCFI"];
                              if (!contentCFI) {
                                contentCFI = @"";
                              }
                              dictionary[@"openPageRequest"] =
                              @{@"idref": locationDictionary[@"idref"], @"elementCfi": contentCFI};

                              if ([self.delegate respondsToSelector:@selector(patronDecidedNavigation:withNavDict:)]) {
                                [self.delegate patronDecidedNavigation:YES withNavDict:dictionary];
                              }
                            }]];

    // Pass through without presenting the Alert Controller if:
    // 1 - The most recent page on the server comes from the same device
    // 2 - The server and the client have the same page marked
    // 3 - There is no recent page saved on the server
    if ((currentLocationString && [deviceIDString isEqualToString:[NYPLAccount sharedAccount].deviceID]) ||
      [currentLocationString isEqualToString:serverLocationString] ||
      !serverLocationString) {
      [self shouldPostLastRead:YES];
    } else {
      [[NYPLRootTabBarController sharedController] safelyPresentViewController:alertController animated:YES completion:nil];
    }
  }];
}

- (void)shouldPostLastRead:(BOOL)status
{
  if ([self.delegate respondsToSelector:@selector(shouldPostReadingPosition:)]) {
    [self.delegate shouldPostReadingPosition:status];
  }
}

- (void)addBookmark:(NYPLReaderBookmarkElement *)bookmark
            withCFI:(NSString *)location
            forBook:(NSString *)bookID
{
  Account *currentAccount = [[AccountsManager sharedInstance] currentAccount];
  if (currentAccount.syncPermissionGranted) {
    [NYPLAnnotations postBookmarkForBook:bookID toURL:nil bookmark:bookmark
                       completionHandler:^(NSString * _Nullable serverAnnotationID) {
                         if (serverAnnotationID) {
                           NYPLLOG_F(@"Bookmark upload success: %@", location);
                         } else {
                           NYPLLOG_F(@"Bookmark failed to upload: %@", location);
                         }
//                         bookmark.annotationId = serverAnnotationID;
                         //GODO maybe there's more to abstract out of readium view now.
                         [self.delegate uploadFinishedForBookmark:bookmark inBook:bookID];
                       }];
  } else {
    [self.delegate uploadFinishedForBookmark:bookmark inBook:bookID];
    NYPLLOG(@"Bookmark saving locally. Sync is not enabled for account.");
  }
}

//GODO need to test
- (void)syncBookmarksWithCompletion:(void(^)(BOOL success, NSArray<NYPLReaderBookmarkElement *> *bookmarks))completion
{
  [[NYPLReachability sharedReachability]
   reachabilityForURL:[NYPLConfiguration mainFeedURL]
   timeoutInternal:8.0
   handler:^(BOOL reachable) {

     if (!reachable) {
       //GODO Alert Controller here?
       NYPLLOG(@"Error: host was not reachable for bookmark sync attempt.");
       //GODO is completion corect here?
//       completion(NO, nil);
       return;
     }

     // Sync: First upload any local bookmarks that have never been saved to the server.
     // Then pull server bookmark list and filter out any that can be deleted.

     NSArray<NYPLReaderBookmarkElement *> *localBookmarks = [[NYPLBookRegistry sharedRegistry] bookmarksForIdentifier:self.bookID].mutableCopy;
     NYPLLOG_F(@"\nLocally Saved Bookmarks:\n\n%@", localBookmarks);
     
     [NYPLAnnotations uploadLocalBookmarks:localBookmarks forBook:self.bookID completion:^(NSArray<NYPLReaderBookmarkElement *> * _Nonnull updatedBookmarks, NSArray<NYPLReaderBookmarkElement *> * _Nonnull localsNotUploaded) {

       NYPLLOG_F(@"\nUploaded Bookmarks:\n\n%@", updatedBookmarks);
       NYPLLOG_F(@"\nBookmarks That Failed To Upload:\n\n%@", localsNotUploaded);

       [NYPLAnnotations getServerBookmarksForBook:self.bookID atURL:self.annotationsURL completionHandler:^(NSArray<NYPLReaderBookmarkElement *> * _Nonnull serverBookmarks) {

         if (serverBookmarks.count == 0) {
           NYPLLOG(@"No server bookmarks were returned.");
         } else {
           NYPLLOG_F(@"\nServer Bookmarks:\n\n%@", serverBookmarks);
         }

         NSMutableArray<NYPLReaderBookmarkElement *> *localBookmarksToKeep = [[NSMutableArray alloc] init];
         NSMutableArray<NYPLReaderBookmarkElement *> *localBookmarksToDelete = [[NSMutableArray alloc] init];
         NSMutableArray<NYPLReaderBookmarkElement *> *serverBookmarksToKeep = serverBookmarks.mutableCopy;
         NSMutableArray<NYPLReaderBookmarkElement *> *serverBookmarksToDelete = [[NSMutableArray alloc] init];

         for (NYPLReaderBookmarkElement *serverBookmark in serverBookmarks) {
           NSPredicate *predicate = [NSPredicate predicateWithFormat:@"annotationId == %@", serverBookmark.annotationId];
           NSArray *matchingBookmarks = [localBookmarks filteredArrayUsingPredicate:predicate];

           [localBookmarksToKeep addObjectsFromArray:matchingBookmarks];

           // Server bookmarks, created on this device, that are no longer present as a local bookmark,
           // should be deleted on the server.
           if (matchingBookmarks.count == 0 &&
               [serverBookmark.device isEqualToString:[[NYPLAccount sharedAccount] deviceID]]) {
             [serverBookmarksToDelete addObject:serverBookmark];
             [serverBookmarksToKeep removeObject:serverBookmark];
           }
         }

         for (NYPLReaderBookmarkElement *localBookmark in localBookmarks) {
           if (![localBookmarksToKeep containsObject:localBookmark]) {
             [[NYPLBookRegistry sharedRegistry] deleteBookmark:localBookmark forIdentifier:self.bookID];
             [localBookmarksToDelete addObject:localBookmark];
           }
         }
         //GODO temp logging
         NYPLLOG_F(@"\nLocal Bookmarks To Delete:\n\n%@", localBookmarksToDelete);

         NSMutableArray<NYPLReaderBookmarkElement *> *bookmarksToAdd = serverBookmarks.mutableCopy;
         for (NYPLReaderBookmarkElement *serverMark in serverBookmarksToKeep) {
           for (NYPLReaderBookmarkElement *localMark in localBookmarksToKeep) {
             if ([serverMark isEqual:localMark]) {
               [bookmarksToAdd removeObject:serverMark];
             }
           }
         }
         [bookmarksToAdd addObjectsFromArray:updatedBookmarks];
         [bookmarksToAdd addObjectsFromArray:localsNotUploaded];
         NYPLLOG_F(@"\nNew Bookmarks To Save Locally:\n\n%@", bookmarksToAdd);

         for (NYPLReaderBookmarkElement *bookmark in bookmarksToAdd) {
           [[NYPLBookRegistry sharedRegistry] addBookmark:bookmark forIdentifier:self.bookID];
         }

         if (serverBookmarksToDelete.count > 0) {
           NYPLLOG_F(@"\nServer Bookmarks To Delete:\n\n%@", serverBookmarksToDelete);
           [NYPLAnnotations deleteBookmarks:serverBookmarksToDelete completionHandler:^{
             completion(YES,[[NYPLBookRegistry sharedRegistry] bookmarksForIdentifier:self.bookID]);
           }];
         } else {
           completion(YES,[[NYPLBookRegistry sharedRegistry] bookmarksForIdentifier:self.bookID]);
         }
       }];
     }];
   }];
}

@end
