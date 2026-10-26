# Git Bash integration emitted by `nvm.exe env --shell bash`.
# Only fixed, allowlisted Base64 data records change this shell's environment.
nvm() {
    local token command='' locked=0 print_only=0 output status line key value payload
    for token in "$@"; do
        if (( ! locked )); then
            [[ $token == -- ]] && locked=1
            case "$token" in --llm|--json|--help|-h) print_only=1;; esac
            case "$token" in --yes|--json|--llm) continue;; esac
        fi
        [[ -n $command ]] || command=$token
    done
    case "$command:$print_only" in
        use:0|install:0|uninstall:0|rm:0|deactivate:0)
            if output=$(ZNVM_SHELL=bash MSYS2_ARG_CONV_EXCL='*' "$__znvm_exe" "$@"); then
                status=0
            else
                status=$?
            fi
            if (( status != 0 )); then
                [[ -z $output ]] || printf '%s\n' "$output" >&2
                return "$status"
            fi
            while IFS= read -r line; do
                line=${line%$'\r'}
                if [[ $line =~ ^ZNVM_ENV\|(PATH|ZNVM_CURRENT|NVM_BIN|NVM_INC|NPM_CONFIG_PREFIX)\|([A-Za-z0-9+/]*={0,2})$ ]]; then
                    key=${BASH_REMATCH[1]} payload=${BASH_REMATCH[2]}
                    # The suffix preserves trailing newlines through command substitution.
                    value=$(printf '%s' "$payload" | base64 --decode && printf '.') || return 65
                    value=${value%.}
                    if [[ $key == PATH ]]; then
                        value=$(cygpath --path --unix "$value") || return 65
                    elif [[ $key == NVM_BIN || $key == NVM_INC ]]; then
                        value=$(cygpath --unix "$value") || return 65
                    fi
                    printf -v "$key" '%s' "$value"
                    export "$key"
                elif [[ $line =~ ^ZNVM_UNSET\|(ZNVM_CURRENT|NVM_BIN|NVM_INC|NPM_CONFIG_PREFIX)$ ]]; then
                    unset "${BASH_REMATCH[1]}"
                elif [[ -n $line ]]; then
                    printf '%s\n' "$line"
                fi
            done <<< "$output"
            hash -r
            return 0
            ;;
        *) ZNVM_SHELL=bash MSYS2_ARG_CONV_EXCL='*' "$__znvm_exe" "$@" ;;
    esac
}
