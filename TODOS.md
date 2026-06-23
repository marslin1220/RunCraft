# TODOs — Open Questions and Future Work

> Things that are deliberately not done yet, with the reasoning behind
> the deferral. When a new "we should do X eventually, but not now"
> idea comes up, add a row here rather than letting it live only in
> conversation — this file is git-tracked and survives session resets.

| What                                  | Why it isn't done                                                                |
| ------------------------------------- | -------------------------------------------------------------------------------- |
| **iCloud sync via `SyncEngine`**      | SQLiteData supports CloudKit sync; we haven't enabled it. Single device only today. Main benefit: device-migration/backup protection — today, losing/replacing the iPhone or deleting the app loses months of training history and VDOT progression with no recovery path. CloudKit's *private* database stays tied to the user's own iCloud account (consistent with the "no servers" privacy stance — see `docs/privacy.md`, which already frames this as a planned v2.0 addition). Not urgent pre-launch; revisit once v1.0 users start accumulating data worth protecting. |
