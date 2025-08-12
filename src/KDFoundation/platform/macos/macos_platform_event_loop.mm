/*
  This file is part of KDUtils.

  SPDX-FileCopyrightText: 2018 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
  Author: Paul Lemire <paul.lemire@kdab.com>

  SPDX-License-Identifier: MIT

  Contact KDAB at <info@kdab.com> for commercial licensing options.
*/

#include "macos_platform_event_loop.h"
#include "macos_platform_timer.h"

#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>

#include <limits>
#include <memory>

namespace KDFoundation {

MacOSPlatformEventLoop::MacOSPlatformEventLoop()
{
    // No longer restrict to main thread. CFRunLoop works on any thread.
}

MacOSPlatformEventLoop::~MacOSPlatformEventLoop() = default;

void MacOSPlatformEventLoop::waitForEventsImpl(int timeout)
{
    // Use CFRunLoopRunInMode for thread-safe event loop
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFStringRef mode = kCFRunLoopDefaultMode;

    double seconds;
    if (timeout == -1)
        seconds = 1.0e10; // Effectively infinite
    else if (timeout == 0)
        seconds = 0.0;
    else
        seconds = static_cast<double>(timeout) / 1000.0;

    CFRunLoopRunInMode(mode, seconds, true);
}

void MacOSPlatformEventLoop::wakeUp()
{
    // Wake up the run loop for the current thread
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFRunLoopWakeUp(runLoop);
}

bool MacOSPlatformEventLoop::registerNotifier(FileDescriptorNotifier * /* notifier */)
{
    // TODO
    return false;
}

bool MacOSPlatformEventLoop::unregisterNotifier(FileDescriptorNotifier * /* notifier */)
{
    // TODO
    return false;
}

std::unique_ptr<AbstractPlatformTimer> MacOSPlatformEventLoop::createPlatformTimerImpl(Timer *timer)
{
    return std::make_unique<MacOSPlatformTimer>(timer);
}

} // namespace KDFoundation
