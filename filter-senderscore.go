//
// Copyright (c) 2019 Gilles Chehade <gilles@poolp.org>
//
// Permission to use, copy, modify, and distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//

package main

import (
	"bufio"
	"flag"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"

	"log"
	"time"
)

var blockBelow *int
var blockPhase *string
var junkBelow *int
var slowFactor *int
var scoreHeader *bool
var whitelistFile *string
var testMode *bool
var whitelist = make(map[string]bool)
var whitelistMasks = make(map[int]bool)

var version string

var outputChannel chan string

type session struct {
	id string

	category int8
	score    int8

	delay      int
	first_line bool
}

var sessions = make(map[string]*session)

var reporters = map[string]func(string, string, []string){
	"link-connect":    linkConnect,
	"link-disconnect": linkDisconnect,
}

var filters = map[string]func(string, string, []string){
	"connect": filterConnect,

	"helo":      delayedAnswer,
	"ehlo":      delayedAnswer,
	"starttls":  delayedAnswer,
	"auth":      delayedAnswer,
	"mail-from": delayedAnswer,
	"rcpt-to":   delayedAnswer,
	"data":      delayedAnswer,
	"data-line": dataline,
	"commit":    delayedAnswer,

	"quit": delayedAnswer,
}

func linkConnect(phase string, sessionId string, params []string) {
	if len(params) != 4 {
		log.Fatal("invalid input, shouldn't happen")
	}

	s := &session{}
	s.first_line = true
	s.score = -1
	sessions[sessionId] = s

	addr := net.ParseIP(strings.Split(params[2], ":")[0])
	if addr == nil || strings.Contains(addr.String(), ":") {
		return
	}

	defer func(addr net.IP, s *session) {
		fmt.Fprintf(os.Stderr, "link-connect addr=%s score=%d\n", addr, s.score)
	}(addr, s)

	for maskOnes := range whitelistMasks {
		mask := net.CIDRMask(maskOnes, 32)
		maskedAddr := addr.Mask(mask).String()
		query := fmt.Sprintf("%s/%d", maskedAddr, maskOnes)
		if whitelist[query] {
			fmt.Fprintf(os.Stderr, "IP address %s matches whitelisted subnet %s\n", addr, query)
			s.score = 100
			return
		}
	}

	atoms := strings.Split(addr.String(), ".")

	if *testMode {
		// if test mode is enabled, the Sender Score DNS query is
		// skipped and the score is derived directly from the
		// connecting IP address; IP addresses ending with 255 can be
		// used to simulate missing Sender Score DNS entries
		if atoms[3] == "255" {
			return
		}
	} else {
		addrs, _ := net.LookupIP(fmt.Sprintf("%s.%s.%s.%s.score.senderscore.com",
			atoms[3], atoms[2], atoms[1], atoms[0]))

		if len(addrs) != 1 {
			return
		}

		resolved := addrs[0].String()
		atoms = strings.Split(resolved, ".")
	}

	category, _ := strconv.ParseInt(atoms[2], 10, 8)
	score, _ := strconv.ParseInt(atoms[3], 10, 8)

	s.category = int8(category)
	s.score = int8(score)
}

func linkDisconnect(phase string, sessionId string, params []string) {
	if len(params) != 0 {
		log.Fatal("invalid input, shouldn't happen")
	}
	delete(sessions, sessionId)
}

func getSession(sessionId string) *session {
	s, ok := sessions[sessionId]
	if !ok {
		log.Fatalf("invalid session ID: %s", sessionId)
	}
	return s
}

func filterConnect(phase string, sessionId string, params []string) {
	s := getSession(sessionId)

	if *slowFactor > 0 && s.score > 0 {
		s.delay = *slowFactor * (100 - int(s.score)) / 100
	} else {
		// no slow factor or neutral IP address
		s.delay = 0
	}

	if s.score != -1 && s.score < int8(*blockBelow) && *blockPhase == "connect" {
		delayedDisconnect(sessionId, params)
	} else if s.score != -1 && s.score < int8(*junkBelow) {
		delayedJunk(sessionId, params)
	} else {
		delayedProceed(sessionId, params)
	}
}

func produceOutput(msgType string, sessionId string, token string, format string, a ...interface{}) {
	var out string

	if version < "0.5" {
		out = msgType + "|" + token + "|" + sessionId
	} else {
		out = msgType + "|" + sessionId + "|" + token
	}
	out += "|" + fmt.Sprintf(format, a...)

	if *testMode {
		fmt.Println(out)
	} else {
		outputChannel <- out
	}
}

func dataline(phase string, sessionId string, params []string) {
	s := getSession(sessionId)
	token := params[0]
	line := strings.Join(params[1:], "|")

	if s.first_line == true {
		if s.score != -1 && *scoreHeader {
			produceOutput("filter-dataline", sessionId, token, "X-SenderScore: %d", s.score)
		}
		s.first_line = false
	}

	produceOutput("filter-dataline", sessionId, token, "%s", line)
}

func delayedAnswer(phase string, sessionId string, params []string) {
	s := getSession(sessionId)

	if s.score != -1 && s.score < int8(*blockBelow) && *blockPhase == phase {
		delayedDisconnect(sessionId, params)
		return
	}

	delayedProceed(sessionId, params)
}

func delayedJunk(sessionId string, params []string) {
	s := getSession(sessionId)
	token := params[0]
	if *testMode {
		waitThenAction(sessionId, token, s.delay, "junk")
	} else {
		go waitThenAction(sessionId, token, s.delay, "junk")
	}
}

func delayedProceed(sessionId string, params []string) {
	s := getSession(sessionId)
	token := params[0]
	if *testMode {
		waitThenAction(sessionId, token, s.delay, "proceed")
	} else {
		go waitThenAction(sessionId, token, s.delay, "proceed")
	}
}

func delayedDisconnect(sessionId string, params []string) {
	s := getSession(sessionId)
	token := params[0]
	if *testMode {
		waitThenAction(sessionId, token, s.delay, "disconnect|550 your IP reputation is too low for this MX")
	} else {
		go waitThenAction(sessionId, token, s.delay, "disconnect|550 your IP reputation is too low for this MX")
	}
}

func waitThenAction(sessionId string, token string, delay int, format string, a ...interface{}) {
	if delay > 0 {
		time.Sleep(time.Duration(delay) * time.Millisecond)
	}
	produceOutput("filter-result", sessionId, token, format, a...)
}

func filterInit() {
	for k := range reporters {
		fmt.Printf("register|report|smtp-in|%s\n", k)
	}
	for k := range filters {
		fmt.Printf("register|filter|smtp-in|%s\n", k)
	}
	fmt.Println("register|ready")
}

func trigger(currentSlice map[string]func(string, string, []string), atoms []string) {
	if handler, ok := currentSlice[atoms[4]]; ok {
		handler(atoms[4], atoms[5], atoms[6:])
	} else {
		log.Fatalf("invalid phase: %s", atoms[4])
	}
}

func skipConfig(scanner *bufio.Scanner) {
	for {
		if !scanner.Scan() {
			os.Exit(0)
		}
		line := scanner.Text()
		if line == "config|ready" {
			return
		}
	}
}

func validatePhase(phase string) {
	switch phase {
	case "connect", "helo", "ehlo", "starttls", "auth", "mail-from", "rcpt-to", "quit":
		return
	}
	log.Fatalf("invalid block phase: %s", phase)
}

func loadWhitelists() {
	if *whitelistFile == "" {
		return
	}

	file, err := os.Open(*whitelistFile)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()

		// remove comments and whitespace, skip empty lines
		line = strings.TrimSpace(strings.Split(line, "#")[0])
		if line == "" {
			continue
		}

		if !strings.Contains(line, "/") {
			line += "/32"
		}
		_, subnet, err := net.ParseCIDR(line)
		if err != nil {
			log.Fatalf("invalid subnet: %s", subnet)
		}

		maskOnes, _ := subnet.Mask.Size()
		if !whitelistMasks[maskOnes] {
			whitelistMasks[maskOnes] = true
		}
		subnetStr := subnet.String()
		if !whitelist[subnetStr] {
			whitelist[subnetStr] = true
			fmt.Fprintf(os.Stderr, "Subnet %s added to whitelist\n", subnetStr)
		}
	}
	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}
}

func main() {
	blockBelow = flag.Int("blockBelow", -1, "score below which session is blocked")
	blockPhase = flag.String("blockPhase", "connect", "phase at which blockBelow triggers")
	junkBelow = flag.Int("junkBelow", -1, "score below which session is junked")
	slowFactor = flag.Int("slowFactor", -1, "delay factor to apply to sessions")
	scoreHeader = flag.Bool("scoreHeader", false, "add X-SenderScore header")
	whitelistFile = flag.String("whitelist", "", "file containing a list of IP addresses or subnets in CIDR notation to whitelist, one per line")
	testMode = flag.Bool("testMode", false, "skip all DNS queries, process all requests sequentially, only for debugging purposes")

	flag.Parse()

	validatePhase(*blockPhase)
	loadWhitelists()

	scanner := bufio.NewScanner(os.Stdin)
	skipConfig(scanner)
	filterInit()

	if !*testMode {
		outputChannel = make(chan string)
		go func() {
			for line := range outputChannel {
				fmt.Println(line)
			}
		}()
	}

	for {
		if !scanner.Scan() {
			os.Exit(0)
		}

		line := scanner.Text()
		atoms := strings.Split(line, "|")
		if len(atoms) < 6 {
			log.Fatalf("missing atoms: %s", line)
		}

		version = atoms[1]

		switch atoms[0] {
		case "report":
			trigger(reporters, atoms)
		case "filter":
			trigger(filters, atoms)
		default:
			log.Fatalf("invalid stream: %s", atoms[0])
		}
	}
}
