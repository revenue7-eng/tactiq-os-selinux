# tactiq_log on hardware: 2026-09-29

The `tactiq_log` module (commit `4eb4ab9`, #24) was written from the
design, not from collected denials. Its commit message asks for a pass
on hardware and for any addition to land in a follow-up commit with its
log under `measurements/`. This is that pass. It adds no rules.

The device is the Rock 5A test board, booted from slot B with the
development loader. The image in slot B reports itself in
`/etc/tactiq-release` as `tactiq-image-dev`, `TACTIQ_META_TACTIQ_GIT=v2.1.0-rc12`,
`TACTIQ_RELEASE_DATE=2026-09-24`. SELinux is `Enforcing`. The root is
`PARTLABEL=rootfs_b` with no device-mapper target, so verity is not in
the boot chain on this image. The board clock resets on power loss and
reads 2026-03-13; timestamps in the raw log carry that date.

## Summary

The module is loaded (`semodule -l` lists `tactiq_log`). During the
boot under test no denial names a `tactiq_log` type or domain, and no
denial concerns the journal on `/data` or the crash record directory.

The layout under `/data/log` carries the labels the design specifies:

- `/data/log/journal` is `systemd_journal_t`, the ordinary journal type;
- `/data/log/pstore` is `tactiq_pstore_log_t`, the module's own type;
- the parent `/data/log` is `tactiq_vault_data_t`, as is the rest of
  the partition.

The journal persists across reboots: `journalctl --list-boots` shows
four boots under the current machine id, and the kernel command line of
each of the three earlier ones reads `rauc.slot=B`.

## Denials that were observed

Twenty-eight `{ getattr }` denials, all from `systemd_networkd_t`,
alternating between two targets:

- `/run/systemd/journal/dev-log`, `syslogd_runtime_t`, `sock_file`;
- `/dev/kmsg`, `init_runtime_t`, `chr_file`.

Neither target is a `tactiq_log` type and the subject is not a
`tactiq_log` domain. This is a gap in the base policy for networkd and
is outside the scope of this module. No rule is added for it here.

## Limits of this measurement

The crash record path is not exercised. On this board the contents of
DRAM do not survive a reset (measured 2026-09-16: the DDR is fully
reinitialised after reset), so no pstore record appears regardless of
policy. The rules for `tactiq_pstore_log_t` and
`tactiq_log_read_pstore_records` are therefore present and labelled
correctly but unobserved in use.

The domain in which the layout service ran was not observed directly.
The service is a oneshot that had exited before inspection; its result
is visible only through the labels it left.

Denials were read from the journal of one boot. `auditd` is not used
on this image, and a `dontaudit` rule anywhere in the loaded policy
would suppress a record without granting the access.

The partition holds eleven journal directories under different machine
ids, written from both slots. Which images wrote them is not
established here: the kernel version string, including its build date,
is identical across builds, so it does not tell images apart. Only the
directory of the current machine id is used as evidence above.

## Result

No policy change. The module version is unchanged. The pin of this
repository in `integration/LAYERS.lock` of `revenue7-eng/tactiq-os`
moves from `b63f7df` to the commit that adds this report, for
v2.1.0-rc14. The policy it pins is that of `4eb4ab9`.

Raw output: `tactiq-log-level0-20260929.log`.
