//
//  DeviceFile.m
//  iSH
//
//  Created by Noah Peeters on 25.10.19.
//

#import <Foundation/Foundation.h>
#import "DeviceFile.h"

@implementation DeviceFile

- (int)update {
    return 0;
}

- (ssize_t)readIntoBuffer:(void *)buf size:(size_t)size {
    @synchronized (self) {
        int err = [self update];
        if (err < 0)
            return err;
        size_t remaining = buffer.length - bufferOffset;
        if (size > remaining)
            size = remaining;
        [buffer getBytes:buf range:NSMakeRange(bufferOffset, size)];
        bufferOffset += size;
        if (bufferOffset == buffer.length)
            buffer = nil;
        return size;
    }
}

@end
