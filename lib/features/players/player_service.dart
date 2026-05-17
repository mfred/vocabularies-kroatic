import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';

class PlayerService {
  PlayerService(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Future<Player> ensureDefaultPlayer() async {
    final existing = await _db.getAnyLocalPlayer();
    if (existing != null) return existing;
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insertPlayer(
      PlayersCompanion.insert(
        id: id,
        displayName: 'Du',
        createdAt: now,
      ),
    );
    return (await _db.getAnyLocalPlayer())!;
  }
}
