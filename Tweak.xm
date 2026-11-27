#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/AdSupport.h>

static NSDictionary *getConfig() {
    return [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
}

// 1. Hook Thông tin thiết bị
%hook UIDevice
- (NSString *)name {
    NSDictionary *cfg = getConfig();
    if (cfg[@"Enabled"] && cfg[@"name"]) return cfg[@"name"];
    return %orig;
}
- (NSString *)model {
    NSDictionary *cfg = getConfig();
    if (cfg[@"Enabled"] && cfg[@"model"]) return cfg[@"model"];
    return %orig;
}
- (NSString *)systemVersion {
    NSDictionary *cfg = getConfig();
    if (cfg[@"Enabled"] && cfg[@"version"]) return cfg[@"version"];
    return %orig;
}
- (NSUUID *)identifierForVendor {
    NSDictionary *cfg = getConfig();
    if (cfg[@"Enabled"] && cfg[@"idfv"]) return [[NSUUID alloc] initWithUUIDString:cfg[@"idfv"]];
    return %orig;
}
%end

// 2. Hook IDFA
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    NSDictionary *cfg = getConfig();
    if (cfg[@"Enabled"] && cfg[@"idfa"]) return [[NSUUID alloc] initWithUUIDString:cfg[@"idfa"]];
    return %orig;
}
%end

// 3. Hook Định vị
%hook CLLocationManager
- (CLLocation *)location {
    NSDictionary *cfg = getConfig();
    if (cfg[@"Enabled"] && cfg[@"lat"] && cfg[@"lon"]) {
        return [[CLLocation alloc] initWithLatitude:[cfg[@"lat"] doubleValue] longitude:[cfg[@"lon"] doubleValue]];
    }
    return %orig;
}
- (void)startUpdatingLocation {
    %orig;
    NSDictionary *cfg = getConfig();
    if (cfg[@"Enabled"] && cfg[@"lat"] && cfg[@"lon"]) {
        CLLocation *fakeLoc = [[CLLocation alloc] initWithLatitude:[cfg[@"lat"] doubleValue] longitude:[cfg[@"lon"] doubleValue]];
        if (self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [self.delegate locationManager:self didUpdateLocations:@[fakeLoc]];
        }
    }
}
%end

// 4. Bypass Jailbreak (Ẩn dấu vết với Shopee)
%hook NSFileManager
- (BOOL)fileExistsAtPath:(NSString *)path {
    NSArray *jbPaths = @[@"/Applications/Cydia.app", @"/var/jb", @"/usr/sbin/sshd", @"/.installed_dopamine", @"/private/var/lib/dpkg"];
    for (NSString *p in jbPaths) {
        if ([path hasPrefix:p]) return NO;
    }
    return %orig;
}
%end

// 5. Ẩn biến môi trường Inject
%hook NSProcessInfo
- (NSDictionary *)environment {
    NSMutableDictionary *env = [%orig mutableCopy];
    [env removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
    return env;
}
%end
