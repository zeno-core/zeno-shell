const std = @import("std");

pub fn printInitScript(writer: anytype) !void {
    try writer.writeAll(
        \\# zeno-shell integration for zsh
        \\# Add to ~/.zshrc: eval "$(zeno_shell init zsh)"
        \\
        \\_zeno_save_exit() { _ZENO_LAST_EXIT=$?; }
        \\
        \\_zeno_record() {
        \\    local cmd="$1"
        \\    [[ ${#cmd} -lt 2 ]] && return
        \\    [[ "$_ZENO_LAST_EXIT" -ne 0 ]] && return
        \\    (zeno_shell record "$cmd" "$PWD" "$_ZENO_LAST_EXIT" >/dev/null 2>&1 &)
        \\}
        \\
        \\_zeno_widget() {
        \\    local results
        \\    results=$(zeno_shell query "$BUFFER" "$PWD" 2>/dev/null)
        \\    if [[ -n "$results" ]]; then
        \\        local top="${results%%$'\\n'*}"
        \\        BUFFER="$top"
        \\        CURSOR=${#BUFFER}
        \\        zle redisplay
        \\        return
        \\    fi
        \\    zle expand-or-complete
        \\}
        \\
        \\autoload -Uz add-zsh-hook
        \\add-zsh-hook preexec _zeno_record
        \\add-zsh-hook precmd _zeno_save_exit
        \\zle -N _zeno_widget
        \\bindkey '^I' _zeno_widget
        \\
    );
}
