#!/bin/sh

. ./test-lib.sh

test_init

test_run 'initialization' '
	echo "config|ready" | "$FILTER_BIN" $FILTER_OPTS | sort >actual &&
	cat <<-EOD >expected &&
	register|filter|smtp-in|auth
	register|filter|smtp-in|commit
	register|filter|smtp-in|connect
	register|filter|smtp-in|data
	register|filter|smtp-in|data-line
	register|filter|smtp-in|ehlo
	register|filter|smtp-in|helo
	register|filter|smtp-in|mail-from
	register|filter|smtp-in|quit
	register|filter|smtp-in|rcpt-to
	register|filter|smtp-in|starttls
	register|ready
	register|report|smtp-in|link-connect
	register|report|smtp-in|link-disconnect
	EOD
	test_cmp actual expected
'

test_run 'test the connect filter with a reputable IP address' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|199.185.178.25:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|199.185.178.25:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	EOD
	test_cmp actual expected
'

test_run 'test the blockBelow parameter' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 101 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|199.185.178.25:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|199.185.178.25:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	EOD
	test_cmp actual expected
'

test_run 'test the junkBelow parameter' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -junkBelow 101 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|199.185.178.25:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|199.185.178.25:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|junk
	EOD
	test_cmp actual expected
'

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

test_run 'test with legacy protocol version' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.4|0|smtp-in|link-connect|7641df9771b4ed00||pass|199.185.178.25:33174|1.1.1.1:25
	filter|0.4|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|199.185.178.25:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|1ef1c203cc576e5d|7641df9771b4ed00|proceed
	EOD
	test_cmp actual expected
'

test_run 'test the connect filter with a nonexistent IP address' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 101 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|127.0.0.2:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|127.0.0.2:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	EOD
	test_cmp actual expected
'

test_run 'test the connect filter with a blacklisted IP address' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 80 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|202.92.4.34:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|202.92.4.34:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	EOD
	test_cmp actual expected
'

test_complete
