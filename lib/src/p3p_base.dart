import 'package:hive/hive.dart';

class P3p {
  static Future<P3p> createSession(String storePath, String sessionName) async {
    Hive.init(storePath);
    return P3p();
  }

  getSelfInfo() {}

  sendMessage() {}

  getChats() {}

  getUnread() {}
}
