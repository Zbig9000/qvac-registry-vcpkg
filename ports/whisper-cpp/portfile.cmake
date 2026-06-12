# whisper-cpp: pinned at tetherto/qvac-ext-lib-whisper.cpp@master HEAD
# 1c75d6e9 (QVAC-19253 Supertonic + Chatterbox on Adreno-Vulkan, PR #41). We
# move this port together with parakeet-cpp and tts-cpp so all three registry
# ports source the same master commit and the same archive SHA512.
#
vcpkg_from_github(
  OUT_SOURCE_PATH SOURCE_PATH
  REPO tetherto/qvac-ext-lib-whisper.cpp
  REF 1c75d6e9d5f07a50d6b0e8b6cff48444df4594b3
  SHA512 bd74d7831f3fdaad9bc5e366662e8c49a847db3ed7f66c4a8a94c10f1f7eee7c8fea58f91f1c8bc43da3ef64e1a4510aef6e376b5c7242711e256e14701f9e07
  HEAD_REF master
  PATCHES
    patches/0001-move-gnuinstalldirs-before-add-subdirectory-src.patch
)

# whisper-cpp consumes the system-installed ggml provided by the `ggml-speech`
# port (same shape as the `parakeet-cpp` and `tts-cpp` ports). Backend
# selection, Android dynamic-backend packaging, Vulkan-Headers download,
# spirv-headers include shim, per-arch CPU variants and the
# libqvac-speech-ggml-* filename prefix are all owned by `ggml-speech`; this
# port only carries whisper-specific build options and links against the
# installed ggml via `find_package(ggml)` (gated by WHISPER_USE_SYSTEM_GGML).
#
# Per-feature wiring lives in vcpkg.json:
#   whisper-cpp[metal]  -> ggml-speech[metal]   (osx | ios)
#   whisper-cpp[vulkan] -> ggml-speech[vulkan]  (linux | windows | android)
#   whisper-cpp[opencl] -> ggml-speech[opencl]  (android)
# so consumers express the full GPU matrix declaratively.

vcpkg_cmake_configure(
  SOURCE_PATH "${SOURCE_PATH}"
  DISABLE_PARALLEL_CONFIGURE
  OPTIONS
    -DWHISPER_USE_SYSTEM_GGML=ON
    -DWHISPER_BUILD_TESTS=OFF
    -DWHISPER_BUILD_EXAMPLES=OFF
    -DWHISPER_BUILD_SERVER=OFF
    -DBUILD_SHARED_LIBS=OFF
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

# whisper-cpp itself produces no shared libraries when BUILD_SHARED_LIBS=OFF.
# The ggml backend .so files (Android dynamic-backend mode) are installed by
# the ggml-speech port into ${VCPKG_INSTALLED_DIR}/<triplet>/lib/, not by us.
if (VCPKG_LIBRARY_LINKAGE MATCHES "static")
  file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin")
  file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/bin")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
