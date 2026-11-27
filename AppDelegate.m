#import "AppDelegate.h"
#import "RootViewController.h"

static void triggerRandomize(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"AutoRandomize" object:nil];
    });
}

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    RootViewController *root = [[RootViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController:root];
    [self.window makeKeyAndVisible];
    
    // API cho AutoTouch: Gửi notify_post("com.outcome.devicechanger.randomize")
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, triggerRandomize, CFSTR("com.outcome.devicechanger.randomize"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    return YES;
}
@end
