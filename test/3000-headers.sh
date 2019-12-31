#!/bin/sh

. ./test-lib.sh

test_init

test_run 'test the scoreHeader parameter' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -scoreHeader | sed "0,/^register|ready/d" | sed "s/X-SenderScore: .*/X-SenderScore: -/" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|199.185.178.25:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|199.185.178.25:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|data-line|7641df9771b4ed00|1ef1c203cc576e5d|.
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	filter-dataline|7641df9771b4ed00|1ef1c203cc576e5d|X-SenderScore: -
	filter-dataline|7641df9771b4ed00|1ef1c203cc576e5d|.
	EOD
	test_cmp actual expected
'

test_complete
