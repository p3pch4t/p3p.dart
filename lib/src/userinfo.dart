import 'dart:convert';

import 'package:isar/isar.dart';
import 'package:p3p/p3p.dart';

/// Information about user, together with helper functions
class UserInfo {
  /// You shouldn't use this function, use UserInfo.create instead.
  UserInfo({
    required PublicKey? publicKey,
    required this.endpoint,
    this.id = -1,
    this.name,
  }) {
    if (publicKey != null) {
      this.publicKey = publicKey;
    }
  }

  /// id, -1 means insert to database as new.
  int id = -1;

  /// PublicKey to identify the user
  @ignore // make isar happy
  late PublicKey publicKey;

  /// Places where we can reach given user
  @ignore // make isar happy
  List<Endpoint> endpoint;

  /// User's display name, if null we will send introduce.request
  String? name;

  /// When did we *receive or send* message in to/from this user?
  DateTime lastMessage = DateTime.fromMicrosecondsSinceEpoch(0);

  /// When did we send introduce event?
  DateTime lastIntroduce = DateTime.fromMicrosecondsSinceEpoch(0);

  /// When did we send any event?
  DateTime lastEvent = DateTime.fromMicrosecondsSinceEpoch(0);

  /// getter for the given UserInfo's filestore
  @ignore // make isar happy
  FileStore get fileStore => FileStore(roomFingerprint: publicKey.fingerprint);

  /// Get all messages and sort them based on when they got received
  Future<List<Message>> getMessages(P3p p3p) async {
    final ret =
        await p3p.db.getMessageList(roomFingerprint: publicKey.fingerprint);
    ret.sort(
      (m1, m2) => m1.dateReceived.difference(m2.dateReceived).inMicroseconds,
    );
    return ret;
  }

  /// add/update a message *without* broadcasting such change.
  Future<void> addMessage(P3p p3p, Message message) async {
    final msg = await p3p.db
        .getMessage(uuid: message.uuid, roomFingerprint: publicKey.fingerprint);
    if (msg != null) {
      message.id = msg.id;
    }
    lastMessage = DateTime.now();
    id = await p3p.db.save(this);
    message.id = await p3p.db.save(message);
    await p3p.callOnMessage(message);
  }

  /// get all events for given UserInfo and try to deliver them.
  Future<void> relayEvents(P3p p3p, PublicKey publicKey) async {
    // fix: issue occured in early versions when introduction wasn't working
    // properly, now it is fixed but I'm leaving this here just in case - to not
    // leave user with not functional chat app
    if (endpoint.isEmpty) {
      // p3p.print('fixing endpoint by adding ReachableRelay.defaultEndpoints');
      endpoint = ReachableRelay.getDefaultEndpoints(p3p);
    }
    // 1. Get all events
    final evts = await p3p.db.getEvents(destinationPublicKey: publicKey);

    // 2. if there aren't any events return
    if (evts.isEmpty) {
      return;
    }
    // NOTE: this can, and probably should be replaced with json.encode,
    // but for development and debugging purposes I'll keep it this way
    // once released we will probably want to encode stuff in a different
    // way anyway - so I'm leaving this as is.
    final bodyJson = const JsonEncoder.withIndent('    ').convert(evts);

    // Encrypt the whole body with destination's publickey (note:  is part of
    // the UserInfo object.)
    //
    final body = await publicKey.encrypt(bodyJson, p3p.privateKey);
    P3pError? resp = P3pError(code: -1, info: 'No endpoint reached.');

    for (final endp in endpoint) {
      if (resp != null) {
        switch (endp.protocol) {
          case 'local' || 'locals':
            resp = await p3p.reachableLocal.reach(
              p3p: p3p,
              endpoint: endp,
              message: body,
              publicKey: publicKey,
            );
          case 'relay' || 'relays':
            resp = await p3p.reachableRelay.reach(
              p3p: p3p,
              endpoint: endp,
              message: body,
              publicKey: publicKey,
            );
          case 'i2p':
            if (p3p.reachableI2p != null) {
              resp = await p3p.reachableI2p?.reach(
                p3p: p3p,
                endpoint: endp,
                message: body,
                publicKey: publicKey,
              );
            } else {
              resp = await p3p.reachableRelay.reach(
                p3p: p3p,
                endpoint: endp,
                message: body,
                publicKey: publicKey,
              );
            }
          default:
        }
      }

      if (resp == null) {
        for (final elm in evts) {
          await p3p.db.remove(elm);
        }
      } else {
        p3p.print(resp);
      }
    }
  }

  /// p.s. not really depracated but I want everybody to know how does it work
  /// and @Deprecated(...) functions are highlighted in IDEs
  @Deprecated(
      'NOTE: If you call this function event is being set internally as '
      'delivered, it is your problem to hand it over to the user. '
      'desired location. \n'
      'For this reason this is released as deprecated - to discourage '
      'usage. ')
  Future<String> relayEventsString(
    P3p p3p,
  ) async {
    final evts = await p3p.db.getEvents(destinationPublicKey: publicKey);
    final bodyJson = const JsonEncoder.withIndent('    ').convert(evts);
    final body = await publicKey.encrypt(bodyJson, p3p.privateKey);
    for (final elm in evts) {
      await p3p.db.remove(elm);
    }
    return body;
  }

  /// Add event to queue - to send it to the destination later.
  Future<void> addEvent(P3p p3p, Event evt) async {
    if (evt.eventType == EventType.introduce) {
      lastIntroduce = DateTime.now();
    }
    lastEvent = DateTime.now();
    evt.destinationPublicKey = publicKey;
    evt.id = await p3p.db.save(evt);
    id = await p3p.db.save(this);
  }

  /// create new UserInfo object, with sane defaults and store it in Database
  /// `any` can be anything that may resolve to user, for now this includes:
  /// - Fingerprint
  // TODO(mrcyjanek): Add some kind of fingerprint database?
  static Future<UserInfo?> create(
    P3p p3p,
    String any,
  ) async {
    final pubKey = await PublicKey.create(p3p, any);
    if (pubKey == null) return null;
    final ui = UserInfo(
      publicKey: pubKey,
      endpoint: [
        ...ReachableRelay.getDefaultEndpoints(p3p),
      ],
    );
    ui.id = await p3p.db.save(ui);
    return ui;
  }
}
