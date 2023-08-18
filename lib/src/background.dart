import 'dart:async';

import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/relay.dart';

Future<void> scheduleTasks(P3p p3p) async {
  Timer.periodic(
    const Duration(seconds: 5),
    (Timer t) async {
      await pingRelay(p3p);
      await processTasks(p3p);
    },
  );
}

Future<void> processTasks(P3p p3p) async {
  final si = await p3p.getSelfInfo();
  final users = await p3p.db.getAllUserInfo();
  // print('processTasks: $users');
  for (final ui in users) {
    // print('schedTask: ${ui.id} - ${si.id}');
    if (ui.publicKey.fingerprint == si.publicKey.fingerprint) continue;
    // begin file request
    final fs = await ui.fileStore.getFileStoreElement(p3p);
    for (final felm in fs) {
      if (felm.isDeleted == false &&
          await felm.file.length() != felm.sizeBytes &&
          felm.shouldFetch == true &&
          felm.requestedLatestVersion == false) {
        felm.requestedLatestVersion = true;
        await felm.save(p3p);
        await ui.addEvent(
          p3p,
          Event(
            eventType: EventType.fileRequest,
            destinationPublicKey: ui.publicKey,
            data: EventFileRequest(
              uuid: felm.uuid,
            ).toJson(),
          ),
        );
      }
    }
    // end file request

    final diff = DateTime.now().difference(ui.lastIntroduce).inMinutes;
    // print(
    //   '${ui.id}: p3p: ${ui.publicKey.fingerprint} : scheduleTasks diff = $diff - ${ui.lastIntroduce}',
    // );
    if (diff > 60) {
      await ui.addEvent(
        p3p,
        Event(
          eventType: EventType.introduce,
          destinationPublicKey: ui.publicKey,
          data: EventIntroduce(
            endpoint: si.endpoint,
            fselm: await ui.fileStore.getFileStoreElement(p3p),
            publickey: p3p.privateKey.toPublic,
            username: si.name ?? 'unknown name [${DateTime.now()}]',
          ).toJson(),
        ),
      );
    } else {
      await ui.relayEvents(p3p, ui.publicKey);
    }
  }
}

Future<void> pingRelay(P3p p3p) async {
  await ReachableRelay.getAndProcessEvents(p3p);
}
