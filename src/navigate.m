#import <Foundation/Foundation.h>
#include "navigate.h"

static NSAppleScript *NavigationScript(void) {
    static NSAppleScript *script;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        script = [[NSAppleScript alloc] initWithSource:
            @"tell application \"Finder\" to set target of front window to "
             @"(container of target of front window)"];
        NSDictionary *error = nil;
        [script compileAndReturnError:&error];
        (void)error;
    });
    return script;
}

void FGU_WarmFinderConnection(void) {
    @autoreleasepool {
        NSDictionary *error = nil;
        NSAppleScript *ping = [[NSAppleScript alloc] initWithSource:
            @"tell application \"Finder\" to return name"];
        [ping executeAndReturnError:&error];
        (void)NavigationScript();
        (void)error;
    }
}

static BOOL RunNavigationScript(NSDictionary **errorOut) {
    return [NavigationScript() executeAndReturnError:errorOut] != nil;
}

BOOL FGU_NavigateUpDirectWithError(NSDictionary **errorOut) {
    return RunNavigationScript(errorOut);
}

BOOL FGU_NavigateUpWithError(NSDictionary **errorOut) {
    return RunNavigationScript(errorOut);
}

void FGU_NavigateUpDirect(void) {
    NSDictionary *error = nil;
    (void)FGU_NavigateUpDirectWithError(&error);
}

void FGU_NavigateUp(void) {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/open";
    task.arguments = @[ @"finder-go-up://go-up" ];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        (void)exception;
    }
}

BOOL FGU_HasFinderAutomationAccess(void) {
    NSDictionary *error = nil;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:
        @"tell application \"Finder\" to return name"];
    return [script executeAndReturnError:&error] != nil && error == nil;
}

BOOL FGU_RequestFinderAutomationAccess(void) {
    return FGU_HasFinderAutomationAccess();
}
