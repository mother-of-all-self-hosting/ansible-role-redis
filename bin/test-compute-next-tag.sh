#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Redis 8.10.1 which has already
# seen two releases of it (v8.10.1-0 and v8.10.1-1).
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/handlers" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	# Mirrors how defaults/main.yml really looks: the version carries the
	# Renovate annotation above it and is referenced by derived variables
	# below it. The commented-out assignment stands in for prose mentioning
	# the variable; none of the three may be mistaken for the version itself.
	cat > defaults/main.yml <<-'EOF'
		# Previously `redis_version: 7.4.5`, before the move to Redis 8.
		# renovate: datasource=docker depName=redis versioning=semver
		redis_version: 8.10.1

		redis_container_image_tag: "{{ redis_version }}-alpine"
	EOF

	printf 'placeholder\n' > handlers/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/redis.conf.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local release_number
	for release_number in 0 1; do
		git tag "v8.10.1-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|redis_version: 8.10.1|redis_version: 8.12.0|' defaults/main.yml"
revert_version="sed -i 's|redis_version: 8.12.0|redis_version: 8.10.1|' defaults/main.yml"
prefix_version="sed -i 's|redis_version: 8.10.1|redis_version: v8.12.0|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_handler="printf 'a handler\n' >> handlers/main.yml"
edit_template="printf 'a line\n' >> templates/redis.conf.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v8.12.0-0 "$(merge "$bump_version")"
expect 'task edit'    v8.12.0-1 "$(merge "$edit_task")"
expect 'template'     v8.12.0-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v8.10.1-2 "$(merge "$edit_task")"
expect 'version bump' v8.12.0-0 "$(merge "$bump_version")"

scenario 'Commits that do not affect the role'
expect 'README'   ''         "$(merge "$edit_readme")"
expect 'a script' ''         "$(merge "$edit_script")"
expect 'a task'   v8.10.1-2 "$(merge "$edit_task")"

# This role, unlike some of its siblings, has handlers, and they are as much a
# part of what a playbook run does as its tasks are.
scenario 'A handler edit is a role change'
expect 'a handler' v8.10.1-2 "$(merge "$edit_handler")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v8.10.1-$release_number"
done
expect 'a task' v8.10.1-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v8.10.1-1 already published, so there is
# nothing new to release.
expect 'a revert' ''         "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v8.10.1-2 "$(merge "$revert_version && $edit_task")"

scenario 'A version value carrying a leading v does not double it in the tag'
expect 'version bump' v8.12.0-0 "$(merge "$prefix_version")"

# The commented-out assignment above the version and the derived image tag
# below it both mention the version, and neither may be read as the version
# itself - a release computed from either would carry the wrong number.
scenario 'Neither a comment nor a derived variable is read as the version'
expect 'a task' v8.10.1-2 "$(merge "$edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
