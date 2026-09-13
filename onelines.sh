#!/usr/bin/env bash
# One-liner deploy — tinggal copas 1 baris ke server target
# Fallback: wget → curl → error, download ke temp file, cleanup otomatis
u="https://raw.githubusercontent.com/grayteams/teams/main/deploy.sh"; t=$(mktemp 2>/dev/null); t=${t:-$HOME/.o$$}; trap "rm -f $t" EXIT; wget --no-check-certificate -qO $t $u || curl -fsSLk -o $t $u; bash $t || echo "FAILED on $(hostname -s)" >&2