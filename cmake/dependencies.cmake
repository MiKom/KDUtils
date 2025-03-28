# This file is part of KDUtils.
#
# SPDX-FileCopyrightText: 2021 Klarälvdalens Datakonsult AB, a KDAB Group company <info@kdab.com>
# Author: Paul Lemire <paul.lemire@kdab.com>
#
# SPDX-License-Identifier: MIT
#
# Contact KDAB at <info@kdab.com> for commercial licensing options.
#

include(FetchContent)

message(STATUS "Looking for KDUtils dependencies")

# spdlog Logging Library
# spdlog needs to be installed. If already exists in the prefix,
# we don't want to override it, so first we try to find it.
# If we don't find it, then we fetch it and install it
find_package(spdlog 1.14.1 QUIET)

if(NOT TARGET spdlog::spdlog)
    # We need to use external fmt because the one bundled with spldog 1.x throws
    # warnings in newer Visual Studio MSVC compiler versions.
    # See https://github.com/gabime/spdlog/issues/2912
    # TODO(spdlog2): external fmt can possibly be removed once splog 2.x is used
    # which bundles newer fmt version
    find_package(fmt 10.2.1 QUIET)
    if(NOT TARGET fmt)
        FetchContent_Declare(
            fmt
            GIT_REPOSITORY https://github.com/fmtlib/fmt.git
            GIT_TAG e69e5f977d458f2650bb346dadf2ad30c5320281 # 10.2.1
        )
        FetchContent_MakeAvailable(fmt)
        set_target_properties(fmt PROPERTIES CXX_CLANG_TIDY "")
    endif()
    set(SPDLOG_FMT_EXTERNAL_HO ON)
    # with this spdlog is included as a system library and won't e.g. trigger
    # linter warnings
    set(SPDLOG_SYSTEM_INCLUDES ON)

    get_property(tmp GLOBAL PROPERTY PACKAGES_NOT_FOUND)
    list(
        FILTER
        tmp
        EXCLUDE
        REGEX
        spdlog
    )
    set_property(GLOBAL PROPERTY PACKAGES_NOT_FOUND ${tmp})

    FetchContent_Declare(
        spdlog
        GIT_REPOSITORY https://github.com/gabime/spdlog.git
        GIT_TAG 27cb4c76708608465c413f6d0e6b8d99a4d84302 # v1.14.1
    )
    set(SPDLOG_INSTALL
        ON
        CACHE BOOL "Install spdlog" FORCE
    )
    FetchContent_MakeAvailable(spdlog)

    set_target_properties(
        spdlog
        PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
                   LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
                   RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    )
endif()

# KDBindings library
find_package(KDBindings QUIET)
if(NOT TARGET KDAB::KDBindings)
    fetchcontent_declare(
        KDBindings
        GIT_REPOSITORY https://github.com/KDAB/KDBindings.git
        GIT_TAG efb54c58c3c2fce280d7089617935ec265fe4e2d # v1.1.0
        USES_TERMINAL_DOWNLOAD YES USES_TERMINAL_UPDATE YES
    )
    fetchcontent_makeavailable(KDBindings)
endif()

# whereami library
find_package(Whereami QUIET)
if(NOT TARGET whereami::whereami)
    fetchcontent_declare(
        whereami
        GIT_REPOSITORY https://github.com/gpakosz/whereami
        GIT_TAG e4b7ba1be0e9fd60728acbdd418bc7195cdd37e7 # master at 5/July/2021
    )
    fetchcontent_makeavailable(whereami)
endif()

# mio header-only lib (provides memory mapping for files)
find_package(mio QUIET)
if(NOT TARGET mio::mio)
    fetchcontent_declare(
        mio
        GIT_REPOSITORY https://github.com/mandreyel/mio.git
        GIT_TAG 8b6b7d878c89e81614d05edca7936de41ccdd2da # March 3rd 2023
    )
    fetchcontent_makeavailable(mio)
endif()

# mosquitto library
find_package(Mosquitto QUIET)
