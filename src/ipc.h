#ifndef FGU_IPC_H
#define FGU_IPC_H

#import <Foundation/Foundation.h>

BOOL FGU_TryAcquireInstanceLock(void);
BOOL FGU_SignalBackgroundToGoUp(void);
void FGU_StartGoUpListener(void (^handler)(void));
void FGU_StopGoUpListener(void);

#endif
