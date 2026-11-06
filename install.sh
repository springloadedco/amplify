#!/usr/bin/env bash
# Installs or updates Amplify in your Amp personal plugins, so it loads in every thread and orb.
#
#   curl -fsSL https://raw.githubusercontent.com/springloadedco/amplify/main/install.sh | bash
#
# Pass --workspace to install it for your whole Amp workspace instead (workspace admins):
#
#   curl -fsSL https://raw.githubusercontent.com/springloadedco/amplify/main/install.sh | bash -s -- --workspace
#
# Run it again to update. It needs the Amp CLI (signed in) and git.
set -euo pipefail

source_repo=${AMPLIFY_SOURCE:-https://github.com/springloadedco/amplify}
scope=user
for arg in "$@"; do
	case "$arg" in
	--workspace) scope=workspace ;;
	*) echo "Unknown option: $arg (use --workspace or nothing)" >&2; exit 1 ;;
	esac
done

say() { printf '\033[1;35m[amplify]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[amplify]\033[0m %s\n' "$*" >&2; exit 1; }

command -v amp >/dev/null || fail "Install the Amp CLI first: https://ampcode.com/docs/cli"
command -v git >/dev/null || fail "Install git first."

# Find the plugins repository for this scope. The JSON is a flat list of objects with no nesting.
repo=$(amp plugins repositories --json 2>/dev/null | tr -d ' \n' | tr '}' '\n' | grep "\"scope\":\"$scope\"" || true)
[ -n "$repo" ] || fail "Amp has no $scope plugins repository for you. Run \`amp login\`, then try again."
field() { printf '%s' "$repo" | grep -o "\"$1\":[^,]*" | head -n1 | cut -d: -f2- | tr -d '"'; }
[ "$(field viewerCanWrite)" = true ] || fail "You cannot write the $scope plugins repository. Ask a workspace admin, or install without --workspace."

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [ "$(field exists)" = true ]; then
	amp clone "$scope-plugins" "$work/plugins" >/dev/null
else
	# Amp creates the repository on the first push.
	git init -q -b main "$work/plugins"
	git -C "$work/plugins" config credential.helper '!amp git-credential-helper'
	git -C "$work/plugins" remote add origin "$(field cloneURL)"
fi

say "Downloading Amplify from $source_repo"
git clone -q --depth 1 "$source_repo" "$work/source"
version=$(git -C "$work/source" rev-parse --short HEAD)

target="$work/plugins/amplify"
rm -rf "$target"
mkdir -p "$target"
cp -R "$work/source/index.ts" "$work/source/skills" "$target/"
[ -f "$work/source/LICENSE" ] && cp "$work/source/LICENSE" "$target/"

cd "$work/plugins"
git add -A amplify
if git diff --cached --quiet; then
	say "Amplify $version is already installed in your $scope plugins."
	exit 0
fi
git -c user.name="${GIT_AUTHOR_NAME:-$(git config user.name || echo Amplify)}" \
	-c user.email="${GIT_AUTHOR_EMAIL:-$(git config user.email || echo amplify@users.noreply.github.com)}" \
	commit -q -m "Install Amplify $version" -m "From $source_repo"
git push -q origin HEAD

say "Installed Amplify $version in your $scope plugins."
say "New Amp threads load it automatically. In an open thread, run \`plugins: reload\` from the command palette."
say "Then, in a Laravel app, ask Amp: \"Set up orbs for this app.\""
