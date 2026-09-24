#!/usr/bin/env bash

set -euo pipefail

usage() {
    printf 'Usage: %s <tool-directory>/requirements.txt\n' "$0" >&2
}

if [[ $# -ne 1 ]]; then
    usage
    exit 2
fi

requirements_file=$1
if [[ ! -f $requirements_file || ! -r $requirements_file ]]; then
    printf 'Error: requirements file is not readable: %s\n' "$requirements_file" >&2
    exit 1
fi

requirements_dir=${requirements_file%/*}
if [[ $requirements_dir == "$requirements_file" ]]; then
    requirements_dir=.
fi
tool_name=${requirements_dir##*/}
if [[ -z $tool_name || $tool_name == . || $tool_name == .. || ! $tool_name =~ ^[[:alnum:]_.-]+$ ]]; then
    printf 'Error: put requirements.txt in a directory named for the tool command.\n' >&2
    printf 'Example: tools/hatch/requirements.txt exposes the "hatch" command.\n' >&2
    exit 1
fi

: "${HOME:?HOME must be set}"

data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
venv_dir="$data_home/python-tools/$tool_name"
bin_dir="$HOME/.local/bin"
launcher="$bin_dir/$tool_name"
tool_executable="$venv_dir/bin/$tool_name"

if [[ -L $venv_dir ]]; then
    printf 'Error: refusing to clear symlinked environment path: %s\n' "$venv_dir" >&2
    exit 1
fi
if [[ -e $launcher || -L $launcher ]]; then
    if [[ ! -L $launcher || $(readlink "$launcher") != "$tool_executable" ]]; then
        printf 'Error: command path already exists: %s\n' "$launcher" >&2
        exit 1
    fi
fi

mkdir -p "$(dirname "$venv_dir")" "$bin_dir"
if ! python3.12 -m venv --clear "$venv_dir"; then
    printf 'Error: failed to create a virtual environment. Ensure this Python includes venv and ensurepip.\n' >&2
    exit 1
fi

"$venv_dir/bin/python" -m pip install \
    --require-hashes \
    --only-binary=:all: \
    -r "$requirements_file"

if [[ ! -x $tool_executable ]]; then
    printf 'Error: installation succeeded, but no "%s" executable was created.\n' "$tool_name" >&2
    printf 'The requirements directory name must match the installed command.\n' >&2
    exit 1
fi

if [[ ! -e $launcher && ! -L $launcher ]]; then
    ln -s "$tool_executable" "$launcher"
fi

printf 'Installed %s in %s\n' "$tool_name" "$venv_dir"
printf 'Command link: %s\n' "$launcher"
case ":${PATH:-}:" in
    *":$bin_dir:"*) ;;
    *) printf 'Add %s to PATH to run %s from any directory.\n' "$bin_dir" "$tool_name" ;;
esac
