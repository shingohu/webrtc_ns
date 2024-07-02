# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(webrtc_ns_library VERSION 0.0.1 LANGUAGES C)

add_library(webrtc_ns SHARED
        "webrtc_ns.c"
        "noise_suppression.c"
        )

set_target_properties(webrtc_ns PROPERTIES
        PUBLIC_HEADER webrtc_ns.h
        OUTPUT_NAME "webrtc_ns"
        )

target_compile_definitions(webrtc_ns PUBLIC DART_SHARED_LIB)
