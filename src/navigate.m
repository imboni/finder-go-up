#import <Foundation/Foundation.h>
#include "common.h"
#include "navigate.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

static int SendToDaemon(void) {
    int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (fd < 0) {
        return -1;
    }

    struct sockaddr_un addr = {0};
    addr.sun_family = AF_UNIX;
    strlcpy(addr.sun_path, FGU_SOCKET_PATH, sizeof(addr.sun_path));

    char signal = 1;
    ssize_t n = sendto(fd, &signal, 1, 0, (struct sockaddr *)&addr, sizeof(addr));
    close(fd);
    return n == 1 ? 0 : -1;
}

static void NavigateUpInline(void) {
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:
        @"tell application \"Finder\" to if (count of windows) > 0 then "
        @"set target of front window to (container of (target of front window))"];
    [script executeAndReturnError:nil];
}

void FGU_NavigateUp(void) {
    if (SendToDaemon() != 0) {
        NavigateUpInline();
    }
}
