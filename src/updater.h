#ifndef FGU_UPDATER_H
#define FGU_UPDATER_H

#import <Foundation/Foundation.h>

extern NSString *FGUUpdateAvailableNotification;

typedef void (^FGUUpdateCheckCompletion)(BOOL updateAvailable,
                                         NSString *latestVersion,
                                         NSString *releaseURL,
                                         NSError *error);

NSString *FGU_CurrentVersion(void);
BOOL FGU_AutoCheckUpdatesEnabled(void);
void FGU_SetAutoCheckUpdates(BOOL enabled);
void FGU_CheckForUpdatesWithCompletion(FGUUpdateCheckCompletion completion);
void FGU_CheckForUpdatesAutomaticallyIfNeeded(void);

#endif
