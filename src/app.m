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

static NSView *CardView(void) {
    NSView *card = [[NSView alloc] initWithFrame:NSZeroRect];
    card.wantsLayer = YES;
    card.layer.cornerRadius = 10;
    card.layer.borderWidth = 1;
    if (@available(macOS 10.14, *)) {
        card.layer.backgroundColor = [[NSColor controlBackgroundColor] CGColor];
        card.layer.borderColor = [[NSColor separatorColor] CGColor];
    }
    card.translatesAutoresizingMaskIntoConstraints = NO;
    return card;
}

static NSTextField *SectionHeading(NSString *text) {
    return Label(text, [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold],
                 [NSColor secondaryLabelColor]);
}

static NSView *CodeBlockView(NSString *text) {
    NSView *wrap = [[NSView alloc] initWithFrame:NSZeroRect];
    wrap.wantsLayer = YES;
    wrap.layer.cornerRadius = 6;
    if (@available(macOS 10.14, *)) {
        wrap.layer.backgroundColor = [[NSColor quaternarySystemFillColor] CGColor];
    }
    wrap.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    field.stringValue = text;
    field.bezeled = NO;
    field.drawsBackground = NO;
    field.editable = NO;
    field.selectable = YES;
    field.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    field.textColor = [NSColor labelColor];
    field.lineBreakMode = NSLineBreakByCharWrapping;
    field.maximumNumberOfLines = 0;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [wrap addSubview:field];
    [NSLayoutConstraint activateConstraints:@[
        [field.topAnchor constraintEqualToAnchor:wrap.topAnchor constant:10],
        [field.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor constant:10],
        [field.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor constant:-10],
        [field.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor constant:-10],
    ]];
    return wrap;
}

static NSButton *PrimaryButton(NSString *title, id target, SEL action) {
    NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
    button.bezelStyle = NSBezelStyleRounded;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.bezelColor = [NSColor controlAccentColor];
    button.attributedTitle = [[NSAttributedString alloc]
        initWithString:title attributes:@{
            NSFontAttributeName : [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName : [NSColor whiteColor],
        }];
    return button;
}

static NSButton *SecondaryButton(NSString *title, id target, SEL action) {
    NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
    button.bezelStyle = NSBezelStyleRounded;
    button.translatesAutoresizingMaskIntoConstraints = NO;
    return button;
}

static void FillCard(NSView *card, NSView *content, CGFloat inset) {
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:card.topAnchor constant:inset],
        [content.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:inset],
        [content.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-inset],
        [content.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-inset],
    ]];
}

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (strong) NSTextField *statusLabel;
@property (strong) NSTextField *updateStatusLabel;
@property (strong) NSButton *autoCheckButton;
@property (copy) NSString *integrationCommands;
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

- (void)copyIntegrationCommands:(id)sender {
    (void)sender;
    if (self.integrationCommands.length == 0) {
        return;
    }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:self.integrationCommands forType:NSPasteboardTypeString];
}

- (void)showWindow {
    if (self.window) {
        [self refreshStatus];
        self.autoCheckButton.state = FGU_AutoCheckUpdatesEnabled() ? NSControlStateValueOn
                                                                   : NSControlStateValueOff;
        [self.window makeKeyAndOrderFront:nil];
        return;
    }

    const CGFloat outer = 24;
    const CGFloat cardInset = 16;

    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 400, 640)
                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = [NSString stringWithUTF8String:FGU_APP_NAME];
    self.window.releasedWhenClosed = NO;

    NSView *root = [[NSView alloc] initWithFrame:NSZeroRect];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(macOS 10.14, *)) {
        root.wantsLayer = YES;
        root.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
    }
    self.window.contentView = root;

    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    icon.image = [NSApp applicationIconImage];
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [icon.widthAnchor constraintEqualToConstant:64].active = YES;
    [icon.heightAnchor constraintEqualToConstant:64].active = YES;

    NSTextField *title = Label([NSString stringWithUTF8String:FGU_APP_NAME],
                               [NSFont boldSystemFontOfSize:20], [NSColor labelColor]);
    title.alignment = NSTextAlignmentCenter;

    NSTextField *subtitle = Label(
        [NSString stringWithFormat:@"版本 %@  ·  访达返回上一级", FGU_CurrentVersion()],
        [NSFont systemFontOfSize:12], [NSColor secondaryLabelColor]);
    subtitle.alignment = NSTextAlignmentCenter;

    NSTextField *usageHeading = SectionHeading(@"使用");
    NSView *usageCard = CardView();
    NSTextField *usage = Label(
        [NSString stringWithUTF8String:
            "选中任意项目，右键「服务」→「返回上一级」\n"
            "快捷键：⌃⌘↑"],
        [NSFont systemFontOfSize:13], [NSColor labelColor]);
    self.statusLabel = Label(@"", [NSFont systemFontOfSize:12 weight:NSFontWeightMedium],
                              [NSColor labelColor]);
    NSButton *authorize = SecondaryButton(@"允许控制访达", self, @selector(requestAccess:));
    NSButton *tryButton = SecondaryButton(@"试用一次", self, @selector(tryOnce:));
    NSStackView *usageActions = [NSStackView stackViewWithViews:@[ authorize, tryButton ]];
    usageActions.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    usageActions.spacing = 10;
    usageActions.alignment = NSLayoutAttributeCenterY;
    usageActions.distribution = NSStackViewDistributionFillEqually;
    usageActions.translatesAutoresizingMaskIntoConstraints = NO;

    NSStackView *usageContent = [NSStackView stackViewWithViews:@[ usage, self.statusLabel, usageActions ]];
    usageContent.orientation = NSUserInterfaceLayoutOrientationVertical;
    usageContent.spacing = 12;
    usageContent.alignment = NSLayoutAttributeLeading;
    usageContent.translatesAutoresizingMaskIntoConstraints = NO;
    FillCard(usageCard, usageContent, cardInset);

    NSTextField *integrateHeading = SectionHeading(@"第三方接入");
    NSView *integrateCard = CardView();
    NSTextField *integrateIntro = Label(
        [NSString stringWithUTF8String:"可被脚本、快捷指令或其他 App 调用"],
        [NSFont systemFontOfSize:12], [NSColor secondaryLabelColor]);
    self.integrationCommands =
        @"finder-go-up\n"
        @"open finder-go-up://go-up";
    NSView *integrateCode = CodeBlockView(self.integrationCommands);
    NSTextField *integrateCli = Label(
        [NSString stringWithUTF8String:
            "安装 CLI（可选）：\n"
            "ln -sf ~/Applications/finder-go-up.app/Contents/MacOS/finder-go-up-client /usr/local/bin/finder-go-up"],
        [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular],
        [NSColor tertiaryLabelColor]);
    NSButton *copyCommands = SecondaryButton(@"复制命令", self, @selector(copyIntegrationCommands:));

    NSStackView *integrateContent = [NSStackView stackViewWithViews:@[
        integrateIntro, integrateCode, copyCommands, integrateCli
    ]];
    integrateContent.orientation = NSUserInterfaceLayoutOrientationVertical;
    integrateContent.spacing = 10;
    integrateContent.alignment = NSLayoutAttributeLeading;
    integrateContent.translatesAutoresizingMaskIntoConstraints = NO;
    FillCard(integrateCard, integrateContent, cardInset);
    [integrateCode.widthAnchor constraintEqualToAnchor:integrateContent.widthAnchor].active = YES;

    NSTextField *updateHeading = SectionHeading(@"更新");
    NSView *updateCard = CardView();
    self.autoCheckButton = [NSButton checkboxWithTitle:@"自动检查更新（每天一次）"
                                              target:self
                                              action:@selector(autoCheckChanged:)];
    self.autoCheckButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.autoCheckButton.state = FGU_AutoCheckUpdatesEnabled() ? NSControlStateValueOn
                                                               : NSControlStateValueOff;
    NSButton *checkUpdate = SecondaryButton(@"检查更新", self, @selector(checkUpdates:));
    self.updateStatusLabel = Label(@"", [NSFont systemFontOfSize:11], [NSColor tertiaryLabelColor]);

    NSStackView *updateContent = [NSStackView stackViewWithViews:@[
        self.autoCheckButton, checkUpdate, self.updateStatusLabel
    ]];
    updateContent.orientation = NSUserInterfaceLayoutOrientationVertical;
    updateContent.spacing = 10;
    updateContent.alignment = NSLayoutAttributeLeading;
    updateContent.translatesAutoresizingMaskIntoConstraints = NO;
    FillCard(updateCard, updateContent, cardInset);

    NSTextField *aboutHeading = SectionHeading(@"关于");
    NSView *aboutCard = CardView();
    NSTextField *about = Label(
        [NSString stringWithUTF8String:
            "macOS 轻量工具，MIT 开源\n"
            "github.com/imboni/finder-go-up"],
        [NSFont systemFontOfSize:12], [NSColor secondaryLabelColor]);
    NSButton *githubButton = SecondaryButton(@"GitHub", self, @selector(openGitHub:));
    NSButton *releasesButton = SecondaryButton(@"更新日志", self, @selector(openReleases:));
    NSStackView *aboutLinks = [NSStackView stackViewWithViews:@[ githubButton, releasesButton ]];
    aboutLinks.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    aboutLinks.spacing = 10;
    aboutLinks.translatesAutoresizingMaskIntoConstraints = NO;

    NSStackView *aboutContent = [NSStackView stackViewWithViews:@[ about, aboutLinks ]];
    aboutContent.orientation = NSUserInterfaceLayoutOrientationVertical;
    aboutContent.spacing = 12;
    aboutContent.alignment = NSLayoutAttributeLeading;
    aboutContent.translatesAutoresizingMaskIntoConstraints = NO;
    FillCard(aboutCard, aboutContent, cardInset);

    NSButton *done = PrimaryButton(@"完成", self, @selector(finish:));
    done.keyEquivalent = @"\r";
    [done.widthAnchor constraintGreaterThanOrEqualToConstant:160].active = YES;
    [done.heightAnchor constraintEqualToConstant:32].active = YES;

    for (NSView *v in @[
        icon, title, subtitle, usageHeading, usageCard, integrateHeading, integrateCard,
        updateHeading, updateCard, aboutHeading, aboutCard, done
    ]) {
        [root addSubview:v];
    }

    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:root.topAnchor constant:outer],
        [icon.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],

        [title.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12],
        [title.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [title.leadingAnchor constraintGreaterThanOrEqualToAnchor:root.leadingAnchor constant:outer],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:root.trailingAnchor constant:-outer],

        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],
        [subtitle.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [subtitle.leadingAnchor constraintGreaterThanOrEqualToAnchor:root.leadingAnchor constant:outer],
        [subtitle.trailingAnchor constraintLessThanOrEqualToAnchor:root.trailingAnchor constant:-outer],

        [usageHeading.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:20],
        [usageHeading.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:outer + 2],

        [usageCard.topAnchor constraintEqualToAnchor:usageHeading.bottomAnchor constant:6],
        [usageCard.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:outer],
        [usageCard.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-outer],

        [integrateHeading.topAnchor constraintEqualToAnchor:usageCard.bottomAnchor constant:16],
        [integrateHeading.leadingAnchor constraintEqualToAnchor:usageHeading.leadingAnchor],

        [integrateCard.topAnchor constraintEqualToAnchor:integrateHeading.bottomAnchor constant:6],
        [integrateCard.leadingAnchor constraintEqualToAnchor:usageCard.leadingAnchor],
        [integrateCard.trailingAnchor constraintEqualToAnchor:usageCard.trailingAnchor],

        [updateHeading.topAnchor constraintEqualToAnchor:integrateCard.bottomAnchor constant:16],
        [updateHeading.leadingAnchor constraintEqualToAnchor:usageHeading.leadingAnchor],

        [updateCard.topAnchor constraintEqualToAnchor:updateHeading.bottomAnchor constant:6],
        [updateCard.leadingAnchor constraintEqualToAnchor:usageCard.leadingAnchor],
        [updateCard.trailingAnchor constraintEqualToAnchor:usageCard.trailingAnchor],

        [aboutHeading.topAnchor constraintEqualToAnchor:updateCard.bottomAnchor constant:16],
        [aboutHeading.leadingAnchor constraintEqualToAnchor:usageHeading.leadingAnchor],

        [aboutCard.topAnchor constraintEqualToAnchor:aboutHeading.bottomAnchor constant:6],
        [aboutCard.leadingAnchor constraintEqualToAnchor:usageCard.leadingAnchor],
        [aboutCard.trailingAnchor constraintEqualToAnchor:usageCard.trailingAnchor],

        [done.topAnchor constraintEqualToAnchor:aboutCard.bottomAnchor constant:20],
        [done.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [done.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-outer],

        [usageActions.widthAnchor constraintEqualToAnchor:usageContent.widthAnchor],
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
