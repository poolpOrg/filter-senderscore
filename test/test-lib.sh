[ -z "$FILTER_BIN" ] && FILTER_BIN="$(pwd)/../filter-senderscore"
[ -z "$FILTER_OPTS" ] && FILTER_OPTS='-disableConcurrency'

test_init() {
	TEST_DIR="$(mktemp -d)"
	cd "$TEST_DIR" || return 1
	i=0
}

test_complete() {
	rm -r "$TEST_DIR"
	echo "1..$i"
}

test_run() {
	i=$(($i + 1))
	eval "$2" && printf "ok" || printf "not ok"
	echo " $i - $1"
}

test_cmp() {
	diff -u "$1" "$2" >&2
}
