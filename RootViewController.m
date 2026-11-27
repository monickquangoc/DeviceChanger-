#import "RootViewController.h"
#import <CoreFoundation/CoreFoundation.h>
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

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
    
    // Lắng nghe lệnh tự động từ Lua (AutoTouch/XXTouch)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(randomizeAction) name:@"AutoRandomize" object:nil];
}

- (void)loadConfig {
    _currentConfig = [NSMutableDictionary dictionaryWithContentsOfFile:_plistPath];
    if (!_currentConfig) {
        _currentConfig = [@{
            @"Enabled": @YES, @"name": @"iPhone 15 Pro Max", @"model": @"iPhone16,2",
            @"version": @"17.5.1", @"idfv": @"A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D",
            @"idfa": @"E5F6G7H8-A1B2-C3D4-E5F6-7A8B9C0D1E2F", @"serial": @"F2LZK1QJQ6L5",
            @"ecid": @"1234567890ABCDEF", @"lat": @21.0285, @"lon": @105.8542,
            @"carrier": @"Viettel", @"battery": @0.85, @"batteryState": @2
        } mutableCopy];
    }
}

- (void)runShell:(NSString *)cmd {
    // Hỗ trợ cả Rootless (palera1n) và Rootful
    NSString *sh = [[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/usr/bin/sh"] ? @"/var/jb/usr/bin/sh" : @"/bin/sh";
    pid_t pid;
    const char *args[] = {[sh UTF8String], "-c", [cmd UTF8String], NULL};
    posix_spawn(&pid, [sh UTF8String], NULL, NULL, (char * const *)args, environ);
}

- (void)respring {
    [_currentConfig writeToFile:_plistPath atomically:YES];
    [self runShell:@"killall -9 SpringBoard"];
}

- (NSString *)generateRandomSerial {
    NSString *letters = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:12];
    for (int i = 0; i < 12; i++) [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)[letters length])]];
    return randomString;
}

- (void)randomizeAction {
    _currentConfig[@"idfv"] = [[NSUUID UUID] UUIDString];
    _currentConfig[@"idfa"] = [[NSUUID UUID] UUIDString];
    _currentConfig[@"serial"] = [self generateRandomSerial];
    _currentConfig[@"ecid"] = [NSString stringWithFormat:@"%llX", (unsigned long long)arc4random()];
    _currentConfig[@"model"] = @[@"iPhone15,4", @"iPhone15,5", @"iPhone16,1", @"iPhone16,2"][arc4random_uniform(4)];
    _currentConfig[@"name"] = @[@"iPhone 14", @"iPhone 14 Pro", @"iPhone 15 Pro", @"iPhone 15 Pro Max"][arc4random_uniform(4)];
    _currentConfig[@"version"] = @[@"16.7.1", @"17.2.1", @"17.5.1"][arc4random_uniform(3)];
    _currentConfig[@"lat"] = @(8.18 + ((double)arc4random() / UINT32_MAX) * (23.39 - 8.18));
    _currentConfig[@"lon"] = @(102.14 + ((double)arc4random() / UINT32_MAX) * (109.46 - 102.14));
    _currentConfig[@"battery"] = @(0.1 + ((double)arc4random() / UINT32_MAX) * 0.8);
    
    [_currentConfig writeToFile:_plistPath atomically:YES];
    dispatch_async(dispatch_get_main_queue(), ^{ [self.tableView reloadData]; });
}

- (void)wipeData {
    // Xóa sạch mọi dấu vết của Shopee và các app khác
    NSString *cmd = @"for dir in /var/mobile/Containers/Data/Application/*/; do \
        if grep -q -E 'com.bee.ios|com.shopee.vn' \"$dir/.com.apple.mobile_container_manager.metadata.plist\" 2>/dev/null; then \
            rm -rf \"$dir/Library/Caches/\"*; \
            rm -rf \"$dir/Library/Preferences/\"*; \
            rm -rf \"$dir/Documents/\"*; \
        fi; done";
    [self runShell:cmd];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Wipe" message:@"Đã xóa sạch dữ liệu!" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Table View
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return 4; // Random, Wipe, Backup, Respring
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
        if (indexPath.row == 1) { cell.textLabel.text = @"RESET / WIPE Dữ Liệu"; cell.textLabel.textColor = [UIColor systemRedColor]; }
        if (indexPath.row == 2) { cell.textLabel.text = @"BACKUP Dữ Liệu"; cell.textLabel.textColor = [UIColor systemOrangeColor]; }
        if (indexPath.row == 3) { cell.textLabel.text = @"Lưu & Respring"; cell.textLabel.textColor = [UIColor systemGreenColor]; }
    }
    else {
        if (indexPath.row == 0) { cell.textLabel.text = @"Thiết bị:"; cell.detailTextLabel.text = _currentConfig[@"name"]; }
        if (indexPath.row == 1) { cell.textLabel.text = @"Serial:"; cell.detailTextLabel.text = _currentConfig[@"serial"]; }
    }
    return cell;
}
- (void)switchChanged:(UISwitch *)sender { _currentConfig[@"Enabled"] = @(sender.isOn); }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        if (indexPath.row == 0) [self randomizeAction];
        if (indexPath.row == 1) [self wipeData];
        if (indexPath.row == 2) [self runShell:@"tar -czf /var/mobile/Documents/backup.tar.gz /var/mobile/Containers/Data/Application/*"];
        if (indexPath.row == 3) [self respring];
    }
}
@end
