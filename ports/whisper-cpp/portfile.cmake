
# TEMPORARY (QVAC-18991 validation): pin to Zbig9000 fork's PR #25 HEAD
# (https://github.com/tetherto/qvac-ext-lib-whisper.cpp/pull/25) so the
# transcription-whispercpp CI can validate the upstream-sync content
# (whisper.cpp v1.8.4.3 + tetherto/master post-divergence merge + VAD
# streaming regression test) on its own, in isolation from QVAC-18300 /
# 18992 / 18993.
#
# After PR #25 merges and a v1.8.4.3 tag is published, REF flips to
# `v${VERSION}` against `tetherto/qvac-ext-lib-whisper.cpp` (no SHA512
# recompute needed if the tag matches PR #25's HEAD).
vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO Zbig9000/qvac-ext-lib-whisper.cpp
  REF 47784b9e00dcf1068f334bb30a4b8e89f8875f52
  SHA512 88fcfe1920a5530d3b5b2156e0ba2bf772d5abb1ba138654d724d09c8bcb79f166b050e763f0f1ff839930baf2f6c00f6ae6e715f5a046d529debb0558b3d020
  HEAD_REF QVAC-18991-pull-latest-whisper-cpp-upstream
)

if (VCPKG_TARGET_IS_ANDROID)
  # NDK only comes with C headers.
  # Make sure C++ header exists, it will be used by ggml tensor library.
  # Need to determine installed vulkan version and download correct headers
  include(${CMAKE_CURRENT_LIST_DIR}/android-vulkan-version.cmake)
  detect_ndk_vulkan_version()
  message(STATUS "Using Vulkan C++ wrappers from version: ${vulkan_version}")
  file(DOWNLOAD
    "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/v${vulkan_version}.tar.gz"
    "${SOURCE_PATH}/vulkan-sdk-${vulkan_version}.tar.gz"
    TLS_VERIFY ON
  )

  file(ARCHIVE_EXTRACT
    INPUT "${SOURCE_PATH}/vulkan-sdk-${vulkan_version}.tar.gz"
    DESTINATION "${SOURCE_PATH}"
  )

  # Copy the Vulkan headers to where the build system expects them
  # The build system looks for vulkan/vulkan.hpp with include path pointing to ggml/src/
  file(COPY "${SOURCE_PATH}/Vulkan-Headers-${vulkan_version}/include/"
       DESTINATION "${SOURCE_PATH}/ggml/src/")
  
  # Clean up the temporary extracted directory
  file(REMOVE_RECURSE "${SOURCE_PATH}/Vulkan-Headers-${vulkan_version}")
endif()

set(PLATFORM_OPTIONS)

if (VCPKG_TARGET_IS_OSX)
  list(APPEND PLATFORM_OPTIONS -DGGML_METAL=ON)
elseif (VCPKG_TARGET_IS_IOS)
  # Intentionally NOT -DGGML_METAL=ON. iOS bare-kit builds were hitting
  # a separate Metal/Compiler XPC crash during transcribe() on physical
  # iPhone (XPC_ERROR_CONNECTION_INTERRUPTED / MTLCompiler peer-unloaded)
  # that is being investigated independently of the OutputCallBackJs
  # teardown UAF. Force the flag OFF so it overrides any upstream default
  # and stays explicit in the build log; iOS falls back to the CPU
  # backend until the Metal-side issue is fixed.
  list(APPEND PLATFORM_OPTIONS -DGGML_METAL=OFF)
elseif("vulkan" IN_LIST FEATURES)
  list(APPEND PLATFORM_OPTIONS -DGGML_VULKAN=ON)
else()
  list(APPEND PLATFORM_OPTIONS -DGGML_VULKAN=OFF)
endif()

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  DISABLE_PARALLEL_CONFIGURE
  OPTIONS
    -DGGML_CCACHE=OFF
    -DGGML_OPENMP=OFF
    -DGGML_NATIVE=OFF
    -DWHISPER_BUILD_TESTS=OFF
    -DWHISPER_BUILD_EXAMPLES=OFF
    -DWHISPER_BUILD_SERVER=OFF
    -DBUILD_SHARED_LIBS=OFF
    -DGGML_BUILD_NUMBER=1
    ${PLATFORM_OPTIONS}
)

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(
  PACKAGE_NAME whisper
  CONFIG_PATH share/whisper
)

vcpkg_fixup_pkgconfig()

vcpkg_copy_pdbs()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

if (VCPKG_LIBRARY_LINKAGE MATCHES "static")
  file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin")
  file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/bin")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")