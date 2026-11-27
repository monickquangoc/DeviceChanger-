#import "RootViewController.h"
#import <CoreFoundation/CoreFoundation.h>

@implementation RootViewController {
    UISwitch *_enableSwitch;
    NSMutableDictionary *_currentConfig;
    NSString *_plistPath;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Device Changer Pro";
    _plistPath = @"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist";
    [self loadConfig];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStyleDone target:self action:@selector(respring)];
}

- (void)loadConfig {
    _currentConfig = [NSMutableDictionary dictionaryWithContentsOfFile:_plistPath];
    if (!_currentConfig) {
        _currentConfig = [@{
            @"Enabled": @YES,
            @"name": @"iPhone 15 Pro Max",
            @"model": @"iPhone16,2",
            @"version": @"17.5.1",
            @"idfv": @"A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D",
            @"idfa": @"E5F6G7H8-A1B2-C3D4-E5F6-7A8B9C0D1E2F",
            @"lat": @21.0285,
            @"lon": @105.8542
        } mutableCopy];
    }
}

- (void)respring {
    [_currentConfig writeToFile:_plistPath atomically:YES];
    // Gửi tín hiệu cho Tweak trong SpringBoard để nó tự khởi động lại
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.outcome.devicechanger.respring"), NULL, NULL, YES);
}

- (void)randomizeAction {
    NSString *newUUID1 = [[NSUUID UUID] UUIDString];
    NSString *newUUID2 = [[NSUUID UUID] UUIDString];
    
    NSArray *models = @[@"iPhone15,4", @"iPhone15,5", @"iPhone16,1", @"iPhone16,2"];
    NSArray *names = @[@"iPhone 14", @"iPhone 14 Pro", @"iPhone 15 Pro", @"iPhone 15 Pro Max"];
    NSArray *versions = @[@"16.7.1", @"17.2.1", @"17.5.1"];
    
    int idx = arc4random_uniform((uint32_t)models.count);
    double randomLat = 8.18 + ((double)arc4random() / UINT32_MAX) * (23.39 - 8.18);
    double randomLon = 102.14 + ((double)arc4random() / UINT32_MAX) * (109.46 - 102.14);
    
    _currentConfig[@"idfv"] = newUUID1;
    _currentConfig[@"idfa"] = newUUID2;
    _currentConfig[@"model"] = models[idx];
    _currentConfig[@"name"] = names[idx];
    _currentConfig[@"version"] = versions[arc4random_uniform((uint32_t)versions.count)];
    _currentConfig[@"lat"] = @(randomLat);
    _currentConfig[@"lon"] = @(randomLon);
    
    [self.tableView reloadData];
}

- (void)clearShopeeCache {
    NSString *containersPath = @"/var/mobile/Containers/Data/Application/";
    NSArray *folders = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:containersPath error:nil];
    BOOL found = NO;
    
    for (NSString *folder in folders) {
        NSString *path = [containersPath stringByAppendingPathComponent:folder];
        NSString *metaPlist = [path stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:metaPlist]) {
            NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPlist];
            NSString *bundleId = meta[@"MCMMetadataIdentifier"];
            
            if ([bundleId isEqualToString:@"com.bee.ios"] || [bundleId isEqualToString:@"com.shopee.vn"]) {
                NSString *cachePath = [path stringByAppendingPathComponent:@"Library/Caches"];
                NSString *prefsPath = [path stringByAppendingPathComponent:@"Library/Preferences"];
                
                [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:prefsPath error:nil];
                found = YES;
                break;
            }
        }
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Shopee Cache" message:(found ? @"Đã xóa sạch dữ liệu!" : @"Không tìm thấy app Shopee!") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Table View
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return 3;
    return 2;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Trạng thái";
    if (section == 1) return @"Hành động";
    return @"Dữ liệu Fake";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    
    if (indexPath.section == 0) {
        cell.textLabel.text = @"Bật Fake Info & Location";
        _enableSwitch = [[UISwitch alloc] init];
        _enableSwitch.on = [_currentConfig[@"Enabled"] boolValue];
        [_enableSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = _enableSwitch;
    } 
    else if (indexPath.section == 1) {
        if (indexPath.row == 0) { cell.textLabel.text = @"Random All (1-Click)"; cell.textLabel.textColor = [UIColor systemBlueColor]; }
        if (indexPath.row == 1) { cell.textLabel.text = @"Xóa Cache Shopee"; cell.textLabel.textColor = [UIColor systemRedColor]; }
        if (indexPath.row == 2) { cell.textLabel.text = @"Lưu & Respring"; cell.textLabel.textColor = [UIColor systemGreenColor]; }
    }
    else {
        if (indexPath.row == 0) { cell.textLabel.text = @"Thiết bị:"; cell.detailTextLabel.text = _currentConfig[@"name"]; }
        if (indexPath.row == 1) { cell.textLabel.text = @"Tọa độ:"; cell.detailTextLabel.text = [NSString stringWithFormat:@"%@, %@", _currentConfig[@"lat"], _currentConfig[@"lon"]]; }
    }
    return cell;
}
- (void)switchChanged:(UISwitch *)sender { _currentConfig[@"Enabled"] = @(sender.isOn); }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        if (indexPath.row == 0) [self randomizeAction];
        if (indexPath.row == 1) [self clearShopeeCache];
        if (indexPath.row == 2) [self respring];
    }
}
@end
