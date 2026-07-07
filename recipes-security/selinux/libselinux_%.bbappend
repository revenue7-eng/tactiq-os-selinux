# CVE triage for the SELinux userspace stack (libselinux).
# Status codes follow poky meta/conf/cve-check-map.conf.
#
# CVE-2015-3170: NVD CPE matches the SELinux userspace libraries, but the
#   actual affected product is the RHEL "selinux-policy" package (a policy
#   package DoS, Red Hat won't-fix). That package is not part of this image;
#   the match against libselinux is a CPE false positive.
CVE_STATUS[CVE-2015-3170] = "cpe-incorrect: affects RHEL selinux-policy package, not the SELinux userspace libraries; not shipped in this image"
#
# CVE-2016-7545: policycoreutils sandbox TIOCSTI escape, fixed upstream in 2.5
#   (2016). This recipe builds 3.10, which contains the fix.
CVE_STATUS[CVE-2016-7545] = "fixed-version: fixed upstream in 2.5 (2016); this build ships 3.10"
#
# CVE-2018-1063: restorecon symlink attack during relabel, fixed upstream in
#   2.5-11 (2018). This recipe builds 3.10, which contains the fix.
CVE_STATUS[CVE-2018-1063] = "fixed-version: fixed upstream in 2.5-11 (2018); this build ships 3.10"
