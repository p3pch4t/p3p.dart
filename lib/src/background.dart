import 'dart:async';

import 'package:p3p/p3p.dart';

/// scheduleTasks - used to run periodic tasks in the library
/// started automatically if createSession is called with scheduleTasks: true
/// which is the default
/// When calling this function manually (which you shouldn't do)
/// make sure to call it once at most.
/// Otherwise it will run multiple times which will cause unnecesary load
/// and many database logs.
Future<void> scheduleTasks(
  P3p p3p, {
  Duration delay = const Duration(seconds: 5),
}) async {
  unawaited(_processTasksLoop(p3p, delay: delay));
  while (true) {
    final s = Stopwatch()..start();
    await pingRelay(p3p);
    // print('pingRelays exited in: ${s.elapsedMilliseconds / 1000}');
    s.stop();

    // ignore: inference_failure_on_instance_creation
    await Future.delayed(delay);
  }
}

/// _processTasksLoop - run processTasks() in a while(true) loop
Future<Never> _processTasksLoop(
  P3p p3p, {
  Duration delay = const Duration(seconds: 5),
}) async {
  while (true) {
    await processTasks(p3p);
    // ignore: inference_failure_on_instance_creation
    await Future.delayed(delay);
  }
}

/// processTasks - basically do everything that needs to be done on a periodic
/// bases.
Future<void> processTasks(P3p p3p) async {
  final si = await p3p.getSelfInfo();
  final users = await p3p.db.getAllUserInfo();
  for (final ui in users) {
    // print('schedTask: ${ui.id} - ${si.id}');
    if (ui.publicKey.fingerprint == si.publicKey.fingerprint) continue;
    if (ui.name == null) {
      await processTasksSendIntroduceRequest(p3p, ui, si);
    }
    await processTasksFileRequest(p3p, ui, si);
    await processTasksRelayEventsOrIntroduce(p3p, ui, si);
  }
}

/// processTasksSendIntroduceRequest - called as part of processTasks, sends
/// introduce request - to obtain things like publickey.
Future<void> processTasksSendIntroduceRequest(
  P3p p3p,
  UserInfo ui,
  UserInfo si,
) async {
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

/// processTasksRelayEventsOrIntroduce - call relayEvents on ui, or introduce
/// ourselves every now and then (TODO: specify when)
Future<void> processTasksRelayEventsOrIntroduce(
  P3p p3p,
  UserInfo ui,
  UserInfo si,
) async {
  final diff = DateTime.now().difference(ui.lastIntroduce).inHours;
  // re-introduce ourself frequently while the app is in development
  // In future this should be changed to like once a day / a week.

  if (diff > 6) {
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

/// processTasksFileRequest - send request for all files that are marked for
/// download but not yet fetched.
Future<void> processTasksFileRequest(P3p p3p, UserInfo ui, UserInfo si) async {
  final fs = await ui.fileStore.getFileStoreElement(p3p);
  for (final felm in fs) {
    if (felm.isDeleted == false &&
        await felm.file.length() != felm.sizeBytes &&
        felm.shouldFetch == true &&
        felm.requestedLatestVersion == false) {
      felm.requestedLatestVersion = true;
      felm.id = await p3p.db.save(felm);
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
}

/// pingRelay(p3p); - alias ofReachableRelay.getAndProcessEvents(p3p);
Future<void> pingRelay(P3p p3p) async {
  await ReachableRelay.getAndProcessEvents(p3p);
}
