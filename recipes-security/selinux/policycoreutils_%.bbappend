# CVE triage for the SELinux userspace stack (policycoreutils).
# Status codes follow poky meta/conf/cve-check-map.conf.
#
# CVE-2015-3170: affects RHEL selinux-policy, not policycoreutils. CPE false positive.
CVE_STATUS[CVE-2015-3170] = "cpe-incorrect: affects RHEL selinux-policy package, not policycoreutils; not shipped in this image"
#
# CVE-2016-7545: this IS historically a policycoreutils issue (sandbox TIOCSTI),
#   fixed upstream in 2.5 (2016). This build ships 3.10. Additionally, the
#   vulnerable policycoreutils-sandbox package is not installed in the image.
CVE_STATUS[CVE-2016-7545] = "fixed-version: fixed upstream in 2.5 (2016); this build ships 3.10; policycoreutils-sandbox not installed"
#
# CVE-2018-1063: restorecon symlink attack, fixed upstream in 2.5-11 (2018).
CVE_STATUS[CVE-2018-1063] = "fixed-version: fixed upstream in 2.5-11 (2018); this build ships 3.10"
