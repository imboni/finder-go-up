#import <Foundation/Foundation.h>
#include "navigate.h"

static BOOL RunNavigationScript(NSDictionary **errorOut) {
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:
        @"tell application \"Finder\"\n"
         @"  activate\n"
         @"  if (count of windows) is 0 then error \"没有打开的访达窗口\"\n"
         @"  set here to target of front window\n"
         @"  try\n"
         @"    set parentFolder to container of here\n"
         @"  on error\n"
         @"    error \"已经在最顶层目录\"\n"
         @"  end try\n"
         @"  set target of front window to parentFolder\n"
         @"end tell"];
    return [script executeAndReturnError:errorOut] != nil;
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
