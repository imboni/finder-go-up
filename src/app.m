#import <Cocoa/Cocoa.h>
#include "common.h"
#include "ipc.h"
#include "navigate.h"
#include "updater.h"

static NSString *FGUNotifyGoUp = @"com.acode.finder-go-up.go-up";

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

static void NotifyPeerFallback(void) {
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:FGUNotifyGoUp
                                                                   object:nil
                                                                 userInfo:nil
                                                       deliverImmediately:YES];
}

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

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (assign) BOOL pendingGoUp;
@property (assign) BOOL serviceHandledNavigate;
@property (assign) BOOL backgroundStarted;
@end

@implementation AppDelegate

- (BOOL)navigateSilently {
    NSDictionary *error = nil;
    return FGU_NavigateUpDirectWithError(&error);
}

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    (void)application;
    for (NSURL *url in urls) {
        if (![url.scheme isEqualToString:@"finder-go-up"]) {
            continue;
        }
        NSString *host = url.host.lowercaseString;
        NSString *path = url.path.lowercaseString;
        if ([host isEqualToString:@"go-up"] || [path isEqualToString:@"/go-up"] ||
            [path isEqualToString:@"go-up"]) {
            self.pendingGoUp = YES;
            return;
        }
    }
}

- (void)registerServiceHandler {
    [NSApp setServicesProvider:self];
    NSUpdateDynamicServices();
}

- (void)finderGoUp:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error {
    (void)pboard;
    (void)userData;
    (void)error;
    self.serviceHandledNavigate = YES;
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

- (void)startBackgroundMode {
    if (self.backgroundStarted) {
        return;
    }
    self.backgroundStarted = YES;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    [self registerWithSystemIfNeeded];
    FGU_StartGoUpListener(^{
        [self navigateSilently];
    });
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        FGU_WarmFinderConnection();
    });
    FGU_CheckForUpdatesAutomaticallyIfNeeded();
}

- (void)navigateIfNotServiceLaunch {
    if (self.serviceHandledNavigate) {
        return;
    }
    [self navigateSilently];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    (void)notification;
    if (!FGU_TryAcquireInstanceLock()) {
        if (!FGU_SignalBackgroundToGoUp()) {
            NotifyPeerFallback();
            [self navigateSilently];
        }
        [NSApp terminate:nil];
        return;
    }
    [self registerServiceHandler];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [self registerServiceHandler];

    if (HasArg(@"--quit")) {
        [NSApp terminate:nil];
        return;
    }

    if (HasArg(@"--background")) {
        [self startBackgroundMode];
        return;
    }

    [self startBackgroundMode];

    if (self.pendingGoUp || HasArg(@"--go-up")) {
        self.serviceHandledNavigate = YES;
        [self navigateSilently];
        return;
    }

    [self performSelector:@selector(navigateIfNotServiceLaunch) withObject:nil afterDelay:0.05];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    (void)sender;
    (void)flag;
    self.serviceHandledNavigate = YES;
    [self navigateSilently];
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
