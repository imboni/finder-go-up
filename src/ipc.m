#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/file.h>
#include <sys/socket.h>
#include <sys/un.h>
#include "common.h"
#include "ipc.h"

static int gInstanceLockFd = -1;
static int gListenFd = -1;
static dispatch_source_t gListenSource;

static NSString *SupportDir(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"Library/Application Support/%s", FGU_SUPPORT_DIR]];
}

static NSString *InstanceLockPath(void) {
    return [SupportDir() stringByAppendingPathComponent:@"instance.lock"];
}

static NSString *GoUpSocketPath(void) {
    return [SupportDir() stringByAppendingPathComponent:@"go-up.sock"];
}

static void EnsureSupportDir(void) {
    [[NSFileManager defaultManager] createDirectoryAtPath:SupportDir()
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
}

BOOL FGU_TryAcquireInstanceLock(void) {
    EnsureSupportDir();
    NSString *lockPath = InstanceLockPath();
    gInstanceLockFd = open(lockPath.fileSystemRepresentation, O_CREAT | O_RDWR, 0644);
    if (gInstanceLockFd < 0) {
        return YES;
    }
    return flock(gInstanceLockFd, LOCK_EX | LOCK_NB) == 0;
}

BOOL FGU_SignalBackgroundToGoUp(void) {
    NSString *path = GoUpSocketPath();
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        return NO;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strlcpy(addr.sun_path, path.fileSystemRepresentation, sizeof(addr.sun_path));

    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(fd);
        return NO;
    }

    (void)write(fd, "1", 1);
    close(fd);
    return YES;
}

void FGU_StartGoUpListener(void (^handler)(void)) {
    if (!handler || gListenSource) {
        return;
    }

    EnsureSupportDir();
    NSString *path = GoUpSocketPath();
    unlink(path.fileSystemRepresentation);

    gListenFd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (gListenFd < 0) {
        return;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strlcpy(addr.sun_path, path.fileSystemRepresentation, sizeof(addr.sun_path));

    if (bind(gListenFd, (struct sockaddr *)&addr, sizeof(addr)) != 0 ||
        listen(gListenFd, 8) != 0) {
        close(gListenFd);
        gListenFd = -1;
        return;
    }

    gListenSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)gListenFd, 0,
                                           dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));
    dispatch_source_set_event_handler(gListenSource, ^{
        for (;;) {
            int client = accept(gListenFd, NULL, NULL);
            if (client < 0) {
                break;
            }
            char buffer[8];
            (void)read(client, buffer, sizeof(buffer));
            close(client);
            dispatch_async(dispatch_get_main_queue(), ^{
                handler();
            });
        }
    });
    dispatch_source_set_cancel_handler(gListenSource, ^{
        if (gListenFd >= 0) {
            close(gListenFd);
            gListenFd = -1;
        }
        unlink(path.fileSystemRepresentation);
    });
    dispatch_resume(gListenSource);
}

void FGU_StopGoUpListener(void) {
    if (!gListenSource) {
        return;
    }
    dispatch_source_cancel(gListenSource);
    gListenSource = nil;
}
