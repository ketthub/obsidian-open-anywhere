#!/usr/bin/env python3
# open-in-obsidian.py — Windows port of obsidian-open-anywhere
#
# Copy external markdown files into your Obsidian Vault's inbox folder,
# then open them in Obsidian. Never overwrites: filename collisions are
# resolved by appending a timestamp suffix.
#
# Part of: obsidian-open-anywhere
# https://github.com/ketthub/obsidian-open-anywhere
#
# Behavior parity with src/open-in-obsidian.sh (macOS), plus one improvement:
# files that are ALREADY inside the vault are opened directly instead of
# being copied again.
#
# Usage:
#   open-in-obsidian.py /path/to/file1.md [/path/to/file2.md ...]
#
# Windows note: this script is registered as the .md file handler by
# install.bat. It is executed with pythonw (no console window). Errors are
# written to the log file.

import sys
import os
import shutil
import urllib.parse
import datetime
import configparser

DEFAULTS = {
    "vault_path": "",
    "vault_name": "",
    "inbox_subpath": "Inbox",
    "log_file": os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")),
        "obsidian-open-anywhere",
        "obsidian-open-anywhere.log",
    ),
    "allowed_extensions": "md markdown txt",
}

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(SCRIPT_DIR, "config.ini")


def load_config():
    values = dict(DEFAULTS)
    cfg = configparser.ConfigParser()
    if os.path.exists(CONFIG_FILE):
        try:
            cfg.read(CONFIG_FILE, encoding="utf-8")
            sec = cfg["obsidian"] if cfg.has_section("obsidian") else {}
            for key in values:
                val = sec.get(key, "").strip()
                if val:
                    values[key] = val
        except Exception:
            pass
    # Expand %VAR% / ~ style entries minimally
    vault = values["vault_path"].strip().strip('"')
    if vault.startswith("~"):
        vault = os.path.expanduser(vault)
    values["vault_path"] = vault
    if not values["vault_name"]:
        values["vault_name"] = os.path.basename(os.path.normpath(vault))
    return values


def log(msg, log_file):
    try:
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        with open(log_file, "a", encoding="utf-8") as f:
            f.write("[%s] %s\n" % (datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"), msg))
    except Exception:
        pass


def url_encode(s):
    return urllib.parse.quote(s, safe="")


def open_in_obsidian(vault_name, rel_path):
    url = "obsidian://open?vault=%s&file=%s" % (url_encode(vault_name), url_encode(rel_path))
    try:
        os.startfile(url)  # ShellExecute hands the URI to the default handler (Obsidian)
    except OSError as e:
        raise RuntimeError("failed to open %s: %s" % (url, e))


def main(argv):
    cfg = load_config()
    log_file = cfg["log_file"]
    log("START argv=%r" % (argv,), log_file)

    vault_path = os.path.normpath(cfg["vault_path"])
    if not vault_path or not os.path.isdir(vault_path):
        log("ERROR: VAULT_PATH does not exist: %s" % cfg["vault_path"], log_file)
        return 2

    if not argv:
        log("ERROR: no input file", log_file)
        return 1

    inbox_dir = os.path.join(vault_path, cfg["inbox_subpath"])
    try:
        os.makedirs(inbox_dir, exist_ok=True)
    except OSError as e:
        log("ERROR: cannot create inbox %s: %s" % (inbox_dir, e), log_file)
        return 2

    allowed = cfg["allowed_extensions"].split()

    for src in argv:
        src = src.strip().strip('"')
        if not os.path.isfile(src):
            log("SKIP (not a file): %s" % src, log_file)
            continue

        # Improvement over the macOS script: files already inside the vault
        # are opened in place, never copied.
        src_abs = os.path.abspath(src)
        try:
            rel = os.path.relpath(src_abs, vault_path)
            inside = not rel.startswith("..")
        except ValueError:
            inside = False
        if inside:
            log("OPEN (in vault): %s" % rel, log_file)
            try:
                open_in_obsidian(cfg["vault_name"], rel.replace("\\", "/"))
            except RuntimeError as e:
                log("ERROR: %s" % e, log_file)
            continue

        base = os.path.basename(src_abs)
        stem, ext = os.path.splitext(base)
        ext_lower = ext[1:].lower()
        if ext_lower not in allowed:
            log("SKIP (extension not allowed: .%s): %s" % (ext_lower, src), log_file)
            continue

        dst = os.path.join(inbox_dir, base)
        if os.path.exists(dst):
            stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
            dst = os.path.join(inbox_dir, "%s-%s%s" % (stem, stamp, ext))
            suffix = 1
            while os.path.exists(dst):
                dst = os.path.join(inbox_dir, "%s-%s-%d%s" % (stem, stamp, suffix, ext))
                suffix += 1

        try:
            shutil.copy2(src_abs, dst)  # copy2 == cp -p (preserves mtime)
        except OSError as e:
            log("ERROR: copy failed %s -> %s: %s" % (src, dst, e), log_file)
            continue
        log("COPY: %s -> %s" % (src, dst), log_file)

        rel_path = os.path.join(cfg["inbox_subpath"], os.path.basename(dst)).replace("\\", "/")
        try:
            open_in_obsidian(cfg["vault_name"], rel_path)
        except RuntimeError as e:
            log("ERROR: %s" % e, log_file)

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
