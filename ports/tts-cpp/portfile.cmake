# tts-cpp: Resemble Chatterbox + Supertonic + CosyVoice3 + Parler-TTS + Audio8
# in pure C++/ggml, from the engines/tts subfolder of qvac-ext-lib-whisper.cpp;
# consumes the ggml-speech port.
#
# [TTS GGML] Audio8 TTS on CPU
# (qvac-ext-lib-whisper.cpp PR #128): a DualAR zero-shot model -- a
# Qwen2.5-shaped 24-layer AR emits one semantic token per 21.5 Hz frame, a
# 4-layer fast AR expands each into the frame's remaining nine codebooks, and a
# DAC-style codec synthesises 44.1 kHz audio. Text to speech and voice cloning
# both run in this process: the codec's analysis half is ported too, so a caller
# hands the engine a reference wav rather than codes computed elsewhere. It
# ships as three GGUFs -- language model, codec decoder, codec encoder -- whose
# lifetimes differ, so a text-only deployment can omit the encoder.
#   The codec runs in blocks in both directions. Its convolution stacks work at
#   the sample rate, so their activations, not the language model, are what made
#   memory grow with utterance length: a 24 s decode needed a 1.5 GB arena and
#   now needs ~150 MB, encode ~443 MB and now ~72 MB. Each block is re-fed the
#   receptive field its stack needs and drops what that context produced, so the
#   result is identical to a single pass whatever the block size, and a cancel
#   is honoured at the next language model step or codec block.
#   Six CTest targets check the stages against fixtures dumped from the
#   checkpoint's own generate loop: tokenizer ids and the ChatML prompt, the
#   language model's per-step trajectory, the codec at every stage boundary in
#   both directions, the filtered score vectors, the repetition-aware window,
#   and both public paths end to end.
#   CPU-only in this release. New engine only: nothing existing changes shape,
#   and the ggml-speech floor stays at 2026-08-07.
#
# Pinned at master 09566de3 (PR #128). Relative to the previous tts-cpp pin
# 5e57a692 the tts subtree adds the Audio8 engine and nothing else, so
# whisper-cpp, parakeet-cpp and audiogen-cpp stay where they are: the only other
# commit in between touches two ACE-Step smoke executables (PR #127) and leaves
# every port's library sources byte-identical. The four re-align on one source
# archive at the next joint bump.

set(VCPKG_POLICY_MISMATCHED_NUMBER_OF_BINARIES enabled)
set(VCPKG_BUILD_TYPE release)

vcpkg_from_github(
    OUT_SOURCE_PATH WHISPER_CPP_SRC
    REPO tetherto/qvac-ext-lib-whisper.cpp
    REF 09566de32e48a2681d78ab442d51d083f4301fc7
    SHA512 556a18d2e1ff2102b5ba702a23fb2d3793591a0c02a57ce5a58de8567840ac5fa7b713b3aa58630f3161b0436c0b8ccf7394585383416a6995635d41fe41d5ea
    HEAD_REF master
)

set(SOURCE_PATH "${WHISPER_CPP_SRC}/engines/tts")
if (NOT EXISTS "${SOURCE_PATH}/CMakeLists.txt")
    message(FATAL_ERROR
        "tts-cpp: ${SOURCE_PATH}/CMakeLists.txt missing; the engines/tts/ "
        "subfolder layout in qvac-ext-lib-whisper.cpp may have changed.")
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        metal   GGML_METAL
        vulkan  GGML_VULKAN
        cuda    GGML_CUDA
        opencl  GGML_OPENCL
)

set(PLATFORM_OPTIONS)

if(NOT VCPKG_TARGET_IS_OSX)
    list(APPEND PLATFORM_OPTIONS
        -DGGML_BLAS=OFF
        -DGGML_ACCELERATE=OFF
        -DCMAKE_DISABLE_FIND_PACKAGE_BLAS=ON
    )
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE
    OPTIONS
        -DTTS_CPP_BUILD_LIBRARY=ON
        -DTTS_CPP_BUILD_SHARED=OFF
        -DTTS_CPP_BUILD_EXECUTABLES=OFF
        -DTTS_CPP_BUILD_TESTS=OFF
        -DTTS_CPP_INSTALL=ON
        -DTTS_CPP_USE_SYSTEM_GGML=ON
        -DBUILD_SHARED_LIBS=OFF
        -DGGML_NATIVE=OFF
        -DGGML_OPENMP=OFF
        -DTTS_CPP_OPENMP=OFF
        -DGGML_CCACHE=OFF
        -DTTS_CPP_CCACHE=OFF
        ${FEATURE_OPTIONS}
        ${PLATFORM_OPTIONS}
)

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(PACKAGE_NAME tts-cpp CONFIG_PATH share/tts-cpp)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

if (VCPKG_LIBRARY_LINKAGE MATCHES "static")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/bin")
endif()

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
