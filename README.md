# filter-senderscore

## Description
This filter performs a SenderScore lookup and allows OpenSMTPD to either block or slow down a
session based on the reputation of the source IP address.


## Features
The filter currently supports:

- blocking hosts with reputation below a certain value
- adding X-Spam header to hosts with reputation below a certain value
- apply to a session a time penalty proportional to the IP reputation


## Dependencies
The filter is written in Golang and doesn't have any dependencies beyond standard library.

It requires OpenSMTPD 6.6.0 or higher.


## How to install
Install from your operating system's preferred package manager if available.
On OpenBSD:
```
$ doas pkg_add filter-senderscore
quirks-3.167 signed on 2019-08-11T14:18:58Z
filter-senderscore-v0.1.0: ok
$
```

Alternatively, clone the repository, build and install the filter:
```
$ cd filter-senderscore/
$ go build
$ doas install -m 0555 filter-senderscore /usr/local/bin/filter-senderscore
```

## How to configure
The filter itself requires no configuration.

It must be declared in smtpd.conf and attached to a listener:
```
filter "senderscore" proc-exec "/usr/local/bin/filter-senderscore -blockBelow 50 -junkBelow 80 -slowFactor 1000"

listen on all filter "senderscore"
```

`-blockBelow` will display an error banner for sessions with reputation score below value then disconnect.

`-blockPhase` will determine at which phase `-blockBelow` will be triggered, defaults to `connect`, valid choices are `connect`, `helo`, `ehlo`, `starttls`, `auth`, `mail-from`, `rcpt-to` and `quit`. Note that `quit` will result in a message at the end of a session and may only be used to warn sender that reputation is degrading as it will not prevent transactions from succeeding.

`-junkBelow` will prepend the 'X-Spam: yes' header to messages

`-slowFactor` will delay all answers to a reputation-related percentage of its value in milliseconds. The formula is `delay - (delay / 100) * score` where `delay` is the argument to the `-slowFactor` parameter and `score` is the reputation score. By default, connections are never delayed.

`-scoreHeader` will add an X-SenderScore header with reputation value if known.

`-whitelist <file>` can be used to specify a file containing a list of IP addresses and subnets in CIDR notation to whitelist, one per line. IP addresses matching any entry in that list automatically receive a score of 100. The current subnet whitelist implementation performs a linear scan of all whitelisted subnets on every connection; keep this in mind when adding a lot of CIDR entries.
