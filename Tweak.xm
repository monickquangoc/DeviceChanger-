#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/AdSupport.h>

// Thêm extern "C" để sửa lỗi Undefined symbols (Name Mangling)
extern "C" CFTypeRef MGCopyAnswer(CFStringRef property);

static NSDictionary *getConfig() {
    return [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
}

// 1. Hook MobileGestalt (Để Settings -> About thay đổi)
%hookf(CFTypeRef, MGCopyAnswer, CFStringRef prop) {
    NSDictionary *cfg = getConfig();
    if (cfg[@"Enabled"]) {
        if (CFEqual(prop, CFSTR("ProductType"))) {
            return (__bridge_retained CFTypeRef)cfg[@"model"];
        }
        if (CFEqual(prop, CFSTR("UserAssignedDeviceName"))) {
            return (__bridge_retained CFTypeRef)cfg[@"name"];
        }
    }
    return %orig;
}

// 2. Hook UIDevice (Cho các app khác đọc)
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

// 3. Hook IDFA
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    NSDictionary *cfg = getConfig();
    if (cfg[@"Enabled"] && cfg[@"idfa"]) return [[NSUUID alloc] initWithUUIDString:cfg[@"idfa"]];
    return %orig;
}
%end

// 4. Hook Định vị (Fake Location)
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

// 5. Bypass Jailbreak
%hook NSFileManager
- (BOOL)fileExistsAtPath:(NSString *)path {
    NSArray *jbPaths = @[@"/Applications/Cydia.app", @"/var/jb", @"/usr/sbin/sshd", @"/.installed_dopamine", @"/private/var/lib/dpkg"];
    for (NSString *p in jbPaths) {
        if ([path hasPrefix:p]) return NO;
    }
    return %orig;
}
%end

// 6. Lắng nghe tín hiệu từ App để tự Respring (Vì App không có quyền killall)
static void respringCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    sleep(1);
    exit(0);
}
%ctor {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, respringCallback, CFSTR("com.outcome.devicechanger.respring"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
