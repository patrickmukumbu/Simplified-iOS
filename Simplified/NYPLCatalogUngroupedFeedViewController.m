#import "NYPLBook.h"
#import "NYPLBookDetailViewController.h"
#import "NYPLBookNormalCell.h"
#import "NYPLCatalogUngroupedFeed.h"
#import "NYPLCatalogFacet.h"
#import "NYPLCatalogFacetGroup.h"
#import "NYPLCatalogFeedViewController.h"
#import "NYPLCatalogSearchViewController.h"
#import "NYPLConfiguration.h"
#import "NYPLFacetBarView.h"
#import "NYPLFacetView.h"
#import "NYPLOpenSearchDescription.h"
#import "NYPLReloadView.h"
#import "NYPLRemoteViewController.h"
#import "UIView+NYPLViewAdditions.h"
#import "NYPLSettings.h"
#import "SimplyE-Swift.h"
#import "NYPLCatalogUngroupedFeedViewController.h"

#import <PureLayout/PureLayout.h>

static const CGFloat kActivityIndicatorPadding = 20.0;
static const CGFloat kSegmentedControlToolbarHeight = 54.0;
static const CGFloat kCollectionViewCrossfadeDuration = 0.3;

@interface NYPLCatalogUngroupedFeedViewController ()
  <NYPLCatalogUngroupedFeedDelegate, NYPLFacetViewDelegate, NYPLEntryPointControlDelegate,
   UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIViewControllerPreviewingDelegate>

@property (nonatomic) NYPLFacetBarView *facetBarView;
@property (nonatomic) NYPLCatalogUngroupedFeed *feed;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic, weak) NYPLRemoteViewController *remoteViewController;
@property (nonatomic) NYPLOpenSearchDescription *searchDescription;
@property (nonatomic) UIActivityIndicatorView *activityIndicator;
@property (nonatomic) UIVisualEffectView *entryPointBarView;
@property (nonatomic) NYPLFacetViewDefaultDataSource *facetDS;

@end

@implementation NYPLCatalogUngroupedFeedViewController

- (instancetype)initWithUngroupedFeed:(NYPLCatalogUngroupedFeed *const)feed
                 remoteViewController:(NYPLRemoteViewController *const)remoteViewController
{
  self = [super init];
  if(!self) return nil;
  self.feed = feed;
  self.feed.delegate = self;
  self.remoteViewController = remoteViewController;
  
  return self;
}

- (UIEdgeInsets)scrollIndicatorInsets
{
  return UIEdgeInsetsMake(CGRectGetMaxY(self.facetBarView.frame),
                          0,
                          self.parentViewController.bottomLayoutGuide.length,
                          0);
}

- (void)updateActivityIndicator
{
  UIEdgeInsets insets = [self scrollIndicatorInsets];
  if(self.feed.currentlyFetchingNextURL) {
    insets.bottom += kActivityIndicatorPadding + self.activityIndicator.frame.size.height;
    CGRect frame = self.activityIndicator.frame;
    frame.origin = CGPointMake(CGRectGetMidX(self.collectionView.frame) - frame.size.width/2,
                               self.collectionView.contentSize.height + kActivityIndicatorPadding/2);
    self.activityIndicator.frame = frame;
  }
  self.activityIndicator.hidden = !self.feed.currentlyFetchingNextURL;
  self.collectionView.contentInset = insets;
}

#pragma mark UIViewController

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self configureEntryPoints:self.feed.entryPoints];

  self.facetBarView = [[NYPLFacetBarView alloc] initWithOrigin:CGPointZero width:0];
  self.facetDS = [[NYPLFacetViewDefaultDataSource alloc] initWithFacetGroups:self.feed.facetGroups];
  self.facetBarView.facetView.dataSource = self.facetDS;
  self.facetBarView.facetView.delegate = self;

  [self.view addSubview:self.facetBarView];
  [self.facetBarView autoPinEdgeToSuperviewEdge:ALEdgeLeading];
  [self.facetBarView autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
  [self.facetBarView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.entryPointBarView];
  if (self.feed.facetGroups.count > 0) {
    [self.facetBarView autoSetDimension:ALDimensionHeight toSize:40.0];
  } else {
    [self.facetBarView autoSetDimension:ALDimensionHeight toSize:0];
    self.facetBarView.hidden = YES;
  }
  
  self.collectionView.dataSource = self;
  self.collectionView.delegate = self;
  self.collectionView.alpha = 0.0;

  if (@available(iOS 11.0, *)) {
    self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
  }
  self.collectionView.alwaysBounceVertical = YES;
  self.refreshControl = [[UIRefreshControl alloc] init];
  [self.refreshControl addTarget:self action:@selector(userDidRefresh:) forControlEvents:UIControlEventValueChanged];
  [self.collectionView addSubview:self.refreshControl];
  
  if(self.feed.openSearchURL) {
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                              initWithImage:[UIImage imageNamed:@"Search"]
                                              style:UIBarButtonItemStylePlain
                                              target:self
                                              action:@selector(didSelectSearch)];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = NSLocalizedString(@"Search", nil);
    self.navigationItem.rightBarButtonItem.enabled = NO;
    
    [self fetchOpenSearchDescription];
  }
  
  [self.collectionView reloadData];
  [self.facetBarView.facetView reloadData];
  
  self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
  self.activityIndicator.hidden = YES;
  [self.activityIndicator startAnimating];
  [self.collectionView addSubview:self.activityIndicator];
  
  [self enable3DTouch];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [UIView animateWithDuration:kCollectionViewCrossfadeDuration animations:^{
    self.collectionView.alpha = 1.0;
    self.entryPointBarView.alpha = 1.0;
  }];
}

- (void)didMoveToParentViewController:(UIViewController *)parent
{
  [super didMoveToParentViewController:parent];
  
  if(parent) {
    [self updateActivityIndicator];
    self.collectionView.scrollIndicatorInsets = [self scrollIndicatorInsets];
    [self.collectionView setContentOffset:CGPointMake(0, -CGRectGetMaxY(self.facetBarView.frame))
                                 animated:NO];
  }
}

- (void)userDidRefresh:(UIRefreshControl *)refreshControl
{
  if ([[self.navigationController.visibleViewController class] isSubclassOfClass:[NYPLCatalogFeedViewController class]] &&
      [self.navigationController.visibleViewController respondsToSelector:@selector(load)]) {
    [self.remoteViewController load];
  }
  
  [refreshControl endRefreshing];
  [[NSNotificationCenter defaultCenter] postNotificationName:NYPLSyncEndedNotification object:nil];
}

#pragma mark UICollectionViewDataSource

- (NSInteger)collectionView:(__attribute__((unused)) UICollectionView *)collectionView
     numberOfItemsInSection:(__attribute__((unused)) NSInteger)section
{
  return self.feed.books.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  [self.feed prepareForBookIndex:indexPath.row];
  [self updateActivityIndicator];
  
  NYPLBook *const book = self.feed.books[indexPath.row];
  
  return NYPLBookCellDequeue(collectionView, indexPath, book);
}

#pragma mark UICollectionViewDelegate

- (void)collectionView:(__attribute__((unused)) UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *const)indexPath
{
  NYPLBook *const book = self.feed.books[indexPath.row];
  
  [[[NYPLBookDetailViewController alloc] initWithBook:book] presentFromViewController:self];
}

#pragma mark NYPLCatalogUngroupedFeedDelegate

- (void)catalogUngroupedFeed:(__attribute__((unused))
                              NYPLCatalogUngroupedFeed *)catalogUngroupedFeed
              didUpdateBooks:(__attribute__((unused)) NSArray *)books
{
  [self.collectionView reloadData];
}

- (void)catalogUngroupedFeed:(__attribute__((unused))
                              NYPLCatalogUngroupedFeed *)catalogUngroupedFeed
                 didAddBooks:(__attribute__((unused)) NSArray *)books
                       range:(NSRange const)range
{
  NSMutableArray *const indexPaths = [NSMutableArray arrayWithCapacity:range.length];
  
  for(NSUInteger i = 0; i < range.length; ++i) {
    NSUInteger indexes[2] = {0, i + range.location};
    [indexPaths addObject:[NSIndexPath indexPathWithIndexes:indexes length:2]];
  }
  
  // Just reloadData instead of inserting items, to avoid a weird crash (issue #144).
//  [self.collectionView insertItemsAtIndexPaths:indexPaths];
  [self.collectionView reloadData];
}

#pragma mark NYPLFacetViewDelegate

- (void)facetView:(__attribute__((unused)) NYPLFacetView *)facetView
didSelectFacetAtIndexPath:(NSIndexPath *const)indexPath
{
  NYPLCatalogFacetGroup *const group = self.feed.facetGroups[[indexPath indexAtPosition:0]];
  NYPLCatalogFacet *const facet = group.facets[[indexPath indexAtPosition:1]];
  self.remoteViewController.URL = facet.href;
  [self.remoteViewController load];
}

#pragma mark NYPLEntryPointControlDelegate

- (void)configureEntryPoints:(NSArray<NYPLCatalogFacet *> *)facets
{
  UIVisualEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
  self.entryPointBarView = [[UIVisualEffectView alloc] initWithEffect:blur];
  self.entryPointBarView.alpha = 0;
  [self.view addSubview:self.entryPointBarView];
  [self.entryPointBarView autoPinEdgeToSuperviewEdge:ALEdgeLeading];
  [self.entryPointBarView autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
  [self.entryPointBarView autoPinToTopLayoutGuideOfViewController:self withInset:0];

  NYPLEntryPointView *entryPointView = [[NYPLEntryPointView alloc] initWithFacets:facets delegate:self];
  if (entryPointView) {
    [self.entryPointBarView.contentView addSubview:entryPointView];
    [entryPointView autoPinEdgesToSuperviewEdges];
    [self.entryPointBarView autoSetDimension:ALDimensionHeight toSize:kSegmentedControlToolbarHeight];
  } else {
    [self.entryPointBarView autoSetDimension:ALDimensionHeight toSize:0];
  }
}

- (void)didSelectWithEntryPointFacet:(NYPLCatalogFacet *)entryPointFacet
{
  NSURL *const newURL = entryPointFacet.href;
  self.remoteViewController.URL = newURL;
  [self.remoteViewController load];
}

#pragma mark - 3D Touch

-(void)enable3DTouch
{
  if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)] &&
      (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable)) {
    [self registerForPreviewingWithDelegate:self sourceView:self.view];
  }
}

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext
              viewControllerForLocation:(CGPoint)location
{
  CGPoint referencePoint = [self.collectionView convertPoint:location fromView:self.view];
  NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:referencePoint];
  UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
  if (![cell isKindOfClass:[NYPLBookNormalCell class]]) {
    return nil;
  }
  NYPLBookNormalCell *bookCell = (NYPLBookNormalCell *) cell;
  UIViewController *vc = [[UIViewController alloc] init];
  vc.view.tag = indexPath.row;
  UIImageView *imView = [[UIImageView alloc] initWithImage:bookCell.cover.image];
  imView.contentMode = UIViewContentModeScaleAspectFill;
  [vc.view addSubview:imView];
  [imView autoPinEdgesToSuperviewEdges];
  
  vc.preferredContentSize = CGSizeZero;
  previewingContext.sourceRect = [self.view convertRect:cell.frame fromView:[cell superview]];
  
  return vc;
}

- (void)previewingContext:(__unused id<UIViewControllerPreviewing>)previewingContext
     commitViewController:(UIViewController *)viewControllerToCommit
{
  NYPLBook *const book = self.feed.books[viewControllerToCommit.view.tag];
  [[[NYPLBookDetailViewController alloc] initWithBook:book] presentFromViewController:self];
}

#pragma mark -

- (void)didSelectSearch
{
  [self.navigationController
   pushViewController:[[NYPLCatalogSearchViewController alloc]
                       initWithOpenSearchDescription:self.searchDescription]
   animated:YES];
}

- (void)fetchOpenSearchDescription
{
  [NYPLOpenSearchDescription
   withURL:self.feed.openSearchURL
   completionHandler:^(NYPLOpenSearchDescription *const description) {
     [[NSOperationQueue mainQueue] addOperationWithBlock:^{
       self.searchDescription = description;
       self.navigationItem.rightBarButtonItem.enabled = YES;
     }];
   }];
}

@end
