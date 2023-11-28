import 'dart:ffi';

import 'package:p3p/p3p.dart';
import 'package:ffi/ffi.dart';

void main() async {
  final p3p = await getP3p('../vendor/api_host.so');
  const path = '/home/user/.config/p3p.test/';
  final charPointer = path.toNativeUtf8().cast<Char>();
  p3p.InitStore(charPointer);
  calloc.free(charPointer);
  print(p3p.HealthCheck() == 1);
}
