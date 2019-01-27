#!/bin/ksh
#
# Copyright (c) 2019 Matthew Martin <phy1729@gmail.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

add_mirror() {
	if [[ -n "$uhs" ]]; then
		set -A mirrors "${mirrors[@]}" "$uhs"
	elif [[ -n "$uh" ]]; then
		set -A mirrors "${mirrors[@]}" "$uh"
	fi
}

stderr=$(mktemp) || exit 1

while read -r key value; do
	case "$key" in
		UH) uh="$value";;
		UHS) uhs="$value";;
		0) add_mirror; uh=; uhs=;;
	esac
done <mirrors.dat
add_mirror

printf 'Checking HTTP status codes...\n'
for mirror in "${mirrors[@]}"; do
	for arch in armv7 sparc64; do
		path="${mirror}snapshots/$arch/SHA256"
		printf 'Trying %s\n' "$path"
		http_code=$(curl -A '' -s -o /dev/null -w '%{http_code}' -- "$path" 2>>"$stderr")
		[[ "$http_code" == 200 ]] || set -A error_mirrors "${error_mirrors[@]}" "$http_code $path"
	done
done

printf 'Checking timestamps...\n'
for mirror in "${mirrors[@]}"; do
	path="${mirror}snapshots/sgi/timestamp"
	domain="${mirror#http*://}"
	domain="${domain%%/*}"
	printf 'Trying %s\n' "$path"
	timestamp=$(ftp -MV -U '' -o - -- "$path" 2>>"$stderr")
	timestamp=$(date -r "$timestamp" '+%Y-%m-%d %H:%M:%S')
	set -A timestamps "${timestamps[@]}" "$timestamp $domain"
done

{
	printf 'Errors when fetching files:\n'
	printf '%s\n' "${error_mirrors[@]}"
	cat -- "$stderr"
	printf '\nTimestamps from oldest to newest:\n'
	printf '%s\n' "${timestamps[@]}" | sort
} | ${PAGER:-less}

rm -- "$stderr"
