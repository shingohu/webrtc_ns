#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else

#include <pthread.h>
#include <unistd.h>

#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

FFI_PLUGIN_EXPORT void *webrtc_ns_init(int sample_rate, int level);

FFI_PLUGIN_EXPORT int webrtc_ns_process(void *handle, int16_t *src_audio_data, int64_t length);

FFI_PLUGIN_EXPORT void webrtc_ns_destroy(void *handle);



