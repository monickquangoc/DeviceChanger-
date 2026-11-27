#import "AppDelegate.h"
#import "RootViewController.h"
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    RootViewController *root = [[RootViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    nav.navigationBar.prefersLargeTitles = YES;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}
@end
