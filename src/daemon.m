#import <Foundation/Foundation.h>
#include "common.h"
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

static NSAppleScript *NavigationScript(void) {
    static NSAppleScript *script;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        script = [[NSAppleScript alloc] initWithSource:
            @"tell application \"Finder\" to if (count of windows) > 0 then "
            @"set target of front window to (container of (target of front window))"];
    });
    return script;
}

static void NavigateUp(void) {
    [NavigationScript() executeAndReturnError:nil];
}

int main(void) {
    @autoreleasepool {
        const char *path = FGU_SOCKET_PATH;
        unlink(path);

        int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
        if (fd < 0) {
            return 1;
        }

        struct sockaddr_un addr = {0};
        addr.sun_family = AF_UNIX;
        strlcpy(addr.sun_path, path, sizeof(addr.sun_path));
        if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
            return 1;
        }

        chmod(path, 0666);

        dispatch_queue_t navQueue =
            dispatch_queue_create(FGU_DAEMON_LABEL ".navigate", DISPATCH_QUEUE_SERIAL);

        for (;;) {
            char buf[8];
            ssize_t n = recv(fd, buf, sizeof(buf), 0);
            if (n <= 0) {
                continue;
            }

            dispatch_async(navQueue, ^{
                NavigateUp();
            });
        }
    }

    return 0;
}
