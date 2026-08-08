# CVE triage for the SELinux userspace stack (libsemanage).
# Status codes follow poky meta/conf/cve-check-map.conf.
CVE_STATUS[CVE-2015-3170] = "cpe-incorrect: affects RHEL selinux-policy package, not libsemanage; not shipped in this image"
CVE_STATUS[CVE-2016-7545] = "fixed-version: policycoreutils sandbox issue fixed upstream in 2.5 (2016); this build ships 3.10"
CVE_STATUS[CVE-2018-1063] = "fixed-version: fixed upstream in 2.5-11 (2018); this build ships 3.10"
