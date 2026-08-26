# udev getattr on RAUC Bundle Files — 2026-08-07


Every RAUC install produced two AVC denials from udev workers touching the
bundle file. Commit `f569e92` had already silenced the same access for
bundles stored under `tactiq_vault_data_t`; bundles stored in the
policy-designated directory `/var/lib/tactiq/rauc/bundles`
(`tactiq_rauc_bundle_t`) were not covered. This test establishes what the
denials are, what the denied access costs, and whether suppressing the
audit record is the right answer.

Policy sources referenced here live in `revenue7-eng/tactiq-os-selinux`,
the same repository as this report. The gap was recorded a day earlier
during the RAUC hook measurement (`selinux-rauc-hook-exec-20260806.md` in
`revenue7-eng/tactiq-os`), which noted that the vault path carried the rule
and the bundle directory did not.

## Summary

Two `{ getattr }` denials occur per install, from `(udev-worker)`
processes, on the bundle file under `tactiq_rauc_bundle_t`. Both were
recorded with `permissive=0`, and the install completed with `rc=0`.

The denied access is not without effect. With the access denied, udev
still identifies the filesystem on the loop device
(`ID_FS_TYPE=squashfs` and the rest of the `ID_FS_*` set), but it does not
populate `ID_LOOP_BACKING_DEVICE`, `ID_LOOP_BACKING_INODE` or
`ID_LOOP_BACKING_FILENAME`, and the symlinks `/dev/disk/by-loop-inode/...`
and `/dev/disk/by-loop-ref/...` are not created. With the access granted,
all of these appear.

Those symlinks are created by a single rule set in
`60-persistent-storage.rules`. Nothing else in the image references
`by-loop-inode` or `by-loop-ref`. They exist so that a consumer can find
the loop device from its backing file; on this device there is no such
consumer. RAUC mounts the bundle itself and knows its own paths.

The rule added here is therefore `dontaudit`, not `allow`: the access stays
denied because nothing on this device needs what it would enable, and the
audit record is suppressed because the denial reports a loss that has no
consumer.

This is narrower than the upstream proposal. Refpolicy PR #1181 carries
`rauc_getattr_bundle_files(udev_t)`, an allow rule, with the same
explanation of the mechanism (probing loop device backing files during
bundle installation). A general-purpose policy cannot know whether a
consumer exists; a policy for one known image can.

Limits on the above. The denials were observed with one bundle carrying two
images (rootfs and boot); whether the count depends on bundle composition
was not tested. The absence of consumers rests on a text search of
`/usr/lib/udev`, `/etc/udev` and `/usr/lib/systemd` in the running image,
not on tracing what reads those paths at runtime. The verification install
ran against a policy loaded into a running system rather than one shipped
in an image, so the rule was not exercised through the normal boot path.

## Test system

| Item | Value |
|---|---|
| Image | TactiQ OS 2.1.0 (hardened-edge) |
| SELinux | targeted, enforcing, policy version 35 |
| Policy before | sha256 `8c576ed822bfa88b8c745e4dc1c589dda6dfdfdcbd54e8d467184cf683f97840` |
| Policy after | sha256 `8d01d5f01db8b6666f3e4207af65319f28c862202a52d68de86a65b3381f6010` |
| Bundle | sha256 `69c32ab9c3d25626fee1fc7b1b6b52a3ebd75ddcd0b8dcca725cf47aca56485b`, verity, two images, no hooks |
| Booted slot | rootfs.0 (A) for all runs |
| Clock | set by hand before each session; the board has no RTC |

The board has no RTC, so log timestamps depend on the clock being set
before capture. They are the only link between a log line and the window it
belongs to.

## Install runs

| Run | Policy | Bundle label | Denials | Install |
|---|---|---|---|---|
| 1 | 2.8.0 | `tactiq_vault_data_t` | 0 | rc=0 |
| 2 | 2.8.0 | `tactiq_rauc_bundle_t` | 2 | rc=0 |
| 3 | 2.9.0 | `tactiq_rauc_bundle_t` | 0 | rc=0 |

Runs 2 and 3 differ only in the loaded policy. The bundle, its path, its
label, the booted slot and the command were unchanged.

Run 1 was made with the bundle still on `/data`, where it had been staged.
No denials appeared there, which is consistent with `f569e92` covering that
type.

The bundle used in runs 2 and 3 carried
`unconfined_u:object_r:tactiq_rauc_bundle_t:s0`. The user field differs
from what the production path produces (`system_u`); type enforcement does
not read that field, but the production path was not tested here.

Key line from run 2:

```
audit[798]: AVC avc: denied { getattr } for pid=798 comm="(udev-worker)"
path="/var/lib/tactiq/rauc/bundles/tactiq-bundle-tactiq-rock5a.raucb"
dev="mmcblk1p2" ino=10368
scontext=system_u:system_r:udev_t:s0
tcontext=unconfined_u:object_r:tactiq_rauc_bundle_t:s0
tclass=file permissive=0
```

## What the denial costs

Measured separately, on policy 2.8.0, by attaching a read-only loop device
to the same content under three labels and reading `udevadm info`.

| Case | Backing file label | udev access | `ID_FS_*` | `ID_LOOP_BACKING_*` | `by-loop-*` symlinks |
|---|---|---|---|---|---|
| 1 | `tactiq_rauc_bundle_t` | denied, audited | present | absent | absent |
| 2 | `tactiq_vault_data_t` | denied, dontaudit | present | absent | absent |
| 3 | `etc_t` | allowed | present | present | present |

Case 3 used an 8 MB head of the same bundle, which is enough for the
squashfs superblock; the `ID_FS_*` values matched the full file.

Cases 1 and 2 confirm that `dontaudit` changes the audit record and nothing
else: the outcome is identical to an audited denial. Case 3 is what an
allow rule would produce.

`ID_FS_TYPE`, `ID_FS_VERSION`, `ID_FS_BLOCKSIZE`, `ID_FS_SIZE` and
`ID_FS_USAGE` are read from the loop device, not from the backing file, and
are unaffected by the denial.

## Method for run 3

The policy carrying the new rule was built on the host, transferred by SD
card, and loaded into the running kernel:

```
dd if=policy.35-2.9.0 of=/sys/fs/selinux/load bs=2M
sesearch --dontaudit -s udev_t -t tactiq_rauc_bundle_t -c file
```

The rule was confirmed present in the loaded policy by `sesearch` before
the install. The system was not rebooted between the load and the install;
udev workers are spawned per event, so the running policy applies to them,
but this was not verified independently.

The hash of a policy in the kernel cannot be read back. The on-disk file
was hashed at three points (build output, SD card, device) and matched.
Presence of the rule in the kernel rests on `sesearch`, not on the hash.

## Rule

```
# udev probes the loop device backing the bundle during install and
# hits the bundle label; harmless - silence it.
dontaudit udev_t tactiq_rauc_bundle_t:file getattr;
```

Module `tactiq_rauc` 2.8.0 to 2.9.0. `udev_t` is already required by the
module; `tactiq_rauc_bundle_t` is declared in it.

## Logs

| File | Contents |
|---|---|
| `udev-bundle-getattr-20260807.log` | install runs 1 and 2, state block first |
| `udev-bundle-getattr-verify-20260807.log` | install run 3, state block first |
| `udev-loop-probe-20260807.log` | loop probe, three cases, state block first |

Hashes in `SHA256SUMS`, verified on the device and after transfer. Logs
were not edited.

Each capture opens with a state block recording the image, the on-disk
policy hash, the SELinux mode and the subject file. Earlier captures in
this project did not record this, which left the loaded policy
unrecoverable after the fact.

One artefact in the first log: a `semodule` denial writing to the log file
itself, because `semanage_t` cannot write to `tactiq_vault_data_t`. It
belongs to the capture, not to the install.

## Observations

Not investigated:

- `/var/lib/tactiq` at the top level is absent from `file_contexts`; only
  its subdirectories are labelled, so the directory carries `var_lib_t`.
- The image ships no module store under `/etc/selinux/targeted`. Policy is
  compiled on the host and shipped as `policy.35`, so module versions
  cannot be established on the device. Identifying a loaded policy needs
  the binary hash plus the commit it was built from.
- IMA appraisal reports `invalid-signature` and unknown key `id:cc67b774`
  throughout boot, with `res=0`. Unrelated to this test.
