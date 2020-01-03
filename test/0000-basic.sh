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

test_run 'test behavior with invalid stream' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 >&2; [ "$?" -eq 1 ]
	config|ready
	invalid|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.4:33174|1.1.1.1:25
	EOD
'

test_run 'test behavior with invalid phase' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 >&2; [ "$?" -eq 1 ]
	config|ready
	report|0.5|0|smtp-in|invalid|7641df9771b4ed00||pass|1.2.3.4:33174|1.1.1.1:25
	EOD
'

test_run 'test behavior with too few atoms' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 >&2; [ "$?" -eq 1 ]
	config|ready
	report|0.5|0|smtp-in|link-connect
	EOD
'

test_run 'test behavior with invalid session ID' '
	cat <<-EOD | "$FILTER_BIN" $FILTER_OPTS -blockBelow 20 >&2; [ "$?" -eq 1 ]
	config|ready
	report|0.5|0|smtp-in|link-connect|7641df9771b4ed00||pass|1.2.3.4:33174|1.1.1.1:25
	filter|0.5|0|smtp-in|connect|7641df9771b4ed01|1ef1c203cc576e5d||pass|1.2.3.4:33174|1.1.1.1:25
	EOD
'

test_complete
