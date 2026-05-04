# Verifying meta-tactiq-selinux Releases

This document specifies the canonical verification procedure for
meta-tactiq-selinux release artifacts. It is intended for security
engineers, integrators, and anyone establishing a chain of trust from a
published GitHub release down to the SELinux policy source consumed by
the parent `meta-tactiq` Yocto build.

This layer ships **source-only** releases. The compiled binary policy
modules are produced as part of the parent
[`revenue7-eng/tactiq-os`](https://github.com/revenue7-eng/tactiq-os)
Yocto build, and their integrity is covered by the parent's release
verification procedure. What this repository's verification
establishes is that the source policy at a given tag is the source the
maintainer signed.

All commands assume a POSIX shell with `cosign` v2.x, the GitHub CLI
`gh` v2.x (with `gh attestation`), `openssl`, and standard GNU
coreutils.

---

## 0. What you are verifying

A meta-tactiq-selinux release carries two independent layers of evidence:

1. **Source archive integrity** — SHA-256 of the deterministic source
   tarball, recorded in `SHA256SUMS`.
2. **Signature over `SHA256SUMS`** — produced with Sigstore keyless
   signing under the workflow identity
   `https://github.com/revenue7-eng/tactiq-os-selinux/.github/workflows/release-sign.yml@refs/tags/<TAG>`,
   OIDC issuer `https://token.actions.githubusercontent.com`,
   produced by
   [`.github/workflows/release-sign.yml`](.github/workflows/release-sign.yml).
   Assets: `SHA256SUMS.workflow.pem`, `SHA256SUMS.workflow.sig`.
3. **SLSA build-provenance attestation** over the same deterministic
   source archive, produced by
   [`.github/workflows/attest.yml`](.github/workflows/attest.yml) via
   `actions/attest-build-provenance@v2`. Retrieved with
   `gh attestation verify`.

The cosign signature is the primary proof consumed at integration
time; the SLSA attestation is a second, structurally independent
proof recorded in the public Rekor transparency log. Both bind to the
same archive bytes.

Unlike the parent `meta-tactiq` repository, this layer has no
personal-identity legacy: every signed release uses the workflow
identity from `v2.1.0` onward.

## 1. Prerequisites

```sh
cosign version          # expect >= 2.2
gh --version            # expect >= 2.40
openssl version         # any recent
sha256sum --version     # GNU coreutils
```

If `cosign` is missing:

```sh
# Linux x86_64
curl -fsSL -o /usr/local/bin/cosign \
    https://github.com/sigstore/cosign/releases/download/v2.4.1/cosign-linux-amd64
chmod +x /usr/local/bin/cosign
```

## 2. Download

Pick a release tag (`v2.1.0` in the examples below) and pull the full
asset set into a clean working directory.

```sh
TAG=v2.1.0
mkdir -p "tactiq-os-selinux-${TAG}" && cd "tactiq-os-selinux-${TAG}"

gh release download "${TAG}" \
    --repo revenue7-eng/tactiq-os-selinux
```

You should now see:

- `tactiq-os-selinux-<commit>.tar.gz` — deterministic source archive
- `SHA256SUMS` — single line, sha256 of the archive above
- `SHA256SUMS.workflow.pem`, `SHA256SUMS.workflow.sig`

## 3. Verify source archive integrity

```sh
sha256sum -c SHA256SUMS
```

Expected output: `tactiq-os-selinux-<commit>.tar.gz: OK`. A `FAILED`
line invalidates the release — stop and report.

## 4. Verify the signature over `SHA256SUMS`

```sh
TAG=v2.1.0
EXPECTED_IDENTITY="https://github.com/revenue7-eng/tactiq-os-selinux/.github/workflows/release-sign.yml@refs/tags/${TAG}"

cosign verify-blob \
    --certificate            SHA256SUMS.workflow.pem \
    --signature              SHA256SUMS.workflow.sig \
    --certificate-identity   "${EXPECTED_IDENTITY}" \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    SHA256SUMS
```

Expected output: `Verified OK`.

The `--certificate-identity` value must match the tag you are
verifying. A certificate whose SAN resolves to `refs/heads/main` or any
non-`refs/tags/<TAG>` ref is **not valid** for a release signature,
even if produced by the same workflow — see Appendix B for why this
matters.

### 4.1 Failure example

A tampered `SHA256SUMS` or a mismatched `--certificate-identity` must
cause verification to fail:

```sh
$ echo 'tampered' >> SHA256SUMS
$ cosign verify-blob \
    --certificate            SHA256SUMS.workflow.pem \
    --signature              SHA256SUMS.workflow.sig \
    --certificate-identity   "${EXPECTED_IDENTITY}" \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    SHA256SUMS
Error: invalid signature when validating ASN.1 encoded signature
```

Do not proceed past this point if cosign reports an error of any kind.

## 5. Verify the SLSA build-provenance attestation

The attestation is produced on the same deterministic source archive
shipped in the release. It is verified directly against that archive.

```sh
gh attestation verify \
    tactiq-os-selinux-<commit>.tar.gz \
    --repo revenue7-eng/tactiq-os-selinux
```

Expected output includes a line confirming the predicate type
`https://slsa.dev/provenance/v1` and a valid OIDC identity matching
the `attest.yml` workflow path.

**What the attestation binds to — and what it does not:**

- **Binds to:** the deterministic source archive
  `tactiq-os-selinux-<commit>.tar.gz`, covering the trees `conf/` and
  `recipes-security/` at the tagged commit. Every `.te`, `.if`, `.fc`
  file shipped in the release is byte-identical to what was attested.
- **Does not bind to:** the compiled binary SELinux policy module
  (`.pp` files), the rootfs in which that policy is enforced, or any
  artifact built downstream by the parent `meta-tactiq` Yocto pipeline.
  Those are covered by the parent repository's verification procedure
  ([`revenue7-eng/tactiq-os/blob/main/VERIFY.md`](https://github.com/revenue7-eng/tactiq-os/blob/main/VERIFY.md)).

## 6. Reconstructing the source archive locally

The source archive is deterministic: any party can rebuild it from the
tagged git state and confirm byte-identity with the released archive.

```sh
git clone https://github.com/revenue7-eng/tactiq-os-selinux.git
cd tactiq-os-selinux
git checkout <TAG>
COMMIT=$(git rev-parse HEAD)
tar --sort=name \
    --owner=0 --group=0 --numeric-owner \
    --mtime="@$(git log -1 --format=%ct)" \
    --exclude-vcs \
    -czf /tmp/tactiq-os-selinux-${COMMIT}.tar.gz \
    conf recipes-security
sha256sum /tmp/tactiq-os-selinux-${COMMIT}.tar.gz
```

The hash must match the `SHA256SUMS` line shipped in the release.

This step is what `release-sign.yml` and `attest.yml` do inside CI;
running it locally is the strongest form of source-side reproducibility
verification available without the full Yocto build pipeline.

## 7. Transparency-log lookup

Every cosign signature above is anchored in the public Rekor log. The
log index is recorded in the release notes for each tag once
established. Rekor can also be queried directly:

```sh
# By hash of SHA256SUMS
rekor-cli search --sha "$(sha256sum SHA256SUMS | awk '{print $1}')"
```

Web UI: <https://search.sigstore.dev>.

Known Rekor indices:

| Release | Index   | Identity |
|---------|---------|----------|
| _none yet — populated after first signed release_ |  |  |

---

## Appendix A — expected identity strings, in full

```
# Workflow identity (v2.1.0+), parameterised by tag
--certificate-identity    https://github.com/revenue7-eng/tactiq-os-selinux/.github/workflows/release-sign.yml@refs/tags/<TAG>
--certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Appendix B — why the tag-SAN check matters

Sigstore bakes the OIDC claims of the signing principal into the
X.509 certificate's Subject Alternative Name. For a GitHub Actions
workflow, the SAN encodes the **exact ref that triggered the run** —
branch or tag. A signature produced by the same workflow running on
`refs/heads/main` is cryptographically valid, but its SAN does not
match `refs/tags/<TAG>`, and the corresponding Rekor entry carries
the `main`-identity. A consumer who accepts such a signature is
trusting a mutable branch, not the immutable tag.

The canonical release-signing workflow in this repository is triggered
only by tag pushes (`on: push: tags: ['v*']`). If you encounter a
workflow-identity signature whose SAN does not resolve to the tag you
downloaded, reject it and surface the discrepancy — the Rekor entry
is unremovable but the release signature assets can be (and must be)
replaced with tag-triggered ones.

## Appendix C — quick one-liner self-check

The short path once all assets are in a clean directory:

```sh
set -e
TAG=v2.1.0
ID="https://github.com/revenue7-eng/tactiq-os-selinux/.github/workflows/release-sign.yml@refs/tags/${TAG}"

sha256sum -c SHA256SUMS
cosign verify-blob \
    --certificate            SHA256SUMS.workflow.pem \
    --signature              SHA256SUMS.workflow.sig \
    --certificate-identity   "${ID}" \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    SHA256SUMS
echo "release ${TAG}: integrity + signature OK"
```

If any step fails, the release should be treated as untrusted until
the failure is explained on the record.

## See also

- Parent verification procedure:
  <https://github.com/revenue7-eng/tactiq-os/blob/main/VERIFY.md>
- Parent supply-chain posture:
  <https://github.com/revenue7-eng/tactiq-os/blob/main/SUPPLY_CHAIN.md>
- This layer's security policy: [`SECURITY.md`](SECURITY.md)
