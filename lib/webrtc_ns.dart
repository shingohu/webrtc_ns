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
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final WebrtcNsBindings _bindings = WebrtcNsBindings(_dylib);

enum NSLevel { Low, Moderate, High, VeryHigh }

class WebrtcNS {
  final Pointer<Void> _nullptr = Pointer.fromAddress(0);

  Pointer<Void>? _handle;

  bool get _hasInit => _handle != null && _handle != _nullptr;

  ///初始化
  ///[sampleRate]音频数据采样率
  ///[level]降噪级别,默认为High
  void init(int sampleRate, {NSLevel level = NSLevel.High}) {
    release();
    _handle = _bindings.webrtc_ns_init(sampleRate, level.index);
  }

  ///释放
  void release() {
    if (_hasInit) {
      _bindings.webrtc_ns_destroy(_handle!);
      _handle = null;
    }
  }

  ///处理byte数组,如果没有初始化,或者处理失败返回原始数据
  ///如果处理成功 返回处理后的数据
  Uint8List process(Uint8List bytes) {
    if (_hasInit) {
      return ffi.using((arena) {
        Int16List shorts = _bytesToShort(bytes);
        int length = shorts.length;
        final ptr = arena<Int16>(length);
        ptr.asTypedList(length).setAll(0, shorts);
        int ret = _bindings.webrtc_ns_process(_handle!, ptr, length);
        if (ret == 0) {
          return _shortToBytes(ptr.asTypedList(length));
        } else {
          return bytes;
        }
      });
    }
    return bytes;
  }

  static Int16List _bytesToShort(Uint8List bytes) {
    Int16List shorts = Int16List(bytes.length ~/ 2);
    for (int i = 0; i < shorts.length; i++) {
      shorts[i] = (bytes[i * 2] & 0xff | ((bytes[i * 2 + 1] & 0xff) << 8));
    }
    return shorts;
  }

  static Uint8List _shortToBytes(Int16List shorts) {
    Uint8List bytes = Uint8List(shorts.length * 2);
    for (int i = 0; i < shorts.length; i++) {
      bytes[i * 2] = (shorts[i] & 0xff);
      bytes[i * 2 + 1] = (shorts[i] >> 8 & 0xff);
    }
    return bytes;
  }
}
