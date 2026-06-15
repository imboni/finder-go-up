#import <Foundation/Foundation.h>
#include "common.h"
#include "updater.h"

NSString *FGUUpdateAvailableNotification = @"FGUUpdateAvailableNotification";

static NSString *SupportDir(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"Library/Application Support/%s", FGU_SUPPORT_DIR]];
}

static NSString *PrefsPath(void) {
    return [SupportDir() stringByAppendingPathComponent:@(FGU_PREFS_FILE)];
}

static NSMutableDictionary *LoadPrefs(void) {
    NSString *path = PrefsPath();
    NSDictionary *stored = [NSDictionary dictionaryWithContentsOfFile:path];
    NSMutableDictionary *prefs = stored ? [stored mutableCopy] : [NSMutableDictionary dictionary];
    if (prefs[@"autoCheckUpdates"] == nil) {
        prefs[@"autoCheckUpdates"] = @YES;
    }
    return prefs;
}

static void SavePrefs(NSDictionary *prefs) {
    [[NSFileManager defaultManager] createDirectoryAtPath:SupportDir()
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
    [prefs writeToFile:PrefsPath() atomically:YES];
}

static NSString *NormalizeVersion(NSString *version) {
    NSString *trimmed = [version stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed hasPrefix:@"v"] || [trimmed hasPrefix:@"V"]) {
        return [trimmed substringFromIndex:1];
    }
    return trimmed;
}

static NSArray<NSNumber *> *VersionParts(NSString *version) {
    NSString *normalized = NormalizeVersion(version);
    NSArray<NSString *> *chunks = [normalized componentsSeparatedByString:@"."];
    NSMutableArray<NSNumber *> *parts = [NSMutableArray array];
    for (NSString *chunk in chunks) {
        NSInteger value = chunk.integerValue;
        [parts addObject:@(value)];
    }
    if (parts.count == 0) {
        [parts addObject:@0];
    }
    return parts;
}

static NSComparisonResult CompareVersionStrings(NSString *left, NSString *right) {
    NSArray<NSNumber *> *a = VersionParts(left);
    NSArray<NSNumber *> *b = VersionParts(right);
    NSUInteger count = MAX(a.count, b.count);
    for (NSUInteger i = 0; i < count; i++) {
        NSInteger av = i < a.count ? a[i].integerValue : 0;
        NSInteger bv = i < b.count ? b[i].integerValue : 0;
        if (av < bv) {
            return NSOrderedAscending;
        }
        if (av > bv) {
            return NSOrderedDescending;
        }
    }
    return NSOrderedSame;
}

NSString *FGU_CurrentVersion(void) {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return version.length > 0 ? version : @"0.0.0";
}

BOOL FGU_AutoCheckUpdatesEnabled(void) {
    return [LoadPrefs()[@"autoCheckUpdates"] boolValue];
}

void FGU_SetAutoCheckUpdates(BOOL enabled) {
    NSMutableDictionary *prefs = LoadPrefs();
    prefs[@"autoCheckUpdates"] = @(enabled);
    SavePrefs(prefs);
}

static void MarkUpdateChecked(void) {
    NSMutableDictionary *prefs = LoadPrefs();
    prefs[@"lastUpdateCheck"] = @([[NSDate date] timeIntervalSince1970]);
    SavePrefs(prefs);
}

static BOOL ShouldAutoCheck(void) {
    if (!FGU_AutoCheckUpdatesEnabled()) {
        return NO;
    }
    NSNumber *last = LoadPrefs()[@"lastUpdateCheck"];
    if (!last) {
        return YES;
    }
    return ([[NSDate date] timeIntervalSince1970] - last.doubleValue) >= (24 * 60 * 60);
}

void FGU_CheckForUpdatesWithCompletion(FGUUpdateCheckCompletion completion) {
    if (!completion) {
        return;
    }

    NSString *urlString = [NSString stringWithFormat:
        @"https://api.github.com/repos/%s/releases/latest", FGU_GITHUB_REPO];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        completion(NO, nil, nil,
                   [NSError errorWithDomain:@"finder-go-up"
                                       code:1
                                   userInfo:@{NSLocalizedDescriptionKey: @"无效的更新地址"}]);
        return;
    }

    NSURLSessionDataTask *task =
        [[NSURLSession sharedSession] dataTaskWithURL:url
                                    completionHandler:^(NSData *data,
                                                        NSURLResponse *response,
                                                        NSError *error) {
        (void)response;
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, nil, error);
            });
            return;
        }

        NSError *jsonError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:data ?: [NSData data]
                                                  options:0
                                                    error:&jsonError];
        if (![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil, nil, jsonError ?: [NSError errorWithDomain:@"finder-go-up"
                                                                          code:2
                                                                      userInfo:@{
                    NSLocalizedDescriptionKey: @"无法解析更新信息",
                }]);
            });
            return;
        }

        NSDictionary *release = (NSDictionary *)json;
        NSString *tag = release[@"tag_name"];
        NSString *releaseURL = release[@"html_url"] ?: @FGU_RELEASES_URL;
        NSString *current = FGU_CurrentVersion();
        BOOL updateAvailable = tag.length > 0 &&
            CompareVersionStrings(current, tag) == NSOrderedAscending;

        MarkUpdateChecked();

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(updateAvailable, tag, releaseURL, nil);
        });
    }];
    [task resume];
}

void FGU_CheckForUpdatesAutomaticallyIfNeeded(void) {
    if (!ShouldAutoCheck()) {
        return;
    }

    FGU_CheckForUpdatesWithCompletion(^(BOOL updateAvailable,
                                        NSString *latestVersion,
                                        NSString *releaseURL,
                                        NSError *error) {
        (void)error;
        if (!updateAvailable || latestVersion.length == 0) {
            return;
        }

        [[NSNotificationCenter defaultCenter]
            postNotificationName:FGUUpdateAvailableNotification
                          object:nil
                        userInfo:@{
            @"latestVersion": latestVersion,
            @"releaseURL": releaseURL ?: @FGU_RELEASES_URL,
        }];
    });
}
