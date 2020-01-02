[ -z "$FILTER_BIN" ] && FILTER_BIN="$(pwd)/../filter-senderscore"
[ -z "$FILTER_OPTS" ] && FILTER_OPTS='-disableConcurrency'

test_init() {
	TEST_DIR="$(mktemp -d)"
	cd "$TEST_DIR" || return 1
	i=0
	ret=0
}

test_complete() {
	rm -r "$TEST_DIR"
	echo "1..$i"
	return "$ret"
}

test_run() {
	i=$(($i + 1))
	if eval "$2"; then
		printf "ok"
	else
		printf "not ok"
		ret=1
	fi
	echo " $i - $1"
}

test_cmp() {
	diff -u "$1" "$2" >&2
}
