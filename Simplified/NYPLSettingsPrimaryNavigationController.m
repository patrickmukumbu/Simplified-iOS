#import "NYPLSettingsPrimaryNavigationController.h"
#import "NYPLSettings.h"
#import "SimplyE-Swift.h"

@interface NYPLSettingsPrimaryNavigationController ()

@property (nonatomic) NYPLSettingsAccountsTableViewController *tableViewController;

@end

@implementation NYPLSettingsPrimaryNavigationController

#pragma mark NSObject

- (instancetype)initWithDelegate:(id)delegate
{
  NSArray *accounts = [[NYPLSettings sharedSettings] settingsAccountsList];
  NYPLSettingsPrimaryTableViewController *const tableViewController =
    [[NYPLSettingsPrimaryTableViewController alloc] initWithAccounts:accounts];
  
  tableViewController.delegate = delegate;
  
  self = [super initWithRootViewController:tableViewController];
  if(!self) return nil;
  
  return self;
}

@end
