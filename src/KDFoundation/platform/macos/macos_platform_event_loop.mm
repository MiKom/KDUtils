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

static void NotifierCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef, const void *info)
{
    auto *notifier = static_cast<FileDescriptorNotifier *>(const_cast<void *>(info));
    if (!notifier)
        return;
    // Only handle read events for now
    if (type == kCFSocketReadCallBack) {
        NotifierEvent ev;
        notifier->event(notifier, &ev);
    }
}

bool MacOSPlatformEventLoop::registerNotifier(FileDescriptorNotifier *notifier)
{
    if (!notifier)
        return false;
    int fd = notifier->fileDescriptor();
    if (m_notifiers.count(fd))
        return false;

    CFSocketContext context = {0, (void *)notifier, nullptr, nullptr, nullptr};
    CFSocketRef socketRef = CFSocketCreateWithNative(kCFAllocatorDefault, fd,
                                                    kCFSocketReadCallBack,
                                                    NotifierCallback,
                                                    &context);
    if (!socketRef)
        return false;

    CFRunLoopSourceRef sourceRef = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socketRef, 0);
    if (!sourceRef) {
        CFRelease(socketRef);
        return false;
    }
    CFRunLoopAddSource(CFRunLoopGetCurrent(), sourceRef, kCFRunLoopDefaultMode);

    m_notifiers[fd] = {notifier, socketRef, sourceRef};
    return true;
}

bool MacOSPlatformEventLoop::unregisterNotifier(FileDescriptorNotifier *notifier)
{
    if (!notifier)
        return false;
    int fd = notifier->fileDescriptor();
    auto it = m_notifiers.find(fd);
    if (it == m_notifiers.end())
        return false;

    if (it->second.sourceRef)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), it->second.sourceRef, kCFRunLoopDefaultMode);
    if (it->second.sourceRef)
        CFRelease(it->second.sourceRef);
    if (it->second.socketRef)
        CFRelease(it->second.socketRef);

    m_notifiers.erase(it);
    return true;
}

std::unique_ptr<AbstractPlatformTimer> MacOSPlatformEventLoop::createPlatformTimerImpl(Timer *timer)
{
    return std::make_unique<MacOSPlatformTimer>(timer);
}

} // namespace KDFoundation
