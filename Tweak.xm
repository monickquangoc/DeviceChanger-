#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/AdSupport.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <substrate.h>
#import <dlfcn.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <IOKit/IOKitLib.h>

static NSString* currentBundleId() {
    return [[NSBundle mainBundle] bundleIdentifier] ?: @"com.apple.springboard";
}

static NSDictionary* getCfg() {
    return [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist"];
}

static id getValue(NSString *key) {
    NSDictionary *cfg = getCfg();
    if (!cfg[@"Enabled"]) return nil;
    NSDictionary *appCfg = cfg[@"PerApp"][currentBundleId()];
    if (appCfg && appCfg[key]) return appCfg[key];
    return cfg[key];
}

// 1. IOKit Spoofer (ECID, Serial, MLB)
typedef CFTypeRef (*IORegistryEntryCreateCFPropertyFunc)(io_registry_entry_t, CFStringRef, CFAllocatorRef, IOOptionBits);
static IORegistryEntryCreateCFPropertyFunc orig_IORegistry = NULL;
static CFTypeRef new_IORegistry(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options) {
    if (CFEqual(key, CFSTR("IOPlatformSerialNumber"))) return (__bridge_retained CFTypeRef)getValue(@"serial");
    if (CFEqual(key, CFSTR("IOPlatformUUID"))) return (__bridge_retained CFTypeRef)getValue(@"uuid");
    if (CFEqual(key, CFSTR("target-type"))) return (__bridge_retained CFTypeRef)getValue(@"model");
    if (CFEqual(key, CFSTR("IOPlatformECID"))) return (__bridge_retained CFTypeRef)getValue(@"ecid");
    if (orig_IORegistry) return orig_IORegistry(entry, key, allocator, options);
    return NULL;
}

// 2. MobileGestalt (Settings)
typedef CFTypeRef (*MGCopyAnswerFunc)(CFStringRef);
static MGCopyAnswerFunc orig_MGCopyAnswer = NULL;
static CFTypeRef new_MGCopyAnswer(CFStringRef prop) {
    if (CFEqual(prop, CFSTR("ProductType"))) return (__bridge_retained CFTypeRef)getValue(@"model");
    if (CFEqual(prop, CFSTR("ProductVersion"))) return (__bridge_retained CFTypeRef)getValue(@"version");
    if (CFEqual(prop, CFSTR("SerialNumber"))) return (__bridge_retained CFTypeRef)getValue(@"serial");
    if (orig_MGCopyAnswer) return orig_MGCopyAnswer(prop);
    return NULL;
}

// 3. Sysctl & Uname
%hookf(int, uname, struct utsname *buf) {
    int ret = %orig;
    NSString *model = getValue(@"model");
    if (model && buf) strncpy(buf->machine, [model UTF8String], sizeof(buf->machine)-1);
    return ret;
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (oldp) {
        if (strcmp(name, "hw.machine") == 0) {
            NSString *m = getValue(@"model");
            if (m) { const char *val = [m UTF8String]; if (oldlenp && *oldlenp >= strlen(val)+1) { strcpy((char *)oldp, val); return 0; } }
        }
    }
    return %orig;
}

// 4. UIDevice, Battery, IDFV
%hook UIDevice
- (NSString *)name { NSString *val = getValue(@"name"); return val ?: %orig; }
- (NSString *)systemVersion { NSString *val = getValue(@"version"); return val ?: %orig; }
- (NSUUID *)identifierForVendor { NSString *val = getValue(@"idfv"); return val ? [[NSUUID alloc] initWithUUIDString:val] : %orig; }
- (float)batteryLevel { NSNumber *val = getValue(@"battery"); return val ? [val floatValue] : %orig; }

// SỬA LỖI TẠI ĐÂY: Thêm ép kiểu (UIDeviceBatteryState)
- (UIDeviceBatteryState)batteryState { 
    NSNumber *val = getValue(@"batteryState"); 
    return val ? (UIDeviceBatteryState)[val integerValue] : %orig; 
}
%end

// 5. IDFA
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier { NSString *val = getValue(@"idfa"); return val ? [[NSUUID alloc] initWithUUIDString:val] : %orig; }
%end

// 6. Location
%hook CLLocationManager
- (CLLocation *)location {
    NSNumber *lat = getValue(@"lat"), *lon = getValue(@"lon");
    if (lat && lon) return [[CLLocation alloc] initWithLatitude:[lat doubleValue] longitude:[lon doubleValue]];
    return %orig;
}
%end

// 7. Carrier (Nhà mạng)
%hook CTCarrier
- (NSString *)carrierName { NSString *val = getValue(@"carrier"); return val ?: %orig; }
%end

%ctor {
    MSHookFunction((void *)dlsym(RTLD_DEFAULT, "IORegistryEntryCreateCFProperty"), (void *)new_IORegistry, (void **)&orig_IORegistry);
    MSHookFunction((void *)dlsym(RTLD_DEFAULT, "MGCopyAnswer"), (void *)new_MGCopyAnswer, (void **)&orig_MGCopyAnswer);
}
