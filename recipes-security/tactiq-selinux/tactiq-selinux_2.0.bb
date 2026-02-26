SUMMARY = "TactiQ SELinux custom policy modules"
DESCRIPTION = "SELinux policy modules for TactiQ Edge v2.0 security components"
SECTION = "security"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

DEPENDS = "refpolicy-targeted"
RDEPENDS:${PN} = "policycoreutils policycoreutils-setfiles selinux-autorelabel"

POLICY_MODULES = "tactiq_agent tactiq_verifier tactiq_tamper tactiq_vault tactiq_ctl tactiq_tpm tactiq_rauc"

SRC_URI = " \
    file://policy/tactiq_agent/tactiq_agent.te \
    file://policy/tactiq_agent/tactiq_agent.fc \
    file://policy/tactiq_agent/tactiq_agent.if \
    file://policy/tactiq_tpm/tactiq_tpm.te \
    file://policy/tactiq_tpm/tactiq_tpm.fc \
    file://policy/tactiq_tpm/tactiq_tpm.if \
    file://policy/tactiq_verifier/tactiq_verifier.te \
    file://policy/tactiq_verifier/tactiq_verifier.fc \
    file://policy/tactiq_verifier/tactiq_verifier.if \
    file://policy/tactiq_tamper/tactiq_tamper.te \
    file://policy/tactiq_tamper/tactiq_tamper.fc \
    file://policy/tactiq_tamper/tactiq_tamper.if \
    file://policy/tactiq_vault/tactiq_vault.te \
    file://policy/tactiq_vault/tactiq_vault.fc \
    file://policy/tactiq_vault/tactiq_vault.if \
    file://policy/tactiq_ctl/tactiq_ctl.te \
    file://policy/tactiq_ctl/tactiq_ctl.fc \
    file://policy/tactiq_ctl/tactiq_ctl.if \
    file://policy/tactiq_rauc/tactiq_rauc.te \
    file://policy/tactiq_rauc/tactiq_rauc.fc \
    file://policy/tactiq_rauc/tactiq_rauc.if \
"

S = "${WORKDIR}"

do_compile() {
    :
}

do_install() {
    install -d ${D}${datadir}/selinux/packages

    for mod in ${POLICY_MODULES}; do
        install -d ${D}${datadir}/selinux/packages/${mod}
        install -m 0644 ${WORKDIR}/policy/${mod}/${mod}.te ${D}${datadir}/selinux/packages/${mod}/
        install -m 0644 ${WORKDIR}/policy/${mod}/${mod}.fc ${D}${datadir}/selinux/packages/${mod}/
        install -m 0644 ${WORKDIR}/policy/${mod}/${mod}.if ${D}${datadir}/selinux/packages/${mod}/
    done

    install -d ${D}${sbindir}
    cat > ${D}${sbindir}/tactiq-selinux-load << 'EOF'
#!/bin/sh
set -e
MODDIR="/usr/share/selinux/packages"
MODULES="tactiq_tpm tactiq_agent tactiq_verifier tactiq_tamper tactiq_vault tactiq_ctl tactiq_rauc"
echo "=== Loading TactiQ SELinux policy modules ==="
for mod in $MODULES; do
    if [ -f "$MODDIR/$mod/$mod.te" ]; then
        echo "  Loading: $mod"
        cd "$MODDIR/$mod"
        make -f /usr/share/selinux/devel/Makefile ${mod}.pp 2>/dev/null || true
        semodule -i ${mod}.pp 2>/dev/null || echo "    WARNING: Failed to load $mod"
    fi
done
echo "=== Restoring file contexts ==="
restorecon -Rv /usr/bin/tactiq-* /etc/tactiq/ /var/lib/tactiq/ /var/log/tactiq/ /etc/rauc/ 2>/dev/null || true
echo "=== Done ==="
sestatus
EOF
    chmod 0755 ${D}${sbindir}/tactiq-selinux-load
}

FILES:${PN} = "${datadir}/selinux/packages ${sbindir}/tactiq-selinux-load"

pkg_postinst:${PN}() {
    if [ -z "$D" ]; then
        ${sbindir}/tactiq-selinux-load || true
    fi
}
