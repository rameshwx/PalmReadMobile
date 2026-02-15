import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../result/data/palm_reads_api.dart';
import '../../result/domain/palm_read_models.dart';

final palmHistoryProvider = FutureProvider<PalmReadHistoryPage>((ref) async {
  return ref.read(palmReadsApiProvider).listPalmReads(page: 1);
});
