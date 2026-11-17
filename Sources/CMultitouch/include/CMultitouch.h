#ifndef HANDYTAB_MULTITOUCH_H
#define HANDYTAB_MULTITOUCH_H

#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>

// Private MultitouchSupport ABI, shared with the Swift adapter via Clang.
typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint position, velocity; } MTVector;
typedef struct {
    int32_t frame;
    double timestamp;
    int32_t identifier, state, fingerID, handID;
    MTVector normalizedVector;
    float total, pressure, angle, majorAxis, minorAxis;
    MTVector absoluteVector;
    int32_t unknown14, unknown15;
    float density;
} MTTouch;

typedef void *MTDeviceRef;
typedef void (*MTContactCallback)(MTDeviceRef, MTTouch *, int32_t, double, int32_t);

CFArrayRef MTDeviceCreateList(void) CF_RETURNS_RETAINED;
void MTDeviceStart(MTDeviceRef device, int32_t mode);
void MTDeviceStop(MTDeviceRef device);
void MTRegisterContactFrameCallback(MTDeviceRef device, MTContactCallback callback);
void MTUnregisterContactFrameCallback(MTDeviceRef device, MTContactCallback callback);

#endif
