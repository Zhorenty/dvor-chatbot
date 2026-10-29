import 'dart:async';
import 'dart:js_interop';

import 'package:dvor_miniapp/core/media/image_picker.dart';
import 'package:web/web.dart' as web;

Future<PickedImage?> pickImage({required int maxSide}) {
  final completer = Completer<PickedImage?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*';
  void finish(PickedImage? image) {
    if (!completer.isCompleted) {
      completer.complete(image);
    }
  }

  input.onchange = (web.Event _) {
    final file = input.files?.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    _read(file, maxSide).then(finish, onError: (Object _) => finish(null));
  }.toJS;
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return completer.future;
}

Future<PickedImage> _read(web.File file, int maxSide) async {
  final original = (await file.arrayBuffer().toDart).toDart.asUint8List();
  try {
    final bitmap = await web.window.createImageBitmap(file).toDart;
    final longest = bitmap.width > bitmap.height ? bitmap.width : bitmap.height;
    if (longest <= maxSide && original.length < 1500 * 1024) {
      return PickedImage(name: file.name, bytes: original);
    }
    final scale = longest > maxSide ? maxSide / longest : 1.0;
    final canvas = web.HTMLCanvasElement()
      ..width = (bitmap.width * scale).round()
      ..height = (bitmap.height * scale).round();
    final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    final blob = Completer<web.Blob?>();
    canvas.toBlob(((web.Blob? b) => blob.complete(b)).toJS, 'image/jpeg', 0.85.toJS);
    final jpeg = await blob.future;
    if (jpeg == null) {
      return PickedImage(name: file.name, bytes: original);
    }
    final bytes = (await jpeg.arrayBuffer().toDart).toDart.asUint8List();
    return PickedImage(name: 'receipt.jpg', bytes: bytes);
  } on Object {
    // Decoding failed (HEIC on some browsers): send the original.
    return PickedImage(name: file.name, bytes: original);
  }
}
