/*
  This file is part of KDUtils.

  SPDX-FileCopyrightText: 2024 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
  Author: Miłosz Kosobucki <milosz.kosobucki@kdab.com>

  SPDX-License-Identifier: MIT

  Contact KDAB at <info@kdab.com> for commercial licensing options.
*/
#include <KDFoundation/core_application.h>
#include <KDFoundation/file_descriptor_notifier.h>

#ifdef WIN32
#include <WinSock2.h>
#include <WS2tcpip.h>
#else
#include <sys/socket.h>
#include <arpa/inet.h>
#include <errno.h>
#include <unistd.h>

static constexpr int INVALID_SOCKET = -1;
static constexpr int SOCKET_ERROR = -1;

using SOCKET = int;

int WSAGetLastError()
{
    return errno;
}

int closesocket(int sock)
{
    return close(sock);
}
#endif

int main()
{
    KDFoundation::CoreApplication app;

#ifdef WIN32
    WSAData wsaData;
    const auto ret = WSAStartup(MAKEWORD(2, 2), &wsaData);
#endif
    const std::string dataToSend("KDFoundation");
    std::string dataReceived;

    std::mutex mutex;
    std::condition_variable cond;
    bool ready = false;

    const uint16_t port = 1337;

    auto serverFunction = [&mutex, &cond, &ready, &dataToSend, &port]() {
        const SOCKET serverSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (serverSocket == INVALID_SOCKET) {
            SPDLOG_ERROR("Cannot create server socket");
        }
        sockaddr_in ad;
        ad.sin_family = AF_INET;
        ad.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        ad.sin_port = htons(port);

        int ret = 0;
        ret = bind(serverSocket, reinterpret_cast<sockaddr *>(&ad), sizeof(ad));

        if (ret == -1) {
            SPDLOG_ERROR("server: cannot bind to port {}", port);
        }

        SPDLOG_INFO("server: listening on port {}", port);

        ret = listen(serverSocket, SOMAXCONN);
        if (ret == SOCKET_ERROR) {
            SPDLOG_ERROR("Listen error: {}", WSAGetLastError());
        }

        // Send info to the client that we're ready
        {
            const std::lock_guard lk(mutex);
            ready = true;
            cond.notify_all();
        }

        auto clientSocket = accept(serverSocket, nullptr, nullptr);
        closesocket(serverSocket);

        if (clientSocket != INVALID_SOCKET) {
            std::array<char, 128> buf;
            for (int i = 0; i < 125; i++) {
                snprintf(buf.data(), buf.size() - 1, "KDFoundation %d\0", i);
                ret = send(clientSocket, buf.data(), buf.size(), 0);
                SPDLOG_INFO("Server sent {} bytes", ret);
                std::this_thread::sleep_for(std::chrono::milliseconds(200));
            }
            if (ret != SOCKET_ERROR) {
                SPDLOG_INFO("Server sent {} bytes", ret);
            } else {
                SPDLOG_ERROR("Error while sending data: {}", WSAGetLastError());
            }
            closesocket(clientSocket);
        } else {
            SPDLOG_ERROR("invalid socket from accept");
        }
    };
    // Start the server
    std::thread serverThread(serverFunction);

    // Wait until the server is ready for connection
    {
        std::unique_lock lk(mutex);
        cond.wait(lk, [&]() { return ready; });
    }

    SOCKET clientSock = INVALID_SOCKET; // NOLINT(modernize-use-auto)
    clientSock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

    // Set up read notifier to receive the data
    KDFoundation::FileDescriptorNotifier readNotifier(static_cast<int>(clientSock), KDFoundation::FileDescriptorNotifier::NotificationType::Read);
    KDBindings::ConnectionHandle readConnection = readNotifier.triggered.connect([&dataReceived, &readConnection](int fd) {
        std::array<char, 128> buf = {};
        const int recvSize = recv(fd, buf.data(), buf.size(), 0);
        dataReceived = std::string(buf.data());
        SPDLOG_INFO("socket test: received {} bytes from the server: {}", recvSize, dataReceived);
    });

    sockaddr_in add;
    add.sin_family = AF_INET;
    add.sin_port = htons(port);
    add.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    // We expect failure here. We're calling connect on an async socket so it should fail with
    // WOULDBLOCK.
    const auto rc = connect(clientSock, reinterpret_cast<sockaddr *>(&add), sizeof(add));

    app.exec();
}
