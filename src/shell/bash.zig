const std = @import("std");

pub fn printInitScript(writer: anytype) !void {
    try writer.writeAll(
        \\# zeno-shell integration for bash
        \\# Add to ~/.bashrc: eval "$(zeno_shell init bash)"
        \\
        \\_zeno_record() {
        \\    [[ "$_ZENO_LAST_EXIT" -ne 0 ]] && return
        \\    local last_cmd
        \\    last_cmd=$(history 1 | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
        \\    [[ ${#last_cmd} -lt 2 ]] && return
        \\    zeno_shell record "$last_cmd" "$PWD" "$_ZENO_LAST_EXIT" &
        \\}
        \\
        \\_zeno_save_exit() { _ZENO_LAST_EXIT=$?; }
        \\
        \\_zeno_complete() {
        \\    local results
        \\    results=$(zeno_shell query "${COMP_LINE}" "$PWD" 2>/dev/null)
        \\    if [[ -n "$results" ]]; then
        \\        local wordStart=$(( COMP_POINT - ${#COMP_WORDS[COMP_CWORD]} ))
        \\        local linePrefix="${COMP_LINE:0:$wordStart}"
        \\        local stripped=()
        \\        while IFS= read -r line; do
        \\            if [[ "$line" == "$linePrefix"* ]]; then
        \\                stripped+=("${line#"$linePrefix"}")
        \\            else
        \\                stripped+=("$line")
        \\            fi
        \\        done <<< "$results"
        \\        COMPREPLY=("${stripped[@]}")
        \\        return
        \\    fi
        \\    local cmd="${COMP_WORDS[0]}"
        \\    local native
        \\    native=$(complete -p "$cmd" 2>/dev/null)
        \\    if [[ -n "$native" ]]; then
        \\        local nativeFn
        \\        nativeFn=$(echo "$native" | grep -oP '(?<=-F )\S+')
        \\        if [[ -n "$nativeFn" ]]; then
        \\            "$nativeFn"
        \\        fi
        \\    else
        \\        mapfile -t COMPREPLY < <(compgen -f -- "${COMP_WORDS[COMP_CWORD]}")
        \\    fi
        \\}
        \\
        \\PROMPT_COMMAND="_zeno_save_exit;_zeno_record${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
        \\complete -F _zeno_complete -o default ''
        \\complete -F _zeno_complete -o default zig
        \\complete -F _zeno_complete -o default git
        \\
    );
}
