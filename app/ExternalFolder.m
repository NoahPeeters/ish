//
//  ExternalFolder.m
//  iSH
//
//  Created by Noah Peeters on 26.10.19.
//

#import <Foundation/Foundation.h>
#include "kernel/fs.h"
#include "kernel/errno.h"
#include "fs/path.h"

NSURL* urlForMount(struct mount *mount) {
    return (__bridge NSURL *) mount->data;
}

int external_mount(struct mount *mount) {
    NSURL *url = urlForMount(mount);
    if ([url startAccessingSecurityScopedResource] == NO) {
        CFBridgingRelease(mount->data);
        return errno_map();
    }

    generic_mkdirat(AT_PWD, mount->point, 0755);

    return realfs.mount(mount);
}

int external_umount(struct mount *mount) {
    NSURL *url = urlForMount(mount);
    [url stopAccessingSecurityScopedResource];
    CFBridgingRelease(mount->data);

    return 0;
}

struct fs_ops* createExternalfs() {
    struct fs_ops *fs = malloc(sizeof(struct fs_ops));
    *fs = realfs;

    fs->name = "external";
    fs->magic = 0x7265616d;
    fs->mount = external_mount;
    fs->umount = external_umount;

    return fs;
}

const struct fs_ops *externalfs = nil;

void createExternalfsIfRequired(void) {
    if (externalfs == nil) {
        externalfs = createExternalfs();
    }
}

