/*
  This file is part of KDUtils.

  SPDX-FileCopyrightText: 2018 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
  Author: Paul Lemire <paul.lemire@kdab.com>

  SPDX-License-Identifier: MIT

  Contact KDAB at <info@kdab.com> for commercial licensing options.
*/

#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest.h>

#include <KDFoundation/platform/macos/macos_platform_event_loop.h>
#include <KDFoundation/object.h>
#include <KDFoundation/file_descriptor_notifier.h>
#include <KDFoundation/postman.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

#include <KDUtils/logging.h>

#include <chrono>
#include <condition_variable>
#include <mutex>
#include <numeric>
#include <string>
#include <thread>

using namespace KDFoundation;

static_assert(std::is_destructible<MacOSPlatformEventLoop>{});
static_assert(std::is_default_constructible<MacOSPlatformEventLoop>{});
static_assert(!std::is_copy_constructible<MacOSPlatformEventLoop>{});
static_assert(!std::is_copy_assignable<MacOSPlatformEventLoop>{});
static_assert(!std::is_move_constructible<MacOSPlatformEventLoop>{});
static_assert(!std::is_move_assignable<MacOSPlatformEventLoop>{});

TEST_CASE("Wait for events")
{
    spdlog::set_level(spdlog::level::debug);

    SUBCASE("can poll for events (0ms timeout)")
    {
        MacOSPlatformEventLoop loop;
        loop.waitForEvents(0);
    }

    SUBCASE("can wait for events (100 ms timeout)")
    {
        MacOSPlatformEventLoop loop;
        loop.waitForEvents(100);
    }

    SUBCASE("can wake up by calling wakeUp from another thread")
    {
        MacOSPlatformEventLoop loop;

        // Spawn a thread to wake up the event loop
        std::mutex mutex;
        std::condition_variable cond;
        bool ready = false;
        auto callWakeUp = [&mutex, &cond, &ready, &loop]() {
            SPDLOG_INFO("Launched helper thread");
            std::unique_lock lock(mutex);
            cond.wait(lock, [&ready] { return ready == true; });
            SPDLOG_INFO("Thread going to sleep before waking up event loop");

            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            loop.wakeUp();
        };
        std::thread t1(callWakeUp);

        // Kick the thread off
        {
            SPDLOG_INFO("Waking up helper thread");
            std::unique_lock lock(mutex);
            ready = true;
            cond.notify_all();
        }

        const auto startTime = std::chrono::steady_clock::now();
        loop.waitForEvents(10000);
        const auto endTime = std::chrono::steady_clock::now();

        auto elapsedTime = std::chrono::duration_cast<std::chrono::milliseconds>(endTime - startTime).count();
        SPDLOG_INFO("elapsedTime = {}", elapsedTime);
        REQUIRE(elapsedTime < 10000);

        // Be nice!
        t1.join();
    }

    SUBCASE("can watch a socket for read events")
    {
        MacOSPlatformEventLoop loop;
        Postman postman;
        loop.setPostman(&postman);

        int sv[2];
        REQUIRE(socketpair(AF_UNIX, SOCK_STREAM, 0, sv) == 0);

        std::string dataToSend = "KDFoundation";
        std::string dataReceived;

        FileDescriptorNotifier readNotifier(sv[1], FileDescriptorNotifier::NotificationType::Read);
        std::ignore = readNotifier.triggered.connect([&dataReceived, &sv](int fd) {
            char buf[128] = {};
            ssize_t recvSize = read(fd, buf, sizeof(buf));
            dataReceived = std::string(buf, recvSize);
        });
        loop.registerNotifier(&readNotifier);

        // Write data from the other end
        REQUIRE(write(sv[0], dataToSend.c_str(), dataToSend.size()) == (ssize_t)dataToSend.size());

        loop.waitForEvents(1000);
        REQUIRE(dataReceived == dataToSend);

        close(sv[0]);
        close(sv[1]);
    }

    SUBCASE("can deregister notifier and not receive events")
    {
        MacOSPlatformEventLoop loop;
        Postman postman;
        loop.setPostman(&postman);

        int sv[2];
        REQUIRE(socketpair(AF_UNIX, SOCK_STREAM, 0, sv) == 0);

        int triggeredCount = 0;
        FileDescriptorNotifier notifier(sv[1], FileDescriptorNotifier::NotificationType::Read);
        std::ignore = notifier.triggered.connect([&triggeredCount](int) {
            triggeredCount++;
        });
        loop.registerNotifier(&notifier);
        loop.unregisterNotifier(&notifier);

        REQUIRE(write(sv[0], "test", 4) == 4);
        loop.waitForEvents(1000);
        REQUIRE(triggeredCount == 0);

        close(sv[0]);
        close(sv[1]);
    }
}
