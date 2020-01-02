#!/bin/sh

. ./test-lib.sh

test_init

test_run 'test the connect filter with a non-reputable IP address' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.2.3.4:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	EOD
	test_cmp actual expected
'

test_run 'test the connect filter with a reputable IP address' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.100:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.2.3.100:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	EOD
	test_cmp actual expected
'

test_run 'test the connect filter with a nonexistent IP address' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|255.255.255.255:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|255.255.255.255:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	EOD
	test_cmp actual expected
'

test_run 'test block phase: connect' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 -blockPhase connect | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.2.3.4:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	EOD
	test_cmp actual expected
'

test_run 'test block phase: helo' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 -blockPhase helo | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|helo|7641df9771b4ed00|1ef1c203cc576e5d|localhost
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	EOD
	test_cmp actual expected
'

test_run 'test block phase: ehlo' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 -blockPhase ehlo | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|ehlo|7641df9771b4ed00|1ef1c203cc576e5d|localhost
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	EOD
	test_cmp actual expected
'

test_run 'test block phase: mail-from' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 -blockPhase mail-from | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|mail-from|7641df9771b4ed00|1ef1c203cc576e5d|root@localhost
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	EOD
	test_cmp actual expected
'

test_run 'test block phase: rcpt-to' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 -blockPhase rcpt-to | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|rcpt-to|7641df9771b4ed00|1ef1c203cc576e5d|root@localhost
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	EOD
	test_cmp actual expected
'

test_run 'test with invalid block phase: data-line' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 -blockPhase data-line; [ "$?" -eq 1 ]
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.2.3.4:33174|1.1.1.1:25
	EOD
'

test_complete
