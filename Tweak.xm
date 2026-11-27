#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/AdSupport.h>
#import <substrate.h>

// Dùng con trỏ hàm để gọi MGCopyAnswer mà không cần link thư viện
typedef CFTypeRef (*MGCopyAnswerFunc)(CFStringRef);
static MGCopyAnswerFunc orig_MGCopyAnswer = NULL;

static CFTypeRef new_MGCopyAnswer(CFStringRef prop) {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
    if (cfg[@"Enabled"]) {
        if (CFEqual(prop, CFSTR("ProductType"))) {
            return (__bridge_retained CFTypeRef)cfg[@"model"];
        }
        if (CFEqual(prop, CFSTR("UserAssignedDeviceName"))) {
            return (__bridge_retained CFTypeRef)cfg[@"name"];
        }
    }
    if (orig_MGCopyAnswer) return orig_MGCopyAnswer(prop);
    return NULL;
}

// 1. Hook UIDevice (Cho các app khác đọc)
%hook UIDevice
- (NSString *)name {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
    if (cfg[@"Enabled"] && cfg[@"name"]) return cfg[@"name"];
    return %orig;
}
- (NSString *)model {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
    if (cfg[@"Enabled"] && cfg[@"model"]) return cfg[@"model"];
    return %orig;
}
- (NSString *)systemVersion {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
    if (cfg[@"Enabled"] && cfg[@"version"]) return cfg[@"version"];
    return %orig;
}
- (NSUUID *)identifierForVendor {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
    if (cfg[@"Enabled"] && cfg[@"idfv"]) return [[NSUUID alloc] initWithUUIDString:cfg[@"idfv"]];
    return %orig;
}
%end

// 2. Hook IDFA
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
    if (cfg[@"Enabled"] && cfg[@"idfa"]) return [[NSUUID alloc] initWithUUIDString:cfg[@"idfa"]];
    return %orig;
}
%end

// 3. Hook Định vị
%hook CLLocationManager
- (CLLocation *)location {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
    if (cfg[@"Enabled"] && cfg[@"lat"] && cfg[@"lon"]) {
        return [[CLLocation alloc] initWithLatitude:[cfg[@"lat"] doubleValue] longitude:[cfg[@"lon"] doubleValue]];
    }
    return %orig;
}
- (void)startUpdatingLocation {
    %orig;
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
    if (cfg[@"Enabled"] && cfg[@"lat"] && cfg[@"lon"]) {
        CLLocation *fakeLoc = [[CLLocation alloc] initWithLatitude:[cfg[@"lat"] doubleValue] longitude:[cfg[@"lon"] doubleValue]];
        if (self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [self.delegate locationManager:self didUpdateLocations:@[fakeLoc]];
        }
    }
}
%end

// 4. Bypass Jailbreak
%hook NSFileManager
- (BOOL)fileExistsAtPath:(NSString *)path {
    NSArray *jbPaths = @[@"/Applications/Cydia.app", @"/var/jb", @"/usr/sbin/sshd", @"/.installed_dopamine", @"/private/var/lib/dpkg"];
    for (NSString *p in jbPaths) {
        if ([path hasPrefix:p]) return NO;
    }
    return %orig;
}
%end

// 5. Lắng nghe tín hiệu từ App để tự Respring
static void respringCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    sleep(1);
    exit(0);
}

// Khởi tạo Hook động và lắng nghe tín hiệu
%ctor {
    MSHookFunction((void *)dlsym(RTLD_DEFAULT, "MGCopyAnswer"), (void *)new_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, respringCallback, CFSTR("com.outcome.devicechanger.respring"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
