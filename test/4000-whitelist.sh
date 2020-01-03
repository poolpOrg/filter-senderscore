#!/bin/sh

. ./test-lib.sh

test_init

test_run 'test IP address whitelisting' '
	cat <<-EOD >whitelist &&
	1.1.1.1
	3.3.3.3
	EOD
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 -whitelist whitelist | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.1.1.1:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.1.1.1:33174|1.1.1.1:25
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed01||pass|2.2.2.2:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed01|1ef1c203cc576e5d||pass|2.2.2.2:33174|1.1.1.1:25
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed02||pass|3.3.3.3:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed02|1ef1c203cc576e5d||pass|3.3.3.3:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	filter-result|7641df9771b4ed01|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	filter-result|7641df9771b4ed02|1ef1c203cc576e5d|proceed
	EOD
	test_cmp actual expected
'

test_run 'test subnet whitelisting' '
	cat <<-EOD >whitelist &&
	1.1.0.0/16
	1.2.3.0/24
	2.0.0.0/8
	EOD
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 -whitelist whitelist | sed "0,/^register|ready/d" >actual &&
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.1.1.1:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed00|1ef1c203cc576e5d||pass|1.1.1.1:33174|1.1.1.1:25
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed01||pass|2.2.2.2:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed01|1ef1c203cc576e5d||pass|2.2.2.2:33174|1.1.1.1:25
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed02||pass|3.3.3.3:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed02|1ef1c203cc576e5d||pass|3.3.3.3:33174|1.1.1.1:25
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed03||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed03|1ef1c203cc576e5d||pass|1.2.3.4:33174|1.1.1.1:25
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed04||pass|1.2.2.3:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed04|1ef1c203cc576e5d||pass|1.2.2.3:33174|1.1.1.1:25
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed05||pass|2.3.4.5:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed05|1ef1c203cc576e5d||pass|2.3.4.5:33174|1.1.1.1:25
	EOD
	cat <<-EOD >expected &&
	filter-result|7641df9771b4ed00|1ef1c203cc576e5d|proceed
	filter-result|7641df9771b4ed01|1ef1c203cc576e5d|proceed
	filter-result|7641df9771b4ed02|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	filter-result|7641df9771b4ed03|1ef1c203cc576e5d|proceed
	filter-result|7641df9771b4ed04|1ef1c203cc576e5d|disconnect|550 your IP reputation is too low for this MX
	filter-result|7641df9771b4ed05|1ef1c203cc576e5d|proceed
	EOD
	test_cmp actual expected
'

test_complete
