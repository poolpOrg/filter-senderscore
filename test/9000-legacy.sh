#!/bin/sh

. ./test-lib.sh

test_init

test_run 'test with protocol version 0.4' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.4|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.100:33174|1.1.1.1:25
	filter|0.4|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.2.3.100:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|1ef1c203cc576e5d|7641df9771b4ed00|proceed
	EOD
	test_cmp actual expected
'

test_complete
