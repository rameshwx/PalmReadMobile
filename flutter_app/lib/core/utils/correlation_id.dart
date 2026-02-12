import 'package:uuid/uuid.dart';

class CorrelationId {
  static const _uuid = Uuid();

  static String next() => _uuid.v4();
}
