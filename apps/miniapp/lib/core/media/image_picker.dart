import 'dart:typed_data';

import 'package:dvor_miniapp/core/media/image_picker_stub.dart'
    if (dart.library.js_interop) 'package:dvor_miniapp/core/media/image_picker_web.dart'
    as impl;

/// A photo chosen by the user, already downscaled for upload.
class PickedImage {
  const PickedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Opens the system photo picker. Returns null when the user cancels.
/// Large photos are re-encoded to JPEG with the long side ≤ [maxSide] px,
/// so receipts upload quickly over mobile networks.
Future<PickedImage?> pickImage({int maxSide = 1600}) => impl.pickImage(maxSide: maxSide);
