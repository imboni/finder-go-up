#import <Cocoa/Cocoa.h>
#include "common.h"
#include "navigate.h"

static NSString *SupportDir(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"Library/Application Support/%s", FGU_SUPPORT_DIR]];
}

static NSString *OnboardedPath(void) {
    return [SupportDir() stringByAppendingPathComponent:@FGU_ONBOARDED_FILE];
}

static BOOL IsReady(void) {
    return [[NSFileManager defaultManager] fileExistsAtPath:OnboardedPath()];
}

static void MarkReady(void) {
    [[NSFileManager defaultManager] createDirectoryAtPath:SupportDir()
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
    [@"" writeToFile:OnboardedPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static BOOL HasFlag(NSString *flag) {
    for (NSString *arg in [NSProcessInfo processInfo].arguments) {
        if ([arg isEqualToString:flag]) {
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

static NSTextField *MakeLabel(NSString *text, NSFont *font, NSColor *color) {
    NSTextField *field = [NSTextField labelWithString:text];
    field.font = font;
    field.textColor = color;
    field.lineBreakMode = NSLineBreakByWordWrapping;
    field.maximumNumberOfLines = 0;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    return field;
}

static NSButton *PrimaryButton(NSString *title) {
    NSButton *button = [NSButton buttonWithTitle:@"" target:nil action:NULL];
    button.bezelStyle = NSBezelStyleRounded;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.bezelColor = [NSColor controlAccentColor];
    button.attributedTitle = [[NSAttributedString alloc]
        initWithString:title
            attributes:@{
                NSFontAttributeName : [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold],
                NSForegroundColorAttributeName : [NSColor whiteColor],
            }];
    return button;
}

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (strong) NSTextField *statusLabel;
@property (assign) BOOL headless;
@property (assign) BOOL pendingGoUp;
@end

@implementation AppDelegate

- (BOOL)navigateSilently {
    NSDictionary *error = nil;
    if (FGU_NavigateUpDirectWithError(&error)) {
        NSBeep();
        return YES;
    }
    return NO;
}

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls {
    (void)application;
    for (NSURL *url in urls) {
        if (URLIsGoUp(url)) {
            self.headless = YES;
            self.pendingGoUp = YES;
            if (self.window) {
                [self navigateSilently];
                [NSApp terminate:nil];
            }
            return;
        }
    }
}

- (void)registerServices {
    [NSApp setServicesProvider:self];
    NSUpdateDynamicServices();
}

- (void)finderGoUp:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error {
    (void)pboard;
    (void)userData;
    (void)error;
    self.headless = YES;
    [self navigateSilently];
    [NSApp terminate:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [self registerServices];

    if (self.pendingGoUp || HasFlag(@"--go-up")) {
        [self navigateSilently];
        [NSApp terminate:nil];
        return;
    }

    if (IsReady() && !HasFlag(@"--show")) {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [NSApp terminate:nil];
        return;
    }

    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [self showWindow];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)refreshStatus {
    if (!self.statusLabel) {
        return;
    }
    if (FGU_HasFinderAutomationAccess()) {
        self.statusLabel.stringValue = @"已授权控制访达";
        self.statusLabel.textColor = [NSColor systemGreenColor];
    } else {
        self.statusLabel.stringValue = @"尚未授权，请点击下方按钮";
        self.statusLabel.textColor = [NSColor systemOrangeColor];
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
        initWithContentRect:NSMakeRect(0, 0, 400, 100)
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
    [icon.widthAnchor constraintEqualToConstant:44].active = YES;
    [icon.heightAnchor constraintEqualToConstant:44].active = YES;

    NSTextField *title = MakeLabel([NSString stringWithUTF8String:FGU_APP_NAME],
                                   [NSFont boldSystemFontOfSize:18], [NSColor labelColor]);
    NSTextField *usage = MakeLabel(
        @"选中任意项目 → 右键 → 服务 → 返回上一级\n"
        @"快捷键：⌃⌘↑",
        [NSFont systemFontOfSize:12], [NSColor secondaryLabelColor]);

    self.statusLabel = MakeLabel(@"", [NSFont systemFontOfSize:12 weight:NSFontWeightMedium],
                                  [NSColor labelColor]);

    NSButton *authorize = PrimaryButton(@"授权并试用");
    authorize.target = self;
    authorize.action = @selector(authorize:);

    NSButton *done = [NSButton buttonWithTitle:@"完成" target:self action:@selector(finish:)];
    done.bezelStyle = NSBezelStyleRounded;
    done.translatesAutoresizingMaskIntoConstraints = NO;
    done.keyEquivalent = @"\r";

    for (NSView *v in @[ icon, title, usage, self.statusLabel, authorize, done ]) {
        [root addSubview:v];
    }

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:root.topAnchor constant:pad],
        [icon.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],

        [title.topAnchor constraintEqualToAnchor:icon.topAnchor constant:2],
        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [title.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [usage.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:16],
        [usage.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [usage.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [self.statusLabel.topAnchor constraintEqualToAnchor:usage.bottomAnchor constant:12],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [authorize.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:16],
        [authorize.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:pad],
        [authorize.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],

        [done.topAnchor constraintEqualToAnchor:authorize.bottomAnchor constant:10],
        [done.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-pad],
        [done.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-pad],
    ]];

    [self.window center];
    [self refreshStatus];
    [self.window makeKeyAndOrderFront:nil];
}

- (void)authorize:(id)sender {
    (void)sender;
    [[NSWorkspace sharedWorkspace] openApplicationAtURL:[NSURL fileURLWithPath:@"/System/Library/CoreServices/Finder.app"]
                                            configuration:[NSWorkspaceOpenConfiguration configuration]
                                        completionHandler:nil];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"允许控制访达";
    alert.informativeText = @"系统即将询问权限，请点击「允许」。";
    [alert addButtonWithTitle:@"继续"];
    [alert runModal];
    [self navigateSilently];
    [self refreshStatus];
}

- (void)finish:(id)sender {
    (void)sender;
    if (FGU_HasFinderAutomationAccess()) {
        MarkReady();
    }
    [NSApp terminate:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
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
