#import "NYPLConfiguration.h"

@implementation NYPLConfiguration

+ (void)initialize
{
  [[UINavigationBar appearance]
   setTitleTextAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:17]}];
}

+ (NSURL *)mainFeedURL
{
  return [NSURL URLWithString:@"http://library-simplified.herokuapp.com"];
}

+ (NSURL *)loanURL
{
  return [NSURL URLWithString:@"http://library-simplified.herokuapp.com/loans"];
}

+ (UIColor *)mainColor
{
  return [UIColor colorWithRed:240/255.0 green:115/255.0 blue:31/255.0 alpha:1.0];
}

+ (UIColor *)accentColor
{
  return [UIColor colorWithRed:0.0/255.0 green:144/255.0 blue:196/255.0 alpha:1.0];
}

+ (UIColor *)backgroundColor
{
  return [UIColor colorWithWhite:250/255.0 alpha:1.0];
}

+ (UIColor *)backgroundDarkColor
{
  return [UIColor colorWithWhite:5/255.0 alpha:1.0];
}

+ (UIColor *)backgroundSepiaColor
{
  return [UIColor colorWithRed:255/255.0 green:245/255.0 blue:210/255.0 alpha:1.0];
}

+ (NSString *)systemFontName
{
  return @"AvenirNext-Medium";
}

+ (NSString *)boldSystemFontName
{
  return @"AvenirNext-Bold";
}

@end
