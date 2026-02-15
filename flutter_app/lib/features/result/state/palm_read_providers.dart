import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/palm_reads_api.dart';
import '../domain/palm_read_models.dart';

final palmReadDetailProvider =
    FutureProvider.family<PalmReadDetail, String>((ref, id) async {
  return ref.read(palmReadsApiProvider).getPalmRead(id);
});

final palmImageBytesProvider =
    FutureProvider.family<Uint8List?, String>((ref, id) async {
  return ref.read(palmReadsApiProvider).getImageBytes(id);
});

final palmOverlayProvider =
    FutureProvider.family<PalmOverlay, String>((ref, id) async {
  return ref.read(palmReadsApiProvider).getOverlay(id);
});
