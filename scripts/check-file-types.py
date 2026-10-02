#!/usr/bin/env python3
"""Fail if a type labelled in a .fc file is declared in this layer without
the file_type attribute.

A file type declared bare (no refpolicy macro, no typeattribute) is outside
every rule written against file_type: PID 1 cannot search it, root cannot
stat it, relabel tools have no rights on it. The defect only shows up on
hardware, under enforcing, so it is checked here instead.

Usage: check-file-types.py [policy-dir]   (default: recipes-security/refpolicy/files)
"""
import pathlib
import re
import sys

# Macros that give their type argument file_type (or a subclass of it).
FIRST_ARG = (
    "files_type", "files_config_file", "files_tmp_file", "files_runtime_file",
    "files_pid_file", "files_lock_file", "files_mountpoint", "files_security_file",
    "logging_log_file", "init_unit_file", "systemd_unit_file", "dev_node",
    "fs_type", "application_executable_file", "corecmd_executable_file",
    "miscfiles_cert_type", "init_script_file",
)
# Macros whose second argument is the entrypoint file type.
SECOND_ARG = ("init_daemon_domain", "application_domain", "domain_entry_file",
              "init_system_domain", "systemd_domain_template")

REQUIRE = re.compile(r"(?:gen_)?require\s*(?:\{.*?\}|\(\s*`.*?'\s*\))", re.S)
COMMENT = re.compile(r"#[^\n]*")


def main() -> int:
    d = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "recipes-security/refpolicy/files")
    labelled = {}
    for fc in sorted(d.glob("*.fc")):
        for t in re.findall(r"gen_context\(\s*system_u:object_r:([a-z0-9_]+)\s*,", fc.read_text()):
            labelled.setdefault(t, fc.name)

    declared = {}
    attributed = set()
    for te in sorted(d.glob("*.te")):
        body = REQUIRE.sub("", COMMENT.sub("", te.read_text()))
        for t in re.findall(r"^\s*type\s+([a-z0-9_]+)\s*;", body, re.M):
            declared.setdefault(t, te.name)
        for t, attrs in re.findall(r"^\s*type\s+([a-z0-9_]+)\s*,([^;]*);", body, re.M):
            declared.setdefault(t, te.name)
            if "file_type" in attrs:
                attributed.add(t)
        for m in FIRST_ARG:
            attributed.update(re.findall(rf"\b{m}\(\s*([a-z0-9_]+)", body))
        for m in SECOND_ARG:
            attributed.update(re.findall(rf"\b{m}\(\s*[a-z0-9_]+\s*,\s*([a-z0-9_]+)", body))
        for t, attrs in re.findall(r"typeattribute\s+([a-z0-9_]+)\s+([^;]+);", body):
            if "file_type" in attrs:
                attributed.add(t)

    bad = sorted(t for t in labelled if t in declared and t not in attributed)
    for t in bad:
        print(f"::error file={d}/{declared[t]}::{t} is labelled in {labelled[t]} "
              f"but declared without file_type; use files_type(), files_config_file(), "
              f"logging_log_file() or another refpolicy file macro")
    print(f"checked {sum(1 for t in labelled if t in declared)} file types, {len(bad)} bare")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
