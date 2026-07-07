FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

TACTIQ_MODULES = "tactiq_fixes tactiq_agent tactiq_tpm tactiq_verifier tactiq_tamper tactiq_vault tactiq_ctl tactiq_rauc agentgateway tactiq_edge_daemon"

SRC_URI += " \
    file://tactiq_fixes.te \
    file://tactiq_fixes.fc \
    file://tactiq_fixes.if \
    file://tactiq_agent.te \
    file://tactiq_agent.fc \
    file://tactiq_agent.if \
    file://tactiq_tpm.te \
    file://tactiq_tpm.fc \
    file://tactiq_tpm.if \
    file://tactiq_verifier.te \
    file://tactiq_verifier.fc \
    file://tactiq_verifier.if \
    file://tactiq_tamper.te \
    file://tactiq_tamper.fc \
    file://tactiq_tamper.if \
    file://tactiq_vault.te \
    file://tactiq_vault.fc \
    file://tactiq_vault.if \
    file://tactiq_ctl.te \
    file://tactiq_ctl.fc \
    file://tactiq_ctl.if \
    file://tactiq_rauc.te \
    file://tactiq_rauc.fc \
    file://tactiq_rauc.if \
    file://0001-squashfs-genfscon-tactiq.patch \
    file://agentgateway.te \
    file://agentgateway.fc \
    file://agentgateway.if \
    file://tactiq_edge_daemon.te \
    file://tactiq_edge_daemon.fc \
    file://tactiq_edge_daemon.if \
"

do_compile:prepend() {
    for mod in ${TACTIQ_MODULES}; do
        if [ -f ${UNPACKDIR}/${mod}.te ]; then
            cp ${UNPACKDIR}/${mod}.te ${S}/policy/modules/services/
            cp ${UNPACKDIR}/${mod}.fc ${S}/policy/modules/services/
            cp ${UNPACKDIR}/${mod}.if ${S}/policy/modules/services/
            echo "${mod} = module" >> ${S}/policy/modules.conf
            bbnote "Injected TactiQ SELinux module: ${mod}"
        fi
    done
}

# --- Dev-policy overlay (measurement channel) ---
# Injected only under the tactiq-dev-policy override (set in dev local.conf).
# Prod builds omit the override -> these modules never enter the policy.
TACTIQ_MODULES:append:tactiq-dev-policy = " tactiq_measurement"

SRC_URI:append:tactiq-dev-policy = " \
    file://tactiq_measurement.te \
    file://tactiq_measurement.fc \
    file://tactiq_measurement.if \
"
