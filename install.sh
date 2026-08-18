#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ] || [ "$(basename "${BASH:-sh}")" = "sh" ]; then
	echo "install.sh: please run this installer with bash, for example:" >&2
	echo "  curl -fsSL https://raw.githubusercontent.com/Q-CAD/MatEnsemble/refs/heads/mcp_refactor/install.sh | bash" >&2
	exit 2
fi

set -euo pipefail

REPO_URL="${MATENSEMBLE_REPO_URL:-https://github.com/Q-CAD/MatEnsemble.git}"
GHCR_NAMESPACE="${MATENSEMBLE_GHCR_NAMESPACE:-ghcr.io/q-cad/matensemble}"
REPO_URL="${MATENSEMBLE_REPO_URL:-https://github.com/FredDude2004/MatEnsemble.git}"

err() {
	echo "install.sh: error: $*" >&2
	exit 1
}

prompt_read() {
	local prompt="$1"
	local value
	if [[ ! -r /dev/tty ]]; then
		err "interactive prompts require a terminal; run this script from an interactive shell"
	fi
	read -r -p "$prompt" value </dev/tty
	printf '%s\n' "$value"
}

prompt_yes_no() {
	local prompt="$1"
	local answer
	while true; do
		answer="$(prompt_read "$prompt")"
		case "${answer:-y}" in
		y | Y | yes | YES) return 0 ;;
		n | N | no | NO) return 1 ;;
		*) echo "Please answer y or n." >&2 ;;
		esac
	done
}

expand_path() {
	local path="$1"
	case "$path" in
	"~") echo "$HOME" ;;
	"~/"*) echo "$HOME/${path#~/}" ;;
	*) echo "$path" ;;
	esac
}

choose_system() {
	local choice
	while true; do
		echo "Which system will run MatEnsemble?" >&2
		echo "  1. Frontier   (Apptainer)" >&2
		echo "  2. Perlmutter (Podman-HPC)" >&2
		echo "  3. Pathfinder (Apptainer)" >&2
		choice="$(prompt_read "Choose a system [1-3]: ")"
		case "$choice" in
		1 | frontier | Frontier) echo "frontier"; return ;;
		2 | perlmutter | Perlmutter) echo "perlmutter"; return ;;
		3 | pathfinder | Pathfinder) echo "pathfinder"; return ;;
		*) echo "Please choose 1, 2, or 3." >&2 ;;
		esac
	done
}

choose_install_root() {
	local default_root
	local path
<<<<<<< HEAD
	path="$(prompt_read "Where should MatEnsemble be installed? ")"
	[[ -n "$path" ]] || err "install path is required"
=======
	default_root="${SCRATCH:-$PWD}/MatEnsemble"
	path="$(prompt_read "Where should MatEnsemble be installed? [$default_root]: ")"
	path="${path:-$default_root}"
>>>>>>> 26ca114 (updated install script)
	echo "$path"
}

clone_or_reuse_repo() {
	local repo_dir="$1"
	mkdir -p "$(dirname "$repo_dir")"
	if [[ -d "$repo_dir/.git" ]]; then
		echo "Using existing MatEnsemble checkout: $repo_dir"
		return
	fi
	if [[ -e "$repo_dir" ]] && [[ -n "$(find "$repo_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
		err "$repo_dir exists and is not an empty git checkout"
	fi
	git clone --depth=1 "$REPO_URL" "$repo_dir"
}

ensure_uv() {
	if command -v uv >/dev/null 2>&1; then
		return
	fi
	echo "uv is required by the MCP server; installing it now."
	command -v curl >/dev/null 2>&1 || err "curl is required to install uv"
	curl -LsSf https://astral.sh/uv/install.sh | sh
	[[ -x "$HOME/.local/bin/uv" ]] || err "uv was not found after installation"
	export PATH="$HOME/.local/bin:$PATH"
}

install_cli() {
	local repo_dir="$1"
	local system="$2"
	local source="$repo_dir/src/cli/matensemble-$system"
	local target_dir="${HOME}/.local/bin"
	local target="$target_dir/matensemble"
	[[ -f "$source" ]] || err "CLI script not found: $source"
	mkdir -p "$target_dir"
	install -m 0755 "$source" "$target"
	echo "Installed MatEnsemble CLI for $system at $target"
	case ":$PATH:" in
	*":$target_dir:"*) ;;
	*) echo "Add this to your shell rc file if needed: export PATH=\"$target_dir:\$PATH\"" ;;
	esac
}

matensemble_version() {
	local repo_dir="$1"
	awk -F '"' '/^version = / { print $2; exit }' "$repo_dir/pyproject.toml"
}

install_container() {
	local repo_dir="$1"
	local install_root="$2"
	local system="$3"
	local cli="$4"
	local version
	local image
	local container_dir
	local container_file

	if ! prompt_yes_no "Install the latest MatEnsemble container for $system? [Y/n] "; then
		return 0
	fi

	version="$(matensemble_version "$repo_dir")"
	[[ -n "$version" ]] || err "could not read the MatEnsemble version from $repo_dir/pyproject.toml"
	image="ghcr.io/freddude2004/matensemble:${system}-v${version}"

	if [[ "$system" == "perlmutter" ]]; then
		command -v podman-hpc >/dev/null 2>&1 || err "podman-hpc is required to install the Perlmutter container"
		echo "Installing MatEnsemble $version container for Perlmutter..."
		podman-hpc pull "$image"
		"$cli" set-image "$image"
		return 0
	fi

	command -v apptainer >/dev/null 2>&1 || err "apptainer is required to install the $system container"
	container_dir="$install_root/containers/$system"
	container_file="$container_dir/matensemble-v${version}.sif"
	mkdir -p "$container_dir"

	if [[ -f "$container_file" ]]; then
		echo "Using existing MatEnsemble container: $container_file"
	else
		echo "Installing MatEnsemble $version container for $system..."
		apptainer build "$container_file" "docker://$image"
	fi

	"$cli" set-image "$container_file"
}

write_configs() {
	local repo_dir="$1"
	local campaigns_dir="$2"
	local system="$3"
	local uv_command="$4"
	local codex_dir="$campaigns_dir/.codex"
	local copilot_dir="$campaigns_dir/.copilot"
	local gemini_dir="$campaigns_dir/.gemini"
	local vscode_dir="$campaigns_dir/.vscode"

	mkdir -p "$codex_dir" "$copilot_dir" "$gemini_dir" "$vscode_dir"

	cat >"$codex_dir/config.toml" <<EOF_CODEX
[mcp_servers.matensemble]
command = "$uv_command"
args = [
  "run",
  "--directory",
  "$repo_dir",
  "--package",
  "mcp-matensemble",
  "mcp-matensemble",
  "--system",
  "$system",
]
cwd = "$campaigns_dir"
startup_timeout_sec = 120
EOF_CODEX

	cat >"$campaigns_dir/.mcp.json" <<EOF_CLAUDE
{
  "mcpServers": {
    "matensemble": {
      "command": "$uv_command",
      "args": [
        "run",
        "--directory",
        "$repo_dir",
        "--package",
        "mcp-matensemble",
        "mcp-matensemble",
        "--system",
        "$system"
      ],
      "cwd": "$campaigns_dir"
    }
  }
}
EOF_CLAUDE

	cat >"$copilot_dir/mcp-config.json" <<EOF_COPILOT
{
  "mcpServers": {
    "matensemble": {
      "type": "local",
      "command": "$uv_command",
      "args": [
        "run",
        "--directory",
        "$repo_dir",
        "--package",
        "mcp-matensemble",
        "mcp-matensemble",
        "--system",
        "$system"
      ],
      "cwd": "$campaigns_dir",
      "env": {},
      "tools": ["*"]
    }
  }
}
EOF_COPILOT

	cat >"$gemini_dir/settings.json" <<EOF_GEMINI
{
  "mcpServers": {
    "matensemble": {
      "command": "$uv_command",
      "args": [
        "run",
        "--directory",
        "$repo_dir",
        "--package",
        "mcp-matensemble",
        "mcp-matensemble",
        "--system",
        "$system"
      ],
      "cwd": "$campaigns_dir",
      "env": {},
      "timeout": 120000
    }
  }
}
EOF_GEMINI

	cat >"$vscode_dir/mcp.json" <<EOF_VSCODE
{
  "servers": {
    "matensemble": {
      "type": "stdio",
      "command": "$uv_command",
      "args": [
        "run",
        "--directory",
        "$repo_dir",
        "--package",
        "mcp-matensemble",
        "mcp-matensemble",
        "--system",
        "$system"
      ],
      "cwd": "$campaigns_dir"
    }
  }
}
EOF_VSCODE

	cat >"$campaigns_dir/README.md" <<EOF_README
# MatEnsemble Campaigns

This workspace is configured for the MatEnsemble MCP server on \`$system\`.

The MatEnsemble checkout lives at:

\`\`\`text
$repo_dir
\`\`\`

The MCP server command is:

\`\`\`bash
uv run --directory "$repo_dir" --package mcp-matensemble mcp-matensemble --system "$system"
\`\`\`
EOF_README

	echo "Wrote MCP configs under $campaigns_dir"
}

main() {
	local system
	local install_root
	local repo_dir
	local campaigns_dir
	local uv_command
	local cli

	system="$(choose_system)"
	install_root="$(choose_install_root)"
	install_root="$(expand_path "$install_root")"
	install_root="$(cd "$install_root" 2>/dev/null && pwd || {
		mkdir -p "$install_root"
		cd "$install_root"
		pwd
	})"
	repo_dir="$install_root/.matensemble"
	campaigns_dir="$install_root/matensemble_campaigns"

	command -v git >/dev/null 2>&1 || err "git is required"
	clone_or_reuse_repo "$repo_dir"
	mkdir -p "$campaigns_dir"
	ensure_uv
	uv_command="$(command -v uv)"

	install_cli "$repo_dir" "$system"
	cli="$HOME/.local/bin/matensemble"
	install_container "$repo_dir" "$install_root" "$system" "$cli"
	write_configs "$repo_dir" "$campaigns_dir" "$system" "$uv_command"

	echo
	echo "MatEnsemble install root: $install_root"
	echo "Repository checkout: $repo_dir"
	echo "Campaign workspace: $campaigns_dir"
	echo "Next: cd \"$campaigns_dir\" and start your preferred agent."
}

main "$@"
