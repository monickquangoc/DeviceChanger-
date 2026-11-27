#import "RootViewController.h"
#import <CoreFoundation/CoreFoundation.h>
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

@implementation RootViewController {
    UISwitch *_enableSwitch;
    NSMutableDictionary *_currentConfig;
}

- (NSUserDefaults *)sharedDefaults {
    return [[NSUserDefaults alloc] initWithSuiteName:@"com.outcome.devicechangerpro"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Device Changer Pro";
    [self loadConfig];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStyleDone target:self action:@selector(respring)];
}

- (void)loadConfig {
    NSUserDefaults *defaults = [self sharedDefaults];
    if (![defaults objectForKey:@"name"]) {
        [defaults setBool:YES forKey:@"Enabled"];
        [defaults setObject:@"iPhone 15 Pro Max" forKey:@"name"];
        [defaults setObject:@"iPhone16,2" forKey:@"model"];
        [defaults setObject:@"17.5.1" forKey:@"version"];
        [defaults setObject:@"F2LZK1QJQ6L5" forKey:@"serial"];
        [defaults setObject:@"A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D" forKey:@"idfv"];
        [defaults setObject:@"E5F6G7H8-A1B2-C3D4-E5F6-7A8B9C0D1E2F" forKey:@"idfa"];
        [defaults setDouble:21.0285 forKey:@"lat"];
        [defaults setDouble:105.8542 forKey:@"lon"];
        [defaults synchronize];
    }
    _currentConfig = [[defaults dictionaryRepresentation] mutableCopy];
}

- (void)runShell:(NSString *)cmd {
    NSString *sh = @"/var/jb/usr/bin/sh"; 
    pid_t pid;
    const char *args[] = {[sh UTF8String], "-c", [cmd UTF8String], NULL};
    posix_spawn(&pid, [sh UTF8String], NULL, NULL, (char * const *)args, environ);
}

- (void)respring {
    [_currentConfig writeToFile:@"/var/mobile/Library/Preferences/com.outcome.devicechangerpro.plist" atomically:YES];
    // Xóa lệnh system(), chỉ dùng tín hiệu Tweak
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.outcome.devicechanger.respring"), NULL, NULL, YES);
}

- (NSString *)generateRandomSerial {
    NSString *letters = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:12];
    for (int i = 0; i < 12; i++) {
        [randomString appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)[letters length])]];
    }
    return randomString;
}

- (void)randomizeAction {
    NSUserDefaults *defaults = [self sharedDefaults];
    
    [defaults setObject:[[NSUUID UUID] UUIDString] forKey:@"idfv"];
    [defaults setObject:[[NSUUID UUID] UUIDString] forKey:@"idfa"];
    [defaults setObject:[self generateRandomSerial] forKey:@"serial"];
    [defaults setObject:@[@"iPhone15,4", @"iPhone15,5", @"iPhone16,1", @"iPhone16,2"][arc4random_uniform(4)] forKey:@"model"];
    [defaults setObject:@[@"iPhone 14", @"iPhone 14 Pro", @"iPhone 15 Pro", @"iPhone 15 Pro Max"][arc4random_uniform(4)] forKey:@"name"];
    [defaults setObject:@[@"16.7.1", @"17.2.1", @"17.5.1"][arc4random_uniform(3)] forKey:@"version"];
    [defaults setDouble:(8.18 + ((double)arc4random() / UINT32_MAX) * (23.39 - 8.18)) forKey:@"lat"];
    [defaults setDouble:(102.14 + ((double)arc4random() / UINT32_MAX) * (109.46 - 102.14)) forKey:@"lon"];
    [defaults setObject:@"Viettel" forKey:@"carrier"];
    
    [defaults synchronize];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thành công" message:@"Đã Random thông số mới!\nBấm 'Lưu & Respring' để áp dụng." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    
    [self loadConfig];
    dispatch_async(dispatch_get_main_queue(), ^{ [self.tableView reloadData]; });
}

// Thêm lại hàm wipeData bị thiếu
- (void)wipeData {
    NSString *cmd = @"for dir in /var/mobile/Containers/Data/Application/*/; do "
                     "if grep -q -E 'com.bee.ios|com.shopee.vn' \"$dir/.com.apple.mobile_container_manager.metadata.plist\" 2>/dev/null; then "
                     "rm -rf \"$dir/Library/Caches/\"*; "
                     "rm -rf \"$dir/Library/Preferences/\"*; "
                     "rm -rf \"$dir/Documents/\"*; "
                     "fi; done";
    [self runShell:cmd];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Wipe" message:@"Đã xóa sạch dữ liệu!" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Table View
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 3;
    return 3;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Hành động";
    return @"Dữ liệu Fake";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) { cell.textLabel.text = @"Random All (1-Click)"; cell.textLabel.textColor = [UIColor systemBlueColor]; }
        if (indexPath.row == 1) { cell.textLabel.text = @"Wipe Dữ Liệu Shopee"; cell.textLabel.textColor = [UIColor systemRedColor]; }
        if (indexPath.row == 2) { cell.textLabel.text = @"Lưu & Respring"; cell.textLabel.textColor = [UIColor systemGreenColor]; }
    }
    else {
        if (indexPath.row == 0) { cell.textLabel.text = @"Thiết bị:"; cell.detailTextLabel.text = _currentConfig[@"name"]; }
        if (indexPath.row == 1) { cell.textLabel.text = @"Serial:"; cell.detailTextLabel.text = _currentConfig[@"serial"]; }
        if (indexPath.row == 2) { cell.textLabel.text = @"IDFV:"; cell.detailTextLabel.text = _currentConfig[@"idfv"]; }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) {
        if (indexPath.row == 0) [self randomizeAction];
        if (indexPath.row == 1) [self wipeData];
        if (indexPath.row == 2) [self respring];
    }
}

@end
