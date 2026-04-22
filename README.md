# meta-tactiq-selinux

Custom SELinux reference policy modules for TactiQ OS.

[![ci](https://github.com/revenue7-eng/tactiq-os-selinux/actions/workflows/ci.yml/badge.svg)](https://github.com/revenue7-eng/tactiq-os-selinux/actions/workflows/ci.yml)

This layer extends the `refpolicy-targeted` policy shipped by
[`meta-selinux`](https://git.yoctoproject.org/meta-selinux) with TactiQ
OS-specific domains. It is consumed by the main
[`meta-tactiq`](https://github.com/revenue7-eng/tactiq-os) Yocto layer; the
two are built together as part of the TactiQ OS image.

## Modules

Each module is a `(.te, .if, .fc)` triplet under
`recipes-security/refpolicy/files/`:

| Module            | Purpose                                                  |
|-------------------|----------------------------------------------------------|
| `tactiq_agent`    | Attestation agent domain (Ed25519, TPM, mTLS to verifier)|
| `tactiq_ctl`      | Control-plane CLI and IPC                                |
| `tactiq_fixes`    | Small overrides against the upstream refpolicy           |
| `tactiq_rauc`     | RAUC A/B update bundle handling                          |
| `tactiq_tamper`   | Tamper-detection helper                                  |
| `tactiq_tpm`      | TPM 2.0 access macros                                    |
| `tactiq_vault`    | Local secret vault for keys and attestation state        |
| `tactiq_verifier` | Verifier-side components (for future on-device verifier) |

## Supply-chain posture

Self-assessed, not certified. The full per-requirement breakdown lives in
the main repository at
[`revenue7-eng/tactiq-os/blob/main/SUPPLY_CHAIN.md`](https://github.com/revenue7-eng/tactiq-os/blob/main/SUPPLY_CHAIN.md).
This layer inherits the posture of the parent project; where it differs,
the differences are listed in the main doc.

CI in this repository runs lightweight policy module syntax checks on
every push and pull request to `main`. The full refpolicy compile still
happens in the parent `meta-tactiq` build because it requires the entire
SELinux userspace and the upstream `refpolicy-targeted` source tree.

## Layer metadata

- Yocto series compatibility: `scarthgap`
- Depends on: `core`, `selinux`
- Collection name: `tactiq-selinux`

## Security

See [`SECURITY.md`](SECURITY.md). Vulnerabilities are triaged via the main
repository's private reporting channel.

## License

MIT unless noted per file.
