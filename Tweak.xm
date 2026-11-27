#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/AdSupport.h>
#import <substrate.h>
#import <dlfcn.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <IOKit/IOKitLib.h>

// --- 1. KHAI BÁO HÀM GỐC ---
typedef CFTypeRef (*MGCopyAnswerFunc)(CFStringRef);
static MGCopyAnswerFunc orig_MGCopyAnswer = NULL;

typedef CFTypeRef (*IORegistryEntryCreateCFPropertyFunc)(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options);
static IORegistryEntryCreateCFPropertyFunc orig_IORegistryEntryCreateCFProperty = NULL;

static NSDictionary* getCfg() {
    return [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
}

// --- 2. HÀM FAKE MOBILEGESTALT (Settings) ---
static CFTypeRef new_MGCopyAnswer(CFStringRef prop) {
    NSDictionary *cfg = getCfg();
    if (cfg[@"Enabled"]) {
        if (CFEqual(prop, CFSTR("ProductType"))) return (__bridge_retained CFTypeRef)cfg[@"model"];
        if (CFEqual(prop, CFSTR("UserAssignedDeviceName"))) return (__bridge_retained CFTypeRef)cfg[@"name"];
        if (CFEqual(prop, CFSTR("ProductVersion"))) return (__bridge_retained CFTypeRef)cfg[@"version"];
        if (CFEqual(prop, CFSTR("SerialNumber"))) return (__bridge_retained CFTypeRef)cfg[@"serial"];
        if (CFEqual(prop, CFSTR("UniqueDeviceID"))) return (__bridge_retained CFTypeRef)cfg[@"idfv"];
    }
    if (orig_MGCopyAnswer) return orig_MGCopyAnswer(prop);
    return NULL;
}

// --- 3. HÀM FAKE IOKIT (Dành cho AIDA64, 3uTools) ---
static CFTypeRef new_IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    NSDictionary *cfg = getCfg();
    if (cfg[@"Enabled"]) {
        if (CFEqual(key, CFSTR("IOPlatformSerialNumber"))) return (__bridge_retained CFTypeRef)cfg[@"serial"];
        if (CFEqual(key, CFSTR("IOPlatformUUID"))) return (__bridge_retained CFTypeRef)cfg[@"idfv"];
        if (CFEqual(key, CFSTR("target-type"))) return (__bridge_retained CFTypeRef)cfg[@"model"];
        if (CFEqual(key, CFSTR("USBProductName"))) return (__bridge_retained CFTypeRef)cfg[@"name"];
    }
    if (orig_IORegistryEntryCreateCFProperty) {
        return orig_IORegistryEntryCreateCFProperty(entry, key, allocator, options);
    }
    return NULL;
}

// --- 4. HOOK CÁC HÀM CƠ BẢN ---
%hookf(int, uname, struct utsname *buf) {
    int ret = %orig;
    NSDictionary *cfg = getCfg();
    if (cfg[@"Enabled"] && buf) {
        strncpy(buf->machine, [cfg[@"model"] UTF8String], sizeof(buf->machine)-1);
        strncpy(buf->release, [cfg[@"version"] UTF8String], sizeof(buf->release)-1);
    }
    return ret;
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    NSDictionary *cfg = getCfg();
    if (cfg[@"Enabled"] && oldp) {
        if (strcmp(name, "hw.model") == 0 || strcmp(name, "hw.machine") == 0) {
            const char *val = [cfg[@"model"] UTF8String];
            // SỬA LỖI TẠI ĐÂY: Thêm (char *) vào trước oldp
            if (oldlenp && *oldlenp >= strlen(val) + 1) { strcpy((char *)oldp, val); return 0; }
        }
        if (strcmp(name, "kern.osversion") == 0) {
            const char *val = [cfg[@"version"] UTF8String];
            // SỬA LỖI TẠI ĐÂY: Thêm (char *) vào trước oldp
            if (oldlenp && *oldlenp >= strlen(val) + 1) { strcpy((char *)oldp, val); return 0; }
        }
    }
    return %orig;
}

%hook UIDevice
- (NSString *)name {
    NSDictionary *cfg = getCfg();
    if (cfg[@"Enabled"] && cfg[@"name"]) return cfg[@"name"];
    return %orig;
}
- (NSUUID *)identifierForVendor {
    NSDictionary *cfg = getCfg();
    if (cfg[@"Enabled"] && cfg[@"idfv"]) return [[NSUUID alloc] initWithUUIDString:cfg[@"idfv"]];
    return %orig;
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    NSDictionary *cfg = getCfg();
    if (cfg[@"Enabled"] && cfg[@"idfa"]) return [[NSUUID alloc] initWithUUIDString:cfg[@"idfa"]];
    return %orig;
}
%end

%hook CLLocationManager
- (CLLocation *)location {
    NSDictionary *cfg = getCfg();
    if (cfg[@"Enabled"] && cfg[@"lat"] && cfg[@"lon"]) {
        return [[CLLocation alloc] initWithLatitude:[cfg[@"lat"] doubleValue] longitude:[cfg[@"lon"] doubleValue]];
    }
    return %orig;
}
- (void)startUpdatingLocation {
    %orig;
    NSDictionary *cfg = getCfg();
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

// --- 5. KHỞI TẠO VÀ RESPRING ---
static void respringCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    sleep(1);
    exit(0);
}

%ctor {
    MSHookFunction((void *)dlsym(RTLD_DEFAULT, "MGCopyAnswer"), (void *)new_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
    MSHookFunction((void *)dlsym(RTLD_DEFAULT, "IORegistryEntryCreateCFProperty"), (void *)new_IORegistryEntryCreateCFProperty, (void **)&orig_IORegistryEntryCreateCFProperty);
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, respringCallback, CFSTR("com.outcome.devicechanger.respring"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
