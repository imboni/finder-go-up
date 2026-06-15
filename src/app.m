#import <Cocoa/Cocoa.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/file.h>
#include "common.h"
#include "navigate.h"
#include "updater.h"

static const char *FGU_INSTANCE_LOCK = "instance.lock";
static NSString *FGUNotifyShow = @"com.acode.finder-go-up.show";
static NSString *FGUNotifyGoUp = @"com.acode.finder-go-up.go-up";
static int gInstanceLockFd = -1;

static NSString *SupportDir(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"Library/Application Support/%s", FGU_SUPPORT_DIR]];
}

static NSString *FlagPath(NSString *name) {
    return [SupportDir() stringByAppendingPathComponent:name];
}

static BOOL HasFlagFile(NSString *name) {
    return [[NSFileManager defaultManager] fileExistsAtPath:FlagPath(name)];
}

static void SetFlagFile(NSString *name) {
    [[NSFileManager defaultManager] createDirectoryAtPath:SupportDir()
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
    [@"" writeToFile:FlagPath(name) atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static NSString *OnboardedFlag(void) {
    return @(FGU_ONBOARDED_FILE);
}

static NSString *RegisteredFlag(void) {
    return @(FGU_REGISTERED_FILE);
}

static BOOL HasArg(NSString *flag) {
    for (NSString *arg in [NSProcessInfo processInfo].arguments) {
        if ([arg isEqualToString:flag]) {
            return YES;
        }
    }
    return NO;
}

static BOOL AcquireInstanceLock(void) {
    NSString *dir = SupportDir();
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
    NSString *lockPath = [dir stringByAppendingPathComponent:@(FGU_INSTANCE_LOCK)];
    gInstanceLockFd = open(lockPath.fileSystemRepresentation, O_CREAT | O_RDWR, 0644);
    if (gInstanceLockFd < 0) {
        return YES;
    }
    return flock(gInstanceLockFd, LOCK_EX | LOCK_NB) == 0;
}

static void NotifyPeer(NSString *name) {
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:name
                                                                   object:nil
                                                                 userInfo:nil
                                                       deliverImmediately:YES];
}

static BOOL LaunchedForService(void) {
    for (NSString *arg in [NSProcessInfo processInfo].arguments) {
        if ([arg isEqualToString:@"-NSService"]) {
            return YES;
        }
    }
    return NO;
}

static BOOL URLIsGoUp(NSURL *url) {
    if (![url.scheme isEqualToString:@"finder-go-up"]) {
        return NO;
    }
    NSString *host = url.host.lowercaseString;
    NSString *path = url.path.lowercaseString;
    return [host isEqualToString:@"go-up"] || [path isEqualToString:@"/go-up"] || [path isEqualToString:@"go-up"];
}

static NSTextField *Label(NSString *text, NSFont *font, NSColor *color) {
    NSTextField *field = [NSTextField labelWithString:text];
    field.font = font;
    field.textColor = color;
    field.lineBreakMode = NSLineBreakByWordWrapping;
    field.maximumNumberOfLines = 0;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    return field;
}

static NSBox *Separator(void) {
    NSBox *box = [[NSBox alloc] initWithFrame:NSZeroRect];
    box.boxType = NSBoxSeparator;
    box.translatesAutoresizingMaskIntoConstraints = NO;
    return box;
}

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (strong) NSTextField *statusLabel;
@property (strong) NSTextField *updateStatusLabel;
@property (strong) NSButton *autoCheckButton;
@property (assign) BOOL pendingGoUp;
@end

static void RegisterAppWithLaunchServices(void) {
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    NSString *cmd =
        @"LSREGISTER='/System/Library/Frameworks/CoreServices.framework/Frameworks/"
         @"LaunchServices.framework/Support/lsregister'; "
         @"\"$LSREGISTER\" -f -R -trusted '%@' 2>/dev/null; "
         @"/System/Library/CoreServices/pbs -update 2>/dev/null";
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/sh";
    task.arguments = @[ @"-c", [NSString stringWithFormat:cmd, appPath] ];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        (void)exception;
    }
}

@implementation AppDelegate

- (BOOL)navigateSilently {
    NSDictionary *error = nil;
    return FGU_NavigateUpDirectWithError(&error);
}

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    (void)application;
    for (NSURL *url in urls) {
        if (URLIsGoUp(url)) {
            self.pendingGoUp = YES;
            if (self.window) {
                [self navigateSilently];
                [NSApp terminate:nil];
            }
            return;
        }
    }
}

- (void)handleShowFromPeer:(NSNotification *)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [self showWindow];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)handleGoUpFromPeer:(NSNotification *)notification {
    (void)notification;
    [self finderGoUp:nil userData:nil error:nil];
}

- (void)setupPeerNotifications {
    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(handleShowFromPeer:) name:FGUNotifyShow object:nil];
    [center addObserver:self selector:@selector(handleGoUpFromPeer:) name:FGUNotifyGoUp object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUpdateAvailable:)
                                                 name:FGUUpdateAvailableNotification
                                               object:nil];
}

- (void)handleUpdateAvailable:(NSNotification *)notification {
    NSString *latestVersion = notification.userInfo[@"latestVersion"];
    NSString *releaseURL = notification.userInfo[@"releaseURL"];
    [self showUpdateResult:YES
             latestVersion:latestVersion
                releaseURL:releaseURL
                     error:nil
                    manual:YES];
}

- (void)registerServiceHandler {
    [NSApp setServicesProvider:self];
    NSUpdateDynamicServices();
}

- (void)finderGoUp:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error {
    (void)pboard;
    (void)userData;
    (void)error;
    if (![self navigateSilently]) {
        NSBeep();
    }
}

- (void)configureServiceShortcutIfNeeded {
    if (HasFlagFile(RegisteredFlag())) {
        return;
    }
    NSString *script = [[NSBundle mainBundle] pathForResource:@"set-service-shortcut" ofType:@"sh"];
    if (!script) {
        return;
    }
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/sh";
    task.arguments = @[ script ];
    @try {
        [task launch];
        [task waitUntilExit];
        NSTask *flush = [[NSTask alloc] init];
        flush.launchPath = @"/bin/sh";
        flush.arguments = @[ @"-c", @"/System/Library/CoreServices/pbs -flush 2>/dev/null" ];
        [flush launch];
        [flush waitUntilExit];
        SetFlagFile(RegisteredFlag());
    } @catch (NSException *exception) {
        (void)exception;
    }
}

- (void)registerWithSystemIfNeeded {
    RegisterAppWithLaunchServices();
    [self configureServiceShortcutIfNeeded];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    (void)notification;
    if (!AcquireInstanceLock()) {
        if (HasArg(@"--show")) {
            NotifyPeer(FGUNotifyShow);
        } else if (HasArg(@"--go-up") || LaunchedForService()) {
            NotifyPeer(FGUNotifyGoUp);
        }
        [NSApp terminate:nil];
        return;
    }
    [self setupPeerNotifications];
    [self registerServiceHandler];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [self registerWithSystemIfNeeded];
    [self registerServiceHandler];

    if (HasArg(@"--quit")) {
        [NSApp terminate:nil];
        return;
    }

    if (self.pendingGoUp || HasArg(@"--go-up")) {
        [self navigateSilently];
        if (!HasFlagFile(OnboardedFlag())) {
            [NSApp terminate:nil];
            return;
        }
        FGU_CheckForUpdatesAutomaticallyIfNeeded();
        return;
    }

    if (HasArg(@"--show") || !HasFlagFile(OnboardedFlag())) {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [self showWindow];
        [NSApp activateIgnoringOtherApps:YES];
        FGU_CheckForUpdatesAutomaticallyIfNeeded();
        return;
    }

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    FGU_CheckForUpdatesAutomaticallyIfNeeded();
}

- (void)refreshStatus {
    if (!self.statusLabel) {
        return;
    }
    if (FGU_HasFinderAutomationAccess()) {
        self.statusLabel.stringValue = @"✓ 已授权，可直接使用";
        self.statusLabel.textColor = [NSColor systemGreenColor];
    } else {
        self.statusLabel.stringValue = @"需要允许控制「访达」";
        self.statusLabel.textColor = [NSColor secondaryLabelColor];
    }
}

- (void)showUpdateResult:(BOOL)updateAvailable
           latestVersion:(NSString *)latestVersion
              releaseURL:(NSString *)releaseURL
                   error:(NSError *)error
                  manual:(BOOL)manual {
    if (!self.updateStatusLabel) {
        return;
    }

    if (error) {
        self.updateStatusLabel.stringValue = @"检查更新失败，请稍后重试";
        self.updateStatusLabel.textColor = [NSColor systemOrangeColor];
        return;
    }

    if (updateAvailable) {
        self.updateStatusLabel.stringValue =
            [NSString stringWithFormat:@"发现新版本 %@", latestVersion ?: @""];
        self.updateStatusLabel.textColor = [NSColor systemBlueColor];
        if (manual) {
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"发现新版本";
            alert.informativeText = [NSString stringWithFormat:
                @"当前版本 %@，最新版本 %@。",
                FGU_CurrentVersion(), latestVersion ?: @""];
            [alert addButtonWithTitle:@"下载"];
            [alert addButtonWithTitle:@"取消"];
            if ([alert runModal] == NSAlertFirstButtonReturn && releaseURL.length > 0) {
                [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:releaseURL]];
            }
        }
        return;
    }

    self.updateStatusLabel.stringValue = @"当前已是最新版本";
    self.updateStatusLabel.textColor = [NSColor secondaryLabelColor];
}

- (void)checkUpdates:(id)sender {
    (void)sender;
    if (self.updateStatusLabel) {
        self.updateStatusLabel.stringValue = @"正在检查更新…";
        self.updateStatusLabel.textColor = [NSColor secondaryLabelColor];
    }
    FGU_CheckForUpdatesWithCompletion(^(BOOL updateAvailable,
                                        NSString *latestVersion,
                                        NSString *releaseURL,
                                        NSError *error) {
        [self showUpdateResult:updateAvailable
                 latestVersion:latestVersion
                    releaseURL:releaseURL
                         error:error
                        manual:YES];
    });
}

- (void)autoCheckChanged:(id)sender {
    FGU_SetAutoCheckUpdates([(NSButton *)sender state] == NSControlStateValueOn);
}

- (void)openGitHub:(id)sender {
    (void)sender;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@FGU_GITHUB_URL]];
}

- (void)openReleases:(id)sender {
    (void)sender;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@FGU_RELEASES_URL]];
}

- (void)showWindow {
    if (self.window) {
        [self refreshStatus];
        self.autoCheckButton.state = FGU_AutoCheckUpdatesEnabled() ? NSControlStateValueOn
                                                                   : NSControlStateValueOff;
        [self.window makeKeyAndOrderFront:nil];
        return;
    }

    const CGFloat pad = 20;
    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 420, 520)
                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = [NSString stringWithUTF8String:FGU_APP_NAME];
    self.window.releasedWhenClosed = NO;

    NSView *root = [[NSView alloc] initWithFrame:NSZeroRect];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    self.window.contentView = root;

    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    icon.image = [NSApp applicationIconImage];
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [icon.widthAnchor constraintEqualToConstant:48].active = YES;
    [icon.heightAnchor constraintEqualToConstant:48].active = YES;

    NSTextField *title = Label([NSString stringWithUTF8String:FGU_APP_NAME],
                               [NSFont boldSystemFontOfSize:18], [NSColor labelColor]);
    NSTextField *version = Label([NSString stringWithFormat:@"版本 %@",
                                  FGU_CurrentVersion()],
                                 [NSFont systemFontOfSize:12], [NSColor secondaryLabelColor]);
    NSTextField *tagline = Label(
        [NSString stringWithUTF8String:"在访达当前窗口返回上一级目录"],
        [NSFont systemFontOfSize:12], [NSColor secondaryLabelColor]);

    NSTextField *usage = Label(
        [NSString stringWithUTF8String:
            "用法：选中任意项目 -> 右键 -> 服务 -> 返回上一级\n"
            "快捷键：Control+Command+上箭头"],
        [NSFont systemFontOfSize:12], [NSColor labelColor]);

    self.statusLabel = Label(@"", [NSFont systemFontOfSize:12], [NSColor labelColor]);

    NSButton *authorize = [NSButton buttonWithTitle:@"允许控制访达"
                                             target:self action:@selector(requestAccess:)];
    authorize.bezelStyle = NSBezelStyleRounded;
    authorize.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *tryButton = [NSButton buttonWithTitle:@"试用一次"
                                             target:self action:@selector(tryOnce:)];
    tryButton.bezelStyle = NSBezelStyleRounded;
    tryButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSBox *sep1 = Separator();
    NSBox *sep2 = Separator();

    self.autoCheckButton = [NSButton checkboxWithTitle:@"自动检查更新（每天一次）"
                                              target:self
                                              action:@selector(autoCheckChanged:)];
    self.autoCheckButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.autoCheckButton.state = FGU_AutoCheckUpdatesEnabled() ? NSControlStateValueOn
                                                               : NSControlStateValueOff;

    NSButton *checkUpdate = [NSButton buttonWithTitle:@"检查更新"
                                               target:self
                                               action:@selector(checkUpdates:)];
    checkUpdate.bezelStyle = NSBezelStyleRounded;
    checkUpdate.translatesAutoresizingMaskIntoConstraints = NO;

    self.updateStatusLabel = Label(@"", [NSFont systemFontOfSize:11], [NSColor secondaryLabelColor]);

    NSTextField *about = Label(
        [NSString stringWithUTF8String:
            "finder-go-up 是一款 macOS 轻量工具。\n"
            "开源协议：MIT\n"
            "仓库：github.com/imboni/finder-go-up"],
        [NSFont systemFontOfSize:11], [NSColor secondaryLabelColor]);

    NSButton *githubButton = [NSButton buttonWithTitle:@"GitHub 主页"
                                                target:self
                                                action:@selector(openGitHub:)];
    githubButton.bezelStyle = NSBezelStyleRounded;
    githubButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *releasesButton = [NSButton buttonWithTitle:@"更新日志"
                                                  target:self
                                                  action:@selector(openReleases:)];
    releasesButton.bezelStyle = NSBezelStyleRounded;
    releasesButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *done = [NSButton buttonWithTitle:@"完成"
                                        target:self
                                        action:@selector(finish:)];
    done.bezelStyle = NSBezelStyleRounded;
    done.translatesAutoresizingMaskIntoConstraints = NO;
    done.keyEquivalent = @"\r";

    for (NSView *v in @[
        icon, title, version, tagline, usage, self.statusLabel, authorize, tryButton,
        sep1, self.autoCheckButton, checkUpdate, self.updateStatusLabel, sep2, about,
        githubButton, releasesButton, done
    ]) {
        [root addSubview:v];
    }

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:root.topAnchor constant:pad],
        [icon.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [title.topAnchor constraintEqualToAnchor:icon.topAnchor constant:2],
        [version.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [version.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
        [tagline.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [tagline.topAnchor constraintEqualToAnchor:version.bottomAnchor constant:4],
        [tagline.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [usage.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:16],
        [usage.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [usage.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [self.statusLabel.topAnchor constraintEqualToAnchor:usage.bottomAnchor constant:10],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [authorize.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:10],
        [authorize.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [tryButton.centerYAnchor constraintEqualToAnchor:authorize.centerYAnchor],
        [tryButton.leadingAnchor constraintEqualToAnchor:authorize.trailingAnchor constant:8],

        [sep1.topAnchor constraintEqualToAnchor:authorize.bottomAnchor constant:14],
        [sep1.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [sep1.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [self.autoCheckButton.topAnchor constraintEqualToAnchor:sep1.bottomAnchor constant:14],
        [self.autoCheckButton.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad - 4],
        [checkUpdate.centerYAnchor constraintEqualToAnchor:self.autoCheckButton.centerYAnchor],
        [checkUpdate.leadingAnchor constraintEqualToAnchor:self.autoCheckButton.trailingAnchor constant:12],

        [self.updateStatusLabel.topAnchor constraintEqualToAnchor:self.autoCheckButton.bottomAnchor constant:6],
        [self.updateStatusLabel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [self.updateStatusLabel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [sep2.topAnchor constraintEqualToAnchor:self.updateStatusLabel.bottomAnchor constant:12],
        [sep2.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [sep2.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [about.topAnchor constraintEqualToAnchor:sep2.bottomAnchor constant:12],
        [about.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [about.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [githubButton.topAnchor constraintEqualToAnchor:about.bottomAnchor constant:10],
        [githubButton.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [releasesButton.centerYAnchor constraintEqualToAnchor:githubButton.centerYAnchor],
        [releasesButton.leadingAnchor constraintEqualToAnchor:githubButton.trailingAnchor constant:8],

        [done.topAnchor constraintEqualToAnchor:githubButton.bottomAnchor constant:14],
        [done.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],
        [done.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-pad],
    ]];

    [self.window center];
    [self refreshStatus];
    [self.window makeKeyAndOrderFront:nil];
}

- (void)requestAccess:(id)sender {
    (void)sender;
    FGU_RequestFinderAutomationAccess();
    [self refreshStatus];
}

- (void)tryOnce:(id)sender {
    (void)sender;
    if ([self navigateSilently]) {
        self.statusLabel.stringValue = @"✓ 已返回上一级";
        self.statusLabel.textColor = [NSColor systemGreenColor];
        return;
    }
    if (!FGU_HasFinderAutomationAccess()) {
        self.statusLabel.stringValue = @"请先点击「允许控制访达」";
        self.statusLabel.textColor = [NSColor systemOrangeColor];
        return;
    }
    self.statusLabel.stringValue = @"请先在访达中打开一个文件夹";
    self.statusLabel.textColor = [NSColor systemOrangeColor];
}

- (void)enableBackgroundAgent {
    NSString *script = [[NSBundle mainBundle] pathForResource:@"register-background-agent" ofType:@"sh"];
    if (!script) {
        return;
    }
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/bash";
    task.arguments = @[ script, appPath, @"--agent-only" ];
    @try {
        [task launch];
    } @catch (NSException *exception) {
        (void)exception;
    }
}

- (void)finish:(id)sender {
    (void)sender;
    if (FGU_HasFinderAutomationAccess()) {
        SetFlagFile(OnboardedFlag());
        [self enableBackgroundAgent];
    }
    [self.window orderOut:nil];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return NO;
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
