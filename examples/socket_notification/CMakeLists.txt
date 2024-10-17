# This file is part of KDUtils.
#
# SPDX-FileCopyrightText: 2024 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# Contact KDAB at <info@kdab.com> for commercial licensing options.
#

project(socket_notification_example LANGUAGES CXX)

add_executable(
    ${PROJECT_NAME}
    socket_notification.cpp
)

target_link_libraries(
    ${PROJECT_NAME} KDFoundation
)

if(WIN32)
    target_link_libraries(${PROJECT_NAME} ws2_32)
endif()