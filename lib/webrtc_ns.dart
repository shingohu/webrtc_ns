import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as ffi;

import 'webrtc_ns_bindings_generated.dart';

const String _libName = 'webrtc_ns';

/// The dynamic library in which the symbols for [WebrtcNsBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.operatingSystem == "ohos") {
    return DynamicLibrary.open('lib$_libName.so');
  }

  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final WebrtcNsBindings _bindings = WebrtcNsBindings(_dylib);

enum NSLevel { Low, Moderate, High, VeryHigh }

final class WebrtcNS {
  final Pointer<Void> _nullptr = Pointer.fromAddress(0);

  Pointer<Void>? _handle;

  /// Pre-allocated reusable native buffer for process() calls.
  Pointer<Int16>? _buffer;
  int _bufferSamples = 0;

  bool get _hasInit => _handle != null && _handle != _nullptr;

  void init(int sampleRate, {NSLevel level = NSLevel.High}) {
    release();
    _handle = _bindings.webrtc_ns_init(sampleRate, level.index);
  }

  void release() {
    if (_hasInit) {
      _bindings.webrtc_ns_destroy(_handle!);
      _handle = null;
    }
    freeBuffer();
  }

  ///预分配内存
  void _ensureBuffer(int samples) {
    if (_bufferSamples == samples && _buffer != null) return;
    if (_buffer != null) {
      ffi.malloc.free(_buffer!);
    }
    _buffer = ffi.malloc<Int16>(samples);
    _bufferSamples = samples;
  }

  ///释放预分配内存
  void freeBuffer() {
    if (_buffer != null) {
      ffi.malloc.free(_buffer!);
      _buffer = null;
      _bufferSamples = 0;
    }
  }

  /// 处理PCM数据并返回处理后的数据
  /// 注意由于webrtc ns每次只能处理10ms数据,所有这里需要传入的数据长度至少是10ms的倍数
  Uint8List process(Uint8List pcmData) {
    if (!_hasInit) return pcmData;
    final int samples = pcmData.length ~/ 2;
    if (samples == 0) {
      return pcmData;
    }
    _ensureBuffer(samples);
    Uint8List copyData = Uint8List.fromList(pcmData);
    // Zero-copy view of input as Int16
    final Int16List input =
        copyData.buffer.asInt16List(copyData.offsetInBytes, samples);
    final Int16List native = _buffer!.asTypedList(samples);

    // Copy to pre-allocated native buffer
    native.setAll(0, input);

    final int ret = _bindings.webrtc_ns_process(_handle!, _buffer!, samples);
    if (ret != 0) {
      freeBuffer();
      return pcmData;
    }

    // Copy processed data back to the input buffer
    final Uint8List nativeBytes =
        Uint8List.view(native.buffer, 0, copyData.length);
    copyData.setAll(0, nativeBytes);
    return copyData;
  }
}
