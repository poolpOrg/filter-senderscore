#!/bin/sh

. ./test-lib.sh

test_init

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

test_run 'test the blockBelow parameter' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 101 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.100:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.2.3.100:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	EOD
	test_cmp actual expected
'

test_run 'test the connect filter with a nonexistent IP address' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 101 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|255.255.255.255:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|255.255.255.255:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	EOD
	test_cmp actual expected
'

test_run 'test the connect filter with a blacklisted IP address' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 80 | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.2.3.4:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	EOD
	test_cmp actual expected
'

test_complete
