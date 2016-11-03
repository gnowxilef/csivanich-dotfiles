#!/usr/env zsh

# prints divider
# _p_divider [bg] [fg]
_p_divider(){
    _p "${_P_DIVIDER:-":"}"
}

# prints $nick if set
_p_nick(){
    _p "$nick"
}

# prints first character of current username
_short_user(){
    printf "$USER" | cut -c1
}

# displays full or shortened (host of host.domain.blah)
# defaults to full, shortened when $_P_HOSTNAME_SHORT is set
_hostname(){
    if [[ -n "$_P_HOSTNAME_SHORT" ]];then
        printf "$(echo $HOST | cut -d '.' -f1)"
    else
        printf '%s' '%M'
    fi
}

# displays first character of username and host
# optionally colors the @host with given color
# _p_main [host color]
# Ex: c@theta
_p_main(){
    _short_user | _p_f "$C_USER"
    _p_f "$C_AT" "@"
    _hostname | _p_f "$C_HOSTNAME"
}

_p_location(){
    _p_f "$C_LOCATION" "%~"
}

_timestamp(){
    date +%s
}

# Caches status of current directory after first call
# Use this if you need to know if the cwd is a git repo
# Ex: _is_git && echo "In a git repo" || echo "No repo here"
_is_git(){
    if [[ -z "$_IS_GIT" ]]; then
        # Run a check for a git repo, if it takes over
        # a second, mark this directory as slow
        start=$(_timestamp)
        git rev-parse --abbrev-ref HEAD >/dev/null 2>&1 && git rev-parse --is-inside-work-tree > /dev/null 2>&1
        _IS_GIT="$?"
        stop=$(_timestamp)
        if [ $((stop - start)) -gt 1 ];then
            _IS_SLOW=1
        fi
    fi

    return $_IS_GIT
}

# Use this if you need to know if the cwd is slow (NFS, etc)
# Uses _IS_SLOW to hold value, is set by _is_git
# Ex: _is_slow && do_something_conservative || do_something_expensive
_is_slow(){
    test "$_IS_SLOW" -eq 1
}

# prints git branch name
# _p_git <border color> <branch name color>
# Ex: (master)
_p_git_branch(){
    if _is_git && ! _is_slow; then
        _p_f "$C_BRANCH" "${_P_BRANCH:-""}["
        git rev-parse --abbrev-ref HEAD | tr -d '\n' | _p_f "$C_BRANCH_TEXT"
        _p_f "$C_BRANCH" "]"
    fi
}

# +insertions ~files_changed -deletions
_p_git_diffs(){
    if _is_git && ! _is_slow;then
        i=$(git diff --shortstat)
        test -z "$i" && return 1
        changes=$(echo "$i" | awk '{print $1}')
        additions=$(echo "$i" | awk '{print $4}')
        deletions=$(echo "$i" | awk '{print $6}')

        if [ "$changes" -gt 0 ]; then
            _p_f "$C_ADDITIONS" "+${additions:-0}"
            _p_space
            _p_f "$C_CHANGES" "~${changes:-0}"
            _p_space
            _p_f "$C_DELETIONS" "-${deletions:-0}"
        fi
    fi
}

# Wrapper of shift which ensures that
# shift is not operating on $# == 0
alias _safe_shift='1=0 && shift'

# prints text with default back and foregrounds
# _p [message]
_p(){
    test -n "$*" && t="$*" || t="$(cat -)"
    test -n "$t" && _p_fk "" "" "$t"
}

# prints text with given back and foreground
# _p_fk [fg_color] [bg_color] <message>
_p_fk(){
    f=$1
    k=$2
    _safe_shift
    _safe_shift
    test -n "$*" && t="$*" || t="$(cat -)"
    test -n "$t" && _p_k "$k" "$t" | _p_f "$f"
}

# prints text with given background
# _p_k [bg_color] <message>
_p_k(){
    v=${1:-"black"}
    _safe_shift
    test -n "$*" && t="$*" || t="$(cat -)"
    test -n "$t" && echo -n "%K{$v}$t%k"
}

# prints text with given foreground
# _p_f [fg_color] <message>
_p_f(){
    v=${1:-"white"}
    _safe_shift
    test -n "$*" && t="$*" || t="$(cat -)"
    test -n "$t" && echo -n "%F{$v}$t%f"
}

# prints a space with correct foreground color
_p_space(){
    _p " "
}

# loads color variables
_p_color_init(){
    C_BLACK="black"
    C_BLUE="blue"
    C_GREEN="green"
    C_MAGENTA="magenta"
    C_RED="red"
    C_WHITE="white"
    C_YELLOW="yellow"
}

# Displays Ruby version string
# By default only shows MAJOR.MINOR version,
# with $_P_RUBY_VERSION_LONG set shows MAJOR.MINOR.PATCHpBUILD
_p_ruby(){
    test "$(find . -maxdepth 1 -name "*.rb" -o -name "*.gem" &>/dev/null | wc -l)" -gt 0 || return
    ruby_version="$(ruby --version | cut -d ' ' -f 2)"
    if [[ -z "$_P_RUBY_VERSION_LONG" ]];then
        ruby_version="$(echo $ruby_version | cut -d '.' -f1,2)"
    fi

    _p_f "$C_RUBY" "("
    _p_f "$C_RUBY_TEXT" "${ruby_version:-"?"}"
    _p_f "$C_RUBY" ")"
}

# Left side of prompt
_p_left(){
    _p_space
    _p_main
    _p_space
    _p_location
    _p_divider
    _p_space
}

# Right side of prompt
_p_right(){
    _p_jobs && _p_space
    _p_git_branch && _p_space
    _p_git_diffs && _p_space
    _p_ruby && _p_space
}

# Inspired by https://github.com/dekz/prompt/blob/master/prompt.zsh#L141
_p_jobs(){
    _jobs=$(jobs -l | wc -l | tr -d '\n')

    if [[ "${_jobs}" -gt 0 ]]; then
        _p_f "$C_JOBS" "{"
        _p_f "$C_JOBS_TEXT" "$_jobs"
        _p_f "$C_JOBS" "}"
    fi
}

_p_benchmark(){
    times=""
    for i in _p_divider _p_nick _p_main _p_location _p_git_branch _p_git_diffs _p_ruby _p_jobs _p_left _p_right; do
        t=$((time ($i) >/dev/null) 2>&1 | rev | cut -d ' ' -f2 | rev)
        times="$times\n$t $i"
    done
    echo $times | sort -n
}

setopt PROMPT_SUBST
PROMPT='$(_p_left)'
RPROMPT='$(_p_right)'
