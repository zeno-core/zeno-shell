const std = @import("std");

pub fn printInitScript(writer: anytype) !void {
    try writer.writeAll(
        \\# zeno-shell integration for bash
        \\# Add to ~/.bashrc: eval "$(zeno_shell init bash)"
        \\
        \\_zeno_record() {
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
        \\    [[ -z "$results" ]] && return
        \\    mapfile -t COMPREPLY <<< "$results"
        \\}
        \\
        \\PROMPT_COMMAND="_zeno_save_exit;_zeno_record${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
        \\complete -F _zeno_complete -o default ''
        \\
    );
}
