#ifndef FGU_NAVIGATE_H
#define FGU_NAVIGATE_H

#import <Foundation/Foundation.h>

void FGU_NavigateUp(void);
void FGU_NavigateUpDirect(void);
BOOL FGU_NavigateUpWithError(NSDictionary **errorOut);
BOOL FGU_NavigateUpDirectWithError(NSDictionary **errorOut);
BOOL FGU_HasFinderAutomationAccess(void);

#endif
