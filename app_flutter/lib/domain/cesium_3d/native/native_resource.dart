import 'dart:ffi';
import 'package:ffi/ffi.dart';

final _finalizer = NativeFinalizer(calloc.nativeFree);

final class NativeResource implements Finalizable {
  final Pointer<Void> pointer;
  final int sizeBytes;
  bool _isReleased = false;

  bool get isReleased => _isReleased;

  NativeResource._(this.pointer, this.sizeBytes) {
    _finalizer.attach(this, pointer, detach: this, externalSize: sizeBytes);
  }

  factory NativeResource.alloc(int count, int elementSize) {
    final ptr = calloc<Int8>(count * elementSize);
    return NativeResource._(ptr.cast(), count * elementSize);
  }

  void release() {
    if (_isReleased) return;
    _isReleased = true;
    _finalizer.detach(this);
    calloc.free(pointer);
  }
}
