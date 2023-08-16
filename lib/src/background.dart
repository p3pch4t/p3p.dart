import 'dart:async';

import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/relay.dart';

void scheduleTasks(P3p p3p) async {
  Timer.periodic(
    Duration(seconds: 5),
    (Timer t) async {
      await pingRelay(p3p);
      await processTasks(p3p);
    },
  );
}

Future<void> processTasks(P3p p3p) async {
  final si = await p3p.getSelfInfo();

  for (UserInfo ui in p3p.userInfoBox.getAll()) {
    // print("schedTask: ${ui.id} - ${si.id}");
    if (ui.id == si.id) continue;
    // begin file request
    final fs = await ui.fileStore.getFileStoreElement(p3p);
    for (var felm in fs) {
      if (felm.isDeleted == false &&
          await felm.file.length() != felm.sizeBytes &&
          felm.shouldFetch == true &&
          felm.requestedLatestVersion == false) {
        felm.requestedLatestVersion = true;
        await felm.save(p3p);
        ui.addEvent(
          p3p,
          Event(
            eventType: EventType.fileRequest,
            destinationPublicKey: ToOne(targetId: ui.publicKey.id),
          )..data = EventFileRequest(
              uuid: felm.uuid,
            ).toJson(),
        );
        ui.save(p3p);
      }
    }
    // end file request
    final diff = DateTime.now().difference(ui.lastIntroduce).inMinutes;
    // print('p3p: ${ui.publicKey.fingerprint} : scheduleTasks diff = $diff');
    if (diff > 60) {
      ui.addEvent(
        p3p,
        Event(
          eventType: EventType.introduce,
          destinationPublicKey: ToOne(target: ui.publicKey),
        )..data = EventIntroduce(
            endpoint: si.endpoint,
            fselm: await ui.fileStore.getFileStoreElement(p3p),
            publickey: p3p.privateKey.toPublic,
            username: si.name ?? "unknown name [${DateTime.now()}]",
          ).toJson(),
      );
      ui.lastIntroduce = DateTime.now();
    } else {
      ui.relayEvents(p3p, ui.publicKey);
    }
    ui.save(p3p);
  }
}

Future<void> pingRelay(P3p p3p) async {
  await ReachableRelay.getAndProcessEvents(p3p);
}
