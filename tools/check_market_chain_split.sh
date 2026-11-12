#!/bin/sh
# Market Chain Split: first and return plates must be the locked, distinct bytes.
set -eu
cd "$(dirname "$0")/.."
food=assets/events/market_food.webp
next=assets/events/market_next.webp
food_md5=50fdf415e0768bf303e3909612416b36
next_md5=675d3f1fdb33d4e295f8ada40182acee
got_food=$(md5sum "$food" | awk '{print $1}')
got_next=$(md5sum "$next" | awk '{print $1}')
printf '%s  %s\n' "$got_food" "$food"
printf '%s  %s\n' "$got_next" "$next"
if [ "$got_food" != "$food_md5" ]; then
	echo "FAIL $food md5 $got_food (want $food_md5)" >&2
	exit 1
fi
if [ "$got_next" != "$next_md5" ]; then
	echo "FAIL $next md5 $got_next (want $next_md5)" >&2
	exit 1
fi
if [ "$got_food" = "$got_next" ]; then
	echo "FAIL plates are identical" >&2
	exit 1
fi
echo "ok distinct market plates"
