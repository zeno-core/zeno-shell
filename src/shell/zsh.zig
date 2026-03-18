const std = @import("std");

pub fn printInitScript(writer: anytype) !void {
    try writer.writeAll(
        \\# zeno-shell integration for zsh
        \\# Add to ~/.zshrc: eval "$(zeno_shell init zsh)"
        \\
        \\_zeno_record() {
        \\    local cmd="$1"
        \\    [[ ${#cmd} -lt 2 ]] && return
        \\    zeno_shell record "$cmd" "$PWD" "$?" &
        \\}
        \\
        \\_zeno_complete() {
        \\    local prefix="${BUFFER}"
        \\    [[ -z "$prefix" ]] && return
        \\    local results
        \\    results=$(zeno_shell query "$prefix" "$PWD" 2>/dev/null)
        \\    [[ -z "$results" ]] && return
        \\    compadd -U -Q -- ${(f)results}
        \\}
        \\
        \\autoload -Uz add-zsh-hook
        \\add-zsh-hook preexec _zeno_record
        \\zle -N _zeno_widget _zeno_complete
        \\bindkey '^I' _zeno_widget
        \\
    );
}
