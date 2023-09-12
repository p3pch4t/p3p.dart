import 'package:p3p/p3p.dart';

/// Abstract class defining a way to contact a peer in the network.
abstract class Reachable {
  /// List of supported protocols
  List<String> protocols = [];

  /// function to contact the relay
  ///  null - success
  ///  P3pError - we will retry
  Future<P3pError?> reach({
    required P3p p3p,
    required Endpoint endpoint,
    required String message,
    required PublicKey publicKey,
  });
}
