import 'dart:async';

import 'package:p3p/p3p.dart';
import 'package:p3p/src/reachable/relay.dart';

Future<void> scheduleTasks(P3p p3p) async {
  unawaited(processTasksLoop(p3p));
  while (true) {
    final s = Stopwatch()..start();
    await pingRelay(p3p);
    print('pingRelays exited in: ${s.elapsedMilliseconds / 1000}');
    s.stop();

    await Future.delayed(const Duration(seconds: 5));
  }
}

Future<Never> processTasksLoop(P3p p3p) async {
  while (true) {
    await processTasks(p3p);
    await Future.delayed(const Duration(seconds: 5));
  }
}

Future<void> processTasks(P3p p3p) async {
  // print('processTasks');
  final si = await p3p.getSelfInfo();
  final users = await p3p.db.getAllUserInfo();
  // print('processTasks: users.length: ${users.length}');
  for (final ui in users) {
    // print('schedTask: ${ui.id} - ${si.id}');
    if (ui.publicKey.fingerprint == si.publicKey.fingerprint) continue;
    if (ui.name == null) {
      ui.name ??= 'Unknown user - ${DateTime.now()}';
      await ui.addEvent(
        p3p,
        Event(
          eventType: EventType.introduceRequest,
          data: EventIntroduceRequest(
            publickey: p3p.privateKey.toPublic,
            endpoint: si.endpoint,
          ),
        ),
      );
    }
    // begin file request
    final fs = await ui.fileStore.getFileStoreElement(p3p);
    for (final felm in fs) {
      if (felm.isDeleted == false &&
          await felm.file.length() != felm.sizeBytes &&
          felm.shouldFetch == true &&
          felm.requestedLatestVersion == false) {
        felm.requestedLatestVersion = true;
        await p3p.db.save(felm);
        await ui.addEvent(
          p3p,
          Event(
            eventType: EventType.fileRequest,
            destinationPublicKey: ui.publicKey,
            data: EventFileRequest(
              uuid: felm.uuid,
            ),
          ),
        );
      }
    }
    // end file request

    final diff = DateTime.now().difference(ui.lastIntroduce).inMinutes;
    // print(
    //   '${ui.id}: p3p: ${ui.publicKey.fingerprint} : scheduleTasks diff = $diff - ${ui.lastIntroduce}',
    // );
    // re-introduce ourself frequently while the app is in development
    // In future this should be changed to like once a day / a week.
    if (diff > 60) {
      await ui.addEvent(
        p3p,
        Event(
          eventType: EventType.introduce,
          destinationPublicKey: ui.publicKey,
          data: EventIntroduce(
            endpoint: si.endpoint,
            publickey: p3p.privateKey.toPublic,
            username: si.name ?? 'unknown name [${DateTime.now()}]',
          ),
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
