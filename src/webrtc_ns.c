#include "webrtc_ns.h"
#include "noise_suppression.h"


FFI_PLUGIN_EXPORT void *webrtc_ns_init(int sample_rate, int level) {
    NsHandle *nsHandle = WebRtcNs_Create();
    int ret = WebRtcNs_Init(nsHandle, sample_rate);
    if (ret != 0) {
        WebRtcNs_Free(nsHandle);
        return NULL;
    }
    ret = WebRtcNs_set_policy(nsHandle, level);
    if (ret != 0) {
        WebRtcNs_Free(nsHandle);
        return NULL;
    }
    return nsHandle;
}

FFI_PLUGIN_EXPORT void webrtc_ns_destroy(void *handle) {
    if (handle != NULL) {
        WebRtcNs_Free(handle);
        handle = NULL;
    }
}


FFI_PLUGIN_EXPORT int webrtc_ns_process(void *handle, int16_t *src_audio_data, int64_t length) {
    if (handle != NULL) {
        NoiseSuppressionC *ns = (NoiseSuppressionC *) handle;

        //noise suppression
        size_t blockLen = ns->blockLen;
        size_t num_bands = 1;

        int16_t *input = src_audio_data;
        int64_t totalLength = length;
        size_t nTotal = (totalLength / blockLen);
        for (int i = 0; i < nTotal; i++) {
            int16_t *nsIn[1] = {input};   //ns input[band][data]
            int16_t *nsOut[1] = {input};  //ns output[band][data]
            WebRtcNs_Analyze(handle, nsIn[0]);
            WebRtcNs_Process(handle, (const int16_t *const *) nsIn, num_bands, nsOut);
            input += blockLen;
        }
        return 0;
    }
    return -1;
}