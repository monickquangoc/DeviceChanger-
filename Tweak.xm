#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/AdSupport.h>
#import <substrate.h>
#import <dlfcn.h> // THÊM DÒNG NÀY ĐỂ FIX LỖI RTLD_DEFAULT

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

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
    if (cfg[@"Enabled"] && cfg[@"idfa"]) return [[NSUUID alloc] initWithUUIDString:cfg[@"idfa"]];
    return %orig;
}
%end

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

%hook NSFileManager
- (BOOL)fileExistsAtPath:(NSString *)path {
    NSArray *jbPaths = @[@"/Applications/Cydia.app", @"/var/jb", @"/usr/sbin/sshd", @"/.installed_dopamine", @"/private/var/lib/dpkg"];
    for (NSString *p in jbPaths) {
        if ([path hasPrefix:p]) return NO;
    }
    return %orig;
}
%end

static void respringCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    sleep(1);
    exit(0);
}

%ctor {
    MSHookFunction((void *)dlsym(RTLD_DEFAULT, "MGCopyAnswer"), (void *)new_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, respringCallback, CFSTR("com.outcome.devicechanger.respring"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
