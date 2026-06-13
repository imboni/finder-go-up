#import <Cocoa/Cocoa.h>
#include "common.h"
#include "navigate.h"

static NSString *SupportDirectory(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"Library/Application Support/%s", FGU_SUPPORT_DIR]];
}

static NSString *OnboardedMarkerPath(void) {
    return [[SupportDirectory()
        stringByAppendingPathComponent:[NSString stringWithUTF8String:FGU_ONBOARDED_FILE]] copy];
}

static BOOL IsOnboardingCompleted(void) {
    return [[NSFileManager defaultManager] fileExistsAtPath:OnboardedMarkerPath()];
}

static void MarkOnboardingCompleted(void) {
    NSString *dir = SupportDirectory();
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    [@"" writeToFile:OnboardedMarkerPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static BOOL HasLaunchFlag(NSString *flag) {
    for (NSString *arg in [NSProcessInfo processInfo].arguments) {
        if ([arg isEqualToString:flag]) {
            return YES;
        }
    }
    return NO;
}

static NSAttributedString *BodyText(NSString *text) {
    return [[NSAttributedString alloc] initWithString:text
                                           attributes:@{
                                               NSFontAttributeName : [NSFont systemFontOfSize:13],
                                               NSForegroundColorAttributeName : [NSColor labelColor],
                                           }];
}

static NSButton *MakeButton(NSString *title, NSView *superview) {
    NSButton *button = [NSButton buttonWithTitle:title target:nil action:NULL];
    button.bezelStyle = NSBezelStyleRounded;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [superview addSubview:button];
    return button;
}

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (assign) BOOL onboardingMode;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    if (HasLaunchFlag(@"--go-up")) {
        FGU_NavigateUp();
        [NSApp terminate:nil];
        return;
    }

    if (HasLaunchFlag(@"--check-onboarding") && IsOnboardingCompleted()) {
        [NSApp terminate:nil];
        return;
    }

    self.onboardingMode = !IsOnboardingCompleted();
    [self showMainWindow];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)showMainWindow {
    if (self.window) {
        [self.window makeKeyAndOrderFront:nil];
        return;
    }

    const CGFloat width = 500;
    const CGFloat height = self.onboardingMode ? 520 : 360;
    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, width, height)
                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = [NSString stringWithUTF8String:FGU_APP_NAME];
    self.window.releasedWhenClosed = NO;
    [self.window center];

    NSView *content = self.window.contentView;
    CGFloat y = height - 32;

    NSTextField *title = [NSTextField labelWithString:[NSString stringWithUTF8String:FGU_APP_NAME]];
    title.font = [NSFont boldSystemFontOfSize:22];
    title.frame = NSMakeRect(24, y - 4, width - 48, 28);
    [content addSubview:title];
    y -= 40;

    NSString *subtitle = self.onboardingMode ? @"欢迎使用！按以下步骤完成配置即可使用。"
                                             : @"在当前访达窗口返回上一级目录。";
    NSTextField *sub = [NSTextField labelWithString:subtitle];
    sub.font = [NSFont systemFontOfSize:13];
    sub.textColor = [NSColor secondaryLabelColor];
    sub.frame = NSMakeRect(24, y, width - 48, 20);
    [content addSubview:sub];
    y -= 28;

    if (self.onboardingMode) {
        NSTextView *steps = [[NSTextView alloc] initWithFrame:NSMakeRect(24, 120, width - 48, y - 128)];
        steps.editable = NO;
        steps.selectable = YES;
        steps.drawsBackground = NO;
        steps.textContainerInset = NSMakeSize(0, 0);
        steps.textStorage.attributedString = BodyText(
            @"1. 安装已完成，finder-go-up 已注册访达右键菜单。\n\n"
            @"2. 打开访达，在窗口空白处右键，选择 finder-go-up。\n\n"
            @"3. 若未看到菜单项：\n"
            @"   系统设置 → 键盘 → 键盘快捷键 → 服务\n"
            @"   勾选 finder-go-up，然后重启访达。\n\n"
            @"4. 首次使用时若弹出自动化权限，请允许控制 Finder。");
        [content addSubview:steps];
    } else {
        NSTextView *hint = [[NSTextView alloc] initWithFrame:NSMakeRect(24, 120, width - 48, y - 128)];
        hint.editable = NO;
        hint.selectable = YES;
        hint.drawsBackground = NO;
        hint.textContainerInset = NSMakeSize(0, 0);
        hint.textStorage.attributedString = BodyText(
            @"使用方式：访达窗口空白处 → 右键 → finder-go-up\n\n"
            @"也可点击下方「试用一次」在当前访达窗口测试。");
        [content addSubview:hint];
    }

    NSButton *settingsButton = MakeButton(@"打开系统设置", content);
    NSButton *tryButton = MakeButton(@"试用一次", content);
    NSButton *doneButton = MakeButton(self.onboardingMode ? @"完成设置" : @"关闭", content);

    settingsButton.target = self;
    settingsButton.action = @selector(openSettings:);
    tryButton.target = self;
    tryButton.action = @selector(tryOnce:);
    doneButton.target = self;
    doneButton.action = @selector(finish:);
    doneButton.keyEquivalent = @"\r";

    CGFloat buttonY = 24;
    settingsButton.frame = NSMakeRect(24, buttonY, 120, 32);
    tryButton.frame = NSMakeRect(156, buttonY, 96, 32);
    doneButton.frame = NSMakeRect(width - 124, buttonY, 100, 32);

    [self.window makeKeyAndOrderFront:nil];
}

- (void)openSettings:(id)sender {
    (void)sender;
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.keyboard?"
                                      @"KeyboardShortcuts"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)tryOnce:(id)sender {
    (void)sender;
    FGU_NavigateUp();
}

- (void)finish:(id)sender {
    (void)sender;
    if (self.onboardingMode) {
        MarkOnboardingCompleted();
        self.onboardingMode = NO;
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
