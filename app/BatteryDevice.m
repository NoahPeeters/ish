//
//  BatteryDevice.m
//  iSH
//
//  Created by Noah Peeters on 25.10.19.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include "kernel/fs.h"
#include "fs/dev.h"
#include "util/sync.h"
#include "DeviceFile.h"

@interface BatteryFile : DeviceFile

@property UIDevice *device;

@end

@implementation BatteryFile

- (instancetype)init {
    if (self = [super init]) {
        self.device = [UIDevice currentDevice];
        [self.device setBatteryMonitoringEnabled:YES];
    }
    return self;
}

- (int)update {
    if (buffer != nil)
        return 0;

    NSInteger state = [self.device batteryState];
    int batLeft = (int)([self.device batteryLevel] * 100);

    NSString *stringStates[4] = {@"Unknown", @"Unplugged", @"Charging", @"Full"};

    NSString *stringState = stringStates[state];

    NSString *output = [NSString stringWithFormat:@"%d%% %@\n", batLeft, stringState];
    buffer = [output dataUsingEncoding:NSUTF8StringEncoding];
    bufferOffset = 0;
    return 0;
}

@end

DEFINE_SIMPLE_READ_DEV_OPS(BatteryFile, battery)
