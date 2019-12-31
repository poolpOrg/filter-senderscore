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

test_complete
