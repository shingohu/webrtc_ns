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
    if (_hasInit) {
      _ensureBuffer(sampleRate ~/ 50); // typical 20ms frame
    }
  }

  void release() {
    if (_hasInit) {
      _bindings.webrtc_ns_destroy(_handle!);
      _handle = null;
    }
    if (_buffer != null) {
      ffi.calloc.free(_buffer!);
      _buffer = null;
      _bufferSamples = 0;
    }
  }

  void _ensureBuffer(int samples) {
    if (_bufferSamples >= samples) return;
    if (_buffer != null) {
      ffi.calloc.free(_buffer!);
    }
    _buffer = ffi.calloc<Int16>(samples);
    _bufferSamples = samples;
  }

  /// Processes PCM data in-place. Zero allocations after warm-up.
  ///
  /// [pcmData] is interleaved 16-bit little-endian PCM. The processed audio
  /// overwrites the input buffer. Returns true on success, false if not
  /// initialized or processing failed.
  bool processInPlace(Uint8List pcmData) {
    if (!_hasInit) return false;

    final int samples = pcmData.length ~/ 2;
    _ensureBuffer(samples);

    // Zero-copy view of input as Int16
    final Int16List input =
        pcmData.buffer.asInt16List(pcmData.offsetInBytes, samples);
    final Int16List native = _buffer!.asTypedList(samples);

    // Copy to pre-allocated native buffer
    native.setAll(0, input);

    final int ret = _bindings.webrtc_ns_process(_handle!, _buffer!, samples);
    if (ret != 0) return false;

    // Copy processed data back to the input buffer
    final Uint8List nativeBytes =
        Uint8List.view(native.buffer, 0, pcmData.length);
    pcmData.setAll(0, nativeBytes);
    return true;
  }

  /// Processes PCM bytes and returns processed data.
  /// Prefer [processInPlace] for real-time audio to avoid allocations.
  Uint8List process(Uint8List bytes) {
    if (!_hasInit) return bytes;

    final Uint8List copy = Uint8List.fromList(bytes);
    if (processInPlace(copy)) {
      return copy;
    }
    return bytes;
  }
}
