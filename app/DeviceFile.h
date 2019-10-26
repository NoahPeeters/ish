//
//  DeviceFile.h
//  iSH
//
//  Created by Noah Peeters on 25.10.19.
//

@interface DeviceFile : NSObject {
    NSData *buffer;
    size_t bufferOffset;
}

- (int)update;
- (ssize_t)readIntoBuffer:(void *)buf size:(size_t)size;

@end

#define DEFINE_SIMPLE_READ_DEV_OPS(handler_class, prefix) \
static int prefix##_open(int major, int minor, struct fd *fd) {\
    fd->data = (void *) CFBridgingRetain([handler_class new]);\
    return 0;\
}\
\
static int prefix##_close(struct fd *fd) {\
    CFBridgingRelease(fd->data);\
    return 0;\
}\
\
static ssize_t prefix##_read(struct fd *fd, void *buf, size_t size) {\
    handler_class *file = (__bridge handler_class *) fd->data;\
    return [file readIntoBuffer:buf size:size];\
}\
\
const struct dev_ops prefix##_dev = {\
    .open = prefix##_open,\
    .fd.close = prefix##_close,\
    .fd.read = prefix##_read,\
};
