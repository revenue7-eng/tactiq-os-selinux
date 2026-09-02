# tactiq_agent search on /etc/ssl — 2026-09-02

Every attestation cycle produced four AVC denials from the tpm2-tools
processes the agent executes, all on `search` of `/etc/ssl` under
`cert_t`. The module already carries rules for its own certificate
type (`tactiq_agent_cert_t`), which is a different label and did not
cover this access. This test establishes what the denials are, what
the denied access costs, and whether suppressing the audit record is
the right answer.

Policy sources referenced here live in `revenue7-eng/tactiq-os-selinux`,
the same repository as this report. The denial first appeared in the
handoff of the preceding session (`5.1`), recorded while the agent was
run under a manual drop-in; this run is the first on a shipped image,
booted from slot B with the `BindPaths` fix from `revenue7-eng/tactiq-os`
PR #145 in place.

## Summary

Sixteen `{ search }` denials in one agent run of roughly four cycles,
from `tpm2_nvincrement`, `tpm2_nvread` and `tpm2_sign`, all with
`scontext=tactiq_agent_t`, `tcontext=cert_t`, `tclass=dir`,
`permissive=0`. The accompanying `type=1300` records show
`syscall=56` (`openat`), `success=no`, `exit=-13` (`EACCES`).

The agent completed its cycles throughout: envelopes 14 through 18
were written while every one of these denials was being recorded.

## What the denied access costs

The subject is OpenSSL linked into tpm2-tools, which probes the default
certificate store during library initialisation. Three facts, measured
on this device, establish that nothing in the attestation path depends
on what lies behind that directory:

1. Envelope 10 verifies with the access denied. Running
   `openssl dgst -sha256 -verify /data/tactiq/keys/pubkey.pem
   -signature .../000000000010.sig .../000000000010.msg`
   returns `Verified OK`. The signature is produced by `tpm2_sign`
   inside the TPM; the private key never reaches userspace and no
   certificate chain is consulted.
2. `/etc/ssl/openssl.cnf.d` is empty. The active `.include` directive
   at the end of `openssl.cnf` therefore contributes nothing.
3. `provider_sect` in `openssl.cnf` activates `default_sect` and
   nothing else; the `fips` line is commented out. That is the same
   provider OpenSSL activates implicitly when no configuration is
   reachable — as the file's own comments state.

So the configuration the agent cannot reach is semantically equivalent
to its absence, and the CA store plays no part in signing. Unlike the
udev case in `udev-bundle-getattr-20260807.md`, where the denial cost
a set of symlinks that simply had no consumer, here the denial costs
nothing at all that is observable on this device.

## Why dontaudit rather than allow

Granting `search` on `cert_t` would buy silence at the price of
widening the agent's reach into a directory it has no business in.
The access stays denied; only the audit record is suppressed.

The rule is written narrowly, `dontaudit tactiq_agent_t cert_t:dir
search;`, rather than through
`miscfiles_dontaudit_read_generic_certs()`, which would also silence
`file` and `lnk_file` read. Only `dir search` was observed, so only
`dir search` is silenced: a wider suppression would hide a future
denial that has not been measured.

The operational argument is secondary but real. `auditd` is not
functional on this image — the log directory is absent — so denials
land only in the kernel ring buffer, which is also the console. Four
records per thirty-second cycle displace the buffer content that
diagnosis actually depends on.

## Limits of this measurement

This run does not establish that the rule works; it establishes that
the denial is spurious. Confirmation is a subsequent boot with the
rebuilt policy in the image, showing no `cert_t` records in `dmesg`
while envelopes continue to be written.

If the agent later needs a genuine trust store — a verifier reached
over mTLS is the obvious case — this rule must be revisited rather
than widened, because the access would stop being spurious at that
point.

Module version 2.1.0 -> 2.2.0.

Raw denials: `agent-cert-search-20260902.log`.
