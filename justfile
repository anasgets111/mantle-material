# Gate before done: syntax, LuaLS types, and the engine's own check.
default: lua types check

lua:
    for f in shell.lua m3/*.lua m3/internal/*.lua demo/*.lua demo/pages/*.lua; do luac5.4 -p "$f"; done

types:
    #!/usr/bin/env bash
    set -euo pipefail
    luals=$(command -v lua-language-server 2>/dev/null || ls -d ~/.local/share/zed/extensions/work/lua/lua-language-server-*/bin/lua-language-server 2>/dev/null | sort -V | tail -1)
    log=$(mktemp -d); trap 'rm -rf "$log"' EXIT
    if ! out=$("$luals" --check "$PWD" --checklevel=Warning --logpath="$log" 2>&1); then
        printf '%s' "$out" | tr '\r' '\n' | grep -E '\.lua:[0-9]+' >&2; exit 1
    fi
    echo "lua type-checks"

check:
    mantle check -c .
