#import <Cocoa/Cocoa.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/file.h>
#include "common.h"
#include "navigate.h"

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

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (strong) NSTextField *statusLabel;
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
    if (FGU_NavigateUpDirectWithError(&error)) {
        return YES;
    }
    return NO;
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
    [center addObserver:self
               selector:@selector(handleShowFromPeer:)
                   name:FGUNotifyShow
                 object:nil];
    [center addObserver:self
               selector:@selector(handleGoUpFromPeer:)
                   name:FGUNotifyGoUp
                 object:nil];
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

    NSString *script = [[NSBundle mainBundle] pathForResource:@"set-service-shortcut"
                                                       ofType:@"sh"];
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
        }
        return;
    }

    if (HasArg(@"--show") || !HasFlagFile(OnboardedFlag())) {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [self showWindow];
        [NSApp activateIgnoringOtherApps:YES];
        return;
    }

    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
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

- (void)showWindow {
    if (self.window) {
        [self refreshStatus];
        [self.window makeKeyAndOrderFront:nil];
        return;
    }

    const CGFloat pad = 24;
    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 360, 220)
                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = [NSString stringWithUTF8String:FGU_APP_NAME];
    self.window.releasedWhenClosed = NO;

    NSView *root = [[NSView alloc] initWithFrame:NSZeroRect];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    self.window.contentView = root;

    NSTextField *title = [NSTextField labelWithString:
        [NSString stringWithUTF8String:"返回上一级目录"]];
    title.font = [NSFont boldSystemFontOfSize:16];
    title.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *usage = [NSTextField labelWithString:
        [NSString stringWithUTF8String:
            "访达中选中任意项目 -> 右键 -> 服务 -> 返回上一级\n"
            "快捷键 Control+Command+上箭头"]];
    usage.font = [NSFont systemFontOfSize:12];
    usage.textColor = [NSColor secondaryLabelColor];
    usage.lineBreakMode = NSLineBreakByWordWrapping;
    usage.maximumNumberOfLines = 0;
    usage.translatesAutoresizingMaskIntoConstraints = NO;

    self.statusLabel = [NSTextField labelWithString:@""];
    self.statusLabel.font = [NSFont systemFontOfSize:12];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *authorize = [NSButton buttonWithTitle:@"允许控制访达"
                                             target:self
                                             action:@selector(requestAccess:)];
    authorize.bezelStyle = NSBezelStyleRounded;
    authorize.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *tryButton = [NSButton buttonWithTitle:@"试用一次"
                                              target:self
                                              action:@selector(tryOnce:)];
    tryButton.bezelStyle = NSBezelStyleRounded;
    tryButton.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *done = [NSButton buttonWithTitle:@"完成"
                                        target:self
                                        action:@selector(finish:)];
    done.bezelStyle = NSBezelStyleRounded;
    done.translatesAutoresizingMaskIntoConstraints = NO;
    done.keyEquivalent = @"\r";

    for (NSView *v in @[ title, usage, self.statusLabel, authorize, tryButton, done ]) {
        [root addSubview:v];
    }

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:root.topAnchor constant:pad],
        [title.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [title.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [usage.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
        [usage.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [usage.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [self.statusLabel.topAnchor constraintEqualToAnchor:usage.bottomAnchor constant:16],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [authorize.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:12],
        [authorize.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],

        [tryButton.centerYAnchor constraintEqualToAnchor:authorize.centerYAnchor],
        [tryButton.leadingAnchor constraintEqualToAnchor:authorize.trailingAnchor constant:8],

        [done.topAnchor constraintEqualToAnchor:authorize.bottomAnchor constant:12],
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
    NSString *script = [[NSBundle mainBundle] pathForResource:@"register-background-agent"
                                                       ofType:@"sh"];
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
