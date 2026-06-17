/*import 'dart:math';


final Random _rand = Random();

String generateClientMsgId() {
  final ts = DateTime.now().microsecondsSinceEpoch;
  final r = _rand.nextInt(1 << 32).toRadixString(16);
  return '$ts-$r';
}
*/
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

String generateClientMsgId() {
  return _uuid.v4();
}
