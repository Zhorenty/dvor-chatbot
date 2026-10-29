import 'package:dvor_miniapp/core/media/image_picker.dart';

/// Tests and non-web builds: no picker.
Future<PickedImage?> pickImage({required int maxSide}) async => null;
