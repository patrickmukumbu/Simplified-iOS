#import "HSHelpStack.h"
#import "HSDeskGear.h"
#import "NYPLSettingsAccountDetailViewController.h"
#import "NYPLSettingsPrimaryNavigationController.h"
#import "NYPLSettingsEULAViewController.h"
#import "NYPLSettings.h"
#import "NYPLBook.h"
#import "NYPLMyBooksDownloadCenter.h"
#import "NYPLRootTabBarController.h"
#import "SimplyE-Swift.h"

#import "NYPLSettingsSplitViewController.h"

@interface NYPLSettingsSplitViewController ()
  <UISplitViewControllerDelegate, NYPLSettingsAccountsTableViewControllerDelegate>

@property (nonatomic) NYPLSettingsPrimaryNavigationController *primaryNavigationController;
@property (nonatomic) bool isFirstLoad;

@end

@implementation NYPLSettingsSplitViewController

#pragma mark NSObject

- (instancetype)init
{
  self = [super init];
  if(!self) return nil;
  
  self.delegate = self;
  
  self.title = NSLocalizedString(@"Settings", nil);
  self.tabBarItem.image = [UIImage imageNamed:@"Settings"];
  
  self.primaryNavigationController = [[NYPLSettingsPrimaryNavigationController alloc] initWithDelegate:self];
  
  self.presentsWithGesture = NO;
  self.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
  
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
    
  if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
     (self.traitCollection.horizontalSizeClass != UIUserInterfaceSizeClassCompact)) {

    self.viewControllers = @[self.primaryNavigationController,
                             [[UINavigationController alloc] initWithRootViewController:
                              [[NYPLSettingsAccountDetailViewController alloc] initWithAccount:AccountsManager.shared.currentAccount.id]]];
  } else {
    self.viewControllers = @[self.primaryNavigationController];
  }
  
  self.isFirstLoad = YES;
}

#pragma mark UISplitViewControllerDelegate

- (BOOL)splitViewController:(__attribute__((unused)) UISplitViewController *)splitViewController
collapseSecondaryViewController:(__attribute__((unused)) UIViewController *)secondaryViewController
ontoPrimaryViewController:(__attribute__((unused)) UIViewController *)primaryViewController
{
  if (self.isFirstLoad) {
    self.isFirstLoad = NO;
    return YES;
  } else {
    self.isFirstLoad = NO;
    return NO;
  }
}

- (void)traitCollectionDidChange:(UITraitCollection *)__unused previousTraitCollection
{
  if (self.primaryNavigationController.viewControllers.count >= 1) {
    NYPLSettingsPrimaryTableViewController *tableVC = self.primaryNavigationController.viewControllers[0];
    [tableVC.tableView reloadData];
  }
}

#pragma mark NYPLSettingsAccountsTableViewControllerDelegate

- (void)didSelectWithStaticCell:(enum PrimaryTableViewStaticCellType)staticCell
                         atPath:(NSIndexPath *)__unused path
      fromPrimaryViewController:(NYPLSettingsPrimaryTableViewController *)primaryVC
{
  UIViewController *viewController;
  switch(staticCell) {
    case PrimaryTableViewStaticCellTypeAbout:
      viewController = [[RemoteHTMLViewController alloc]
                        initWithURL:[NSURL URLWithString:NYPLAcknowledgementsURLString]
                        title:NSLocalizedString(@"AboutApp", nil)
                        failureMessage:NSLocalizedString(@"SettingsConnectionFailureMessage", nil)];
      break;
    case PrimaryTableViewStaticCellTypeEula:
      viewController = [[RemoteHTMLViewController alloc]
                        initWithURL:[NSURL URLWithString:NYPLUserAgreementURLString]
                        title:NSLocalizedString(@"EULA", nil)
                        failureMessage:NSLocalizedString(@"SettingsConnectionFailureMessage", nil)];
      break;
    case PrimaryTableViewStaticCellTypeSoftwareLicenses:
      viewController = [[BundledHTMLViewController alloc]
                        initWithFileURL:[[NSBundle mainBundle]
                                         URLForResource:@"software-licenses"
                                         withExtension:@"html"]
                        title:NSLocalizedString(@"SoftwareLicenses", nil)];
      break;
    case PrimaryTableViewStaticCellTypeHelpStack: {
      [[HSHelpStack instance] setThemeFrompList:@"HelpStackTheme"];
      HSHelpStack *helpStack = [HSHelpStack instance];
      helpStack.gear = [APIKeys topLevelHelpStackGear];

      if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
         ([[NYPLRootTabBarController sharedController] traitCollection].horizontalSizeClass != UIUserInterfaceSizeClassCompact)) {
        UIStoryboard* helpStoryboard = [UIStoryboard storyboardWithName:@"HelpStackStoryboard" bundle:[NSBundle mainBundle]];
        UINavigationController *mainNavVC = [helpStoryboard instantiateInitialViewController];
        UIViewController *firstVC = mainNavVC.viewControllers.firstObject;
        firstVC.navigationItem.leftBarButtonItem = nil;
        [self showDetailViewController:mainNavVC sender:self];
      } else {
        [primaryVC.tableView deselectRowAtIndexPath:path animated:YES];
        [[HSHelpStack instance] showHelp:self];
      }
      return;
    }
    case PrimaryTableViewStaticCellTypeCustomFeedUrl:
      //Handled in 
    case PrimaryTableViewStaticCellTypeNewAccount:
      return;
  }
  
  [self showDetailViewController:[[UINavigationController alloc]
                                  initWithRootViewController:viewController]
                          sender:self];
}

- (void)didSelectWithLibrary:(NSInteger)library
                      atPath:(NSIndexPath *)__unused path
   fromPrimaryViewController:(NYPLSettingsAccountsTableViewController *)__unused primaryVC
{
  UIViewController *detailVC = [[NYPLSettingsAccountDetailViewController alloc] initWithAccount:library];
  
  [self showDetailViewController:[[UINavigationController alloc]
                                  initWithRootViewController:detailVC]
                          sender:self];
}

@end
