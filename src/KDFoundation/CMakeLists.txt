# This file is part of KDUtils.
#
# SPDX-FileCopyrightText: 2021 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
# Author: Paul Lemire <paul.lemire@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# Contact KDAB at <info@kdab.com> for commercial licensing options.
#

find_package(Threads)

set(SOURCES
    core_application.cpp
    event_receiver.cpp
    event.cpp
    file_descriptor_notifier.cpp
    object.cpp
    postman.cpp
    timer.cpp
    platform/abstract_platform_event_loop.cpp
)

set(HEADERS
    constexpr_sort.h
    core_application.h
    destruction_helpers.h
    event_queue.h
    event_receiver.h
    event.h
    file_descriptor_notifier.h
    formatters.h
    hashutils.h
    kdfoundation_global.h
    logging.h
    object.h
    postman.h
    timer.h
    utils.h
    vector_helper.h
    platform/abstract_platform_event_loop.h
    platform/abstract_platform_integration.h
    platform/abstract_platform_timer.h
)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    list(
        APPEND
        SOURCES
        platform/linux/linux_platform_event_loop.cpp
        platform/linux/linux_platform_integration.cpp
        platform/linux/linux_platform_timer.cpp
    )
    list(
        APPEND
        HEADERS
        platform/linux/linux_platform_event_loop.h
        platform/linux/linux_platform_integration.h
        platform/linux/linux_platform_timer.h
    )
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    list(
        APPEND
        SOURCES
        platform/win32/win32_platform_event_loop.cpp
        platform/win32/win32_platform_integration.cpp
        platform/win32/win32_platform_timer.cpp
    )
    list(
        APPEND
        HEADERS
        platform/win32/win32_platform_event_loop.h
        platform/win32/win32_platform_integration.h
        platform/win32/win32_platform_timer.h
    )
    set_source_files_properties(core_application.cpp PROPERTIES COMPILE_DEFINITIONS _CRT_SECURE_NO_WARNINGS)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    list(
        APPEND
        SOURCES
        platform/macos/macos_platform_event_loop.mm
        platform/macos/macos_platform_event_loop.h
        platform/macos/macos_platform_integration.mm
        platform/macos/macos_platform_integration.h
        platform/macos/macos_platform_timer.mm
        platform/macos/macos_platform_timer.h
    )
endif()

add_library(
    KDFoundation
    ${SOURCES} ${HEADERS}
)
add_library(
    KDUtils::KDFoundation ALIAS KDFoundation
)

target_link_libraries(
    KDFoundation
    PUBLIC KDUtils::KDUtils KDAB::KDBindings
)

if(CMAKE_SYSTEM_NAME STREQUAL "Android")
    target_compile_definitions(KDFoundation PRIVATE PLATFORM_ANDROID)
    set(PLATFORM_NAME "PLATFORM_ANDROID")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_compile_definitions(KDFoundation PRIVATE PLATFORM_LINUX)
    set(PLATFORM_NAME "PLATFORM_LINUX")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    target_compile_definitions(KDFoundation PRIVATE PLATFORM_WIN32)
    target_compile_definitions(KDFoundation PRIVATE UNICODE)
    target_link_libraries(KDFoundation PRIVATE ws2_32)
    set(PLATFORM_NAME "PLATFORM_WIN32")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    target_link_libraries(KDFoundation PUBLIC "-framework Cocoa" "-framework QuartzCore")
    target_compile_definitions(KDFoundation PRIVATE PLATFORM_MACOS)
    set(PLATFORM_NAME "PLATFORM_MACOS")
endif()

# Require >=C++17 for us and downstream projects
target_compile_features(KDFoundation PUBLIC cxx_std_17)

target_include_directories(
    KDFoundation
    PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../..> $<INSTALL_INTERFACE:include>
)
target_include_directories(
    KDFoundation
    PUBLIC $<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/include>
)

#
# Logging configuration
#
# Compile out some of the SPDLOG macros based on build type
target_compile_definitions(
    KDFoundation PRIVATE SPDLOG_ACTIVE_LEVEL=$<IF:$<CONFIG:Debug>,SPDLOG_LEVEL_TRACE,SPDLOG_LEVEL_WARN>
)
target_link_libraries(
    KDFoundation
    PRIVATE spdlog::spdlog
)

generate_export_header(KDFoundation BASE_NAME kdfoundation)
configure_file(
    ${CMAKE_CURRENT_BINARY_DIR}/kdfoundation_export.h ${CMAKE_BINARY_DIR}/include/KDFoundation/kdfoundation_export.h
)
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/config.h ${CMAKE_BINARY_DIR}/include/KDFoundation/config.h)
install(
    FILES ${CMAKE_CURRENT_BINARY_DIR}/kdfoundation_export.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/KDFoundation
)
install(
    FILES ${CMAKE_BINARY_DIR}/include/KDFoundation/config.h
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/KDFoundation
)

if(KDUTILS_CODE_COVERAGE)
    append_coverage_compiler_flags()
endif()

# add_library(Core INTERFACE)
# target_link_libraries(Core INTERFACE kdfoundation)
foreach(file ${HEADERS})
    get_filename_component(dir ${file} DIRECTORY)
    install(FILES ${file} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/KDFoundation/${dir})
endforeach()

set(project_config_in "${CMAKE_CURRENT_LIST_DIR}/cmake/KDFoundationConfig.cmake.in")
set(project_config_out "${CMAKE_CURRENT_BINARY_DIR}/KDFoundationConfig.cmake")

install(
    TARGETS KDFoundation
    EXPORT KDFoundation
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(
    EXPORT KDFoundation
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/KDFoundation
    NAMESPACE KDUtils::
    FILE KDFoundationConfigTargets.cmake
)
include(CMakePackageConfigHelpers)
configure_file("${project_config_in}" "${project_config_out}" @ONLY)
install(
    FILES "${project_config_out}"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/KDFoundation
)
install(
    FILES ${HEADERS}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/KDFoundation
)
