# This file is part of KDUtils.
#
# SPDX-FileCopyrightText: 2022 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# Contact KDAB at <info@kdab.com> for commercial licensing options.
#

add_subdirectory(gui_window)

if(KDUTILS_BUILD_MQTT_SUPPORT)
    file(DOWNLOAD https://test.mosquitto.org/ssl/mosquitto.org.crt ${CMAKE_BINARY_DIR}/mosquitto.org.crt)
    add_subdirectory(mqtt_client)
endif()
