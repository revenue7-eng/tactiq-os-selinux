#!/usr/bin/env bash
# build-release-archive.sh
#
# Build a deterministic source archive of the SELinux policy layer suitable
# for signing and attestation. The output is byte-identical given the same
# git commit, so two independent builders converge on the same SHA-256.
#
# Determinism rules applied:
#   - tar --sort=name         : entries in stable order, independent of inode/readdir
#   - --owner=0 --group=0     : no local-uid leakage
#   - --numeric-owner         : no /etc/passwd dependency
#   - --mtime=@<commit_time>  : timestamp pinned to the commit's author date
#   - --exclude-vcs           : no .git churn
#   - gzip -n                 : no embedded mtime/filename in the gzip header
#
# Mirror of the recipe in revenue7-eng/tactiq-os/.github/workflows/attest.yml,
# extracted here so that humans and CI run the *same* command, and so that
# reproducibility can be verified locally without GitHub Actions.
#
# Usage:
#   ./scripts/build-release-archive.sh           # writes to ./dist/
#   OUT=/tmp/foo ./scripts/build-release-archive.sh
#
# Outputs:
#   <OUT>/tactiq-os-selinux-<commit>.tar.gz
#   <OUT>/tactiq-os-selinux-<commit>.sha256
#   <OUT>/SHA256SUMS                # canonical, sorted, two-space format

set -euo pipefail

OUT="${OUT:-dist}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

COMMIT="$(git rev-parse HEAD)"
COMMIT_TIME="$(git log -1 --format=%ct)"

# Files and directories to include. Anything outside this list is treated as
# build-system noise and deliberately excluded so the archive hash depends
# only on policy-relevant content.
#
# REQUIRED entries must exist or the build fails. OPTIONAL entries are added
# to the archive only if present; this lets repository state evolve (e.g.
# adding a top-level LICENSE file once the licensing question is resolved
# upstream) without breaking the release pipeline before the file lands.
REQUIRED=(
    conf
    recipes-security
    POLICY_MANIFEST.md
    README.md
    SECURITY.md
    CODEOWNERS
)
OPTIONAL=(
    LICENSE
)

INCLUDE=()
for path in "${REQUIRED[@]}"; do
    if [[ ! -e "$path" ]]; then
        echo "::error::release archive input missing: $path" >&2
        exit 1
    fi
    INCLUDE+=("$path")
done
for path in "${OPTIONAL[@]}"; do
    if [[ -e "$path" ]]; then
        INCLUDE+=("$path")
    fi
done

mkdir -p "$OUT"
ARCHIVE="$OUT/tactiq-os-selinux-${COMMIT}.tar.gz"

# Two-stage pipe: tar emits a deterministic stream, gzip -n strips its own
# header timestamp. Combining the two flags into `tar -czf` would re-introduce
# a gzip-side mtime via tar's internal gzip invocation.
tar --sort=name \
    --owner=0 --group=0 --numeric-owner \
    --mtime="@${COMMIT_TIME}" \
    --exclude-vcs \
    -cf - "${INCLUDE[@]}" \
  | gzip -n -9 > "$ARCHIVE"

sha256sum "$ARCHIVE" | tee "$OUT/tactiq-os-selinux-${COMMIT}.sha256"

# Canonical SHA256SUMS over every release asset. cosign will sign this file,
# so its format is part of the verification contract: GNU `sha256sum`
# two-space output, sorted by filename, LF line endings, no trailing blank.
( cd "$OUT" && \
    sha256sum "tactiq-os-selinux-${COMMIT}.tar.gz" \
    | LC_ALL=C sort -k2 \
    > SHA256SUMS )

echo
echo "Release archive built:"
echo "  archive:   $ARCHIVE"
echo "  sha256:    $(cut -d' ' -f1 < "$OUT/tactiq-os-selinux-${COMMIT}.sha256")"
echo "  manifest:  $OUT/SHA256SUMS"
