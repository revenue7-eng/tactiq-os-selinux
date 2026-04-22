# Security Policy

This repository is a companion layer to
[`revenue7-eng/tactiq-os`](https://github.com/revenue7-eng/tactiq-os).
Vulnerability triage and disclosure is coordinated through the main
repository's security policy.

## Supported versions

This layer is versioned alongside the main `meta-tactiq` layer. Only the
latest tag receives active support; older tags are preserved for
historical reference.

| Version        | Supported          |
|----------------|--------------------|
| v2.0.1         | :white_check_mark: |
| v2.0.0-alpha1  | :x:                |

## Reporting a vulnerability

Please do **not** open a public GitHub issue. Use one of:

- **Preferred:** private vulnerability report on this repository —
  `Security → Report a vulnerability`.
- **Or** on the main repository:
  <https://github.com/revenue7-eng/tactiq-os/security/advisories/new>.
- **Email:** `security@tactiqedge.com`.

When reporting, please include:

- Affected module (`.te` / `.if` / `.fc`) and version or commit.
- A description of the policy-level issue — for example, an overly broad
  `allow` rule, a missing `neverallow`, or a mislabelled file context.
- Any suggested mitigation, if known.

Acknowledgement within three business days; status update within seven
business days. Coordinated disclosure timeline is agreed case-by-case;
default is 90 days from initial report to public disclosure, shortened
if a fix is already available.

## Scope

- All SELinux policy modules under `recipes-security/refpolicy/files/`
  (the `tactiq_*` triplets).
- The `refpolicy-targeted_%.bbappend` that integrates these modules into
  the upstream reference policy build.
- The CI workflows under `.github/workflows/`.

Out of scope: upstream `refpolicy-targeted` itself, `meta-selinux`, the
Linux kernel SELinux subsystem. Please report those to their respective
upstream projects.

## See also

- Main security policy:
  <https://github.com/revenue7-eng/tactiq-os/blob/main/SECURITY.md>
- Supply-chain posture:
  <https://github.com/revenue7-eng/tactiq-os/blob/main/SUPPLY_CHAIN.md>
