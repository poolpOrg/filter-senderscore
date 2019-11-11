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

	"time"
	"log"
)

var blockBelow *int
var blockPhase *string
var junkBelow *int
var slowFactor *int
var scoreHeader *bool

type session struct {
	id string

	category int8
	score int8

	delay int
	first_line bool
}

var sessions = make(map[string]*session)

var reporters = map[string]func(string, string, []string) {
	"link-connect": linkConnect,
	"link-disconnect": linkDisconnect,
}

var filters = map[string]func(string, string, []string) {
	"connect": filterConnect,

	"helo": delayedAnswer,
	"ehlo": delayedAnswer,
	"starttls": delayedAnswer,
	"auth": delayedAnswer,
	"mail-from": delayedAnswer,
	"rcpt-to": delayedAnswer,
	"data": delayedAnswer,
	"data-line": dataline,
	"commit": delayedAnswer,

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

	atoms := strings.Split(addr.String(), ".")
	addrs, _ := net.LookupIP(fmt.Sprintf("%s.%s.%s.%s.score.senderscore.com",
		atoms[3], atoms[2], atoms[1], atoms[0]))

	if len(addrs) != 1 {
		return
	}

	resolved := addrs[0].String()
	atoms = strings.Split(resolved, ".")
	category, _ := strconv.ParseInt(atoms[2], 10, 8)
	score, _ := strconv.ParseInt(atoms[3], 10, 8)

	s.category = int8(category)
	s.score = int8(score)
	
	fmt.Fprintf(os.Stderr, "link-connect addr=%s score=%d\n", addr, score)
}

func linkDisconnect(phase string, sessionId string, params []string) {
	if len(params) != 0 {
		log.Fatal("invalid input, shouldn't happen")
	}
	delete(sessions, sessionId)
}

func filterConnect(phase string, sessionId string, params[] string) {
	s := sessions[sessionId]

	// no slow factor, neutral or 100% good IP
	if (*slowFactor == -1 || s.score == -1 || s.score == 100) {
		s.delay = -1
	} else {
		s.delay = *slowFactor - ((*slowFactor / 100) * int(s.score))
	}

	if (s.score != -1 && s.score < int8(*blockBelow) && *blockPhase == "connect") {
		delayedDisconnect(sessionId, params)
	} else if (s.score != -1 && s.score < int8(*junkBelow)) {
		delayedJunk(sessionId, params)
	} else {
		delayedProceed(sessionId, params)
	}
}

func dataline(phase string, sessionId string, params[] string) {
	token := params[0]
	line := strings.Join(params[1:], "|")

	s := sessions[sessionId]
	if s.first_line == true {
		if (s.score != -1 && *scoreHeader) {
			fmt.Printf("filter-dataline|%s|%s|X-SenderScore: %d\n", token, sessionId, s.score)
		}
		s.first_line = false
	}
	sessions[sessionId] = s
	fmt.Printf("filter-dataline|%s|%s|%s\n", token, sessionId, line)
}

func delayedAnswer(phase string, sessionId string, params[] string) {
	s := sessions[sessionId]
	if (s.score != -1 && s.score < int8(*blockBelow) && *blockPhase == phase) {
		delayedDisconnect(sessionId, params)
		return
	}

	delayedProceed(sessionId, params)
}

func delayedJunk(sessionId string, params[] string) {
	token := params[0]
	s := sessions[sessionId]
	go waitThenAction(sessionId, token, s.delay, "junk")
}

func delayedProceed(sessionId string, params[] string) {
	token := params[0]
	s := sessions[sessionId]
	go waitThenAction(sessionId, token, s.delay, "proceed")
}

func delayedDisconnect(sessionId string, params[] string) {
	token := params[0]
	s := sessions[sessionId]
	go waitThenDisconnect(sessionId, token, s.delay)
}

func waitThenAction(sessionId string, token string, delay int, action string) {
	if (delay != -1) {
		time.Sleep(time.Duration(delay) * time.Millisecond)
	}
	fmt.Printf("filter-result|%s|%s|%s\n", token, sessionId, action)
	return
}

func waitThenDisconnect(sessionId string, token string, delay int) {
	if (delay != -1) {
		time.Sleep(time.Duration(delay) * time.Millisecond)
	}
	fmt.Printf("filter-result|%s|%s|disconnect|550 your IP reputation is too low for this MX\n", token, sessionId)
	return
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
	found := false
	for k, v := range currentSlice {
		if k == atoms[4] {
			v(atoms[4], atoms[5], atoms[6:])
			found = true
			break
		}
	}
	if !found {
		os.Exit(1)
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

func main() {
	blockBelow = flag.Int("blockBelow", -1, "score below which session is blocked")
	blockPhase = flag.String("blockPhase", "connect", "phase at which blockBelow triggers")
	junkBelow = flag.Int("junkBelow", -1, "score below which session is junked")
	slowFactor = flag.Int("slowFactor", -1, "delay factor to apply to sessions")
	scoreHeader = flag.Bool("scoreHeader", false, "add X-SenderScore header")

	flag.Parse()

	scanner := bufio.NewScanner(os.Stdin)
	skipConfig(scanner)
	filterInit()

	for {
		if !scanner.Scan() {
			os.Exit(0)
		}
		
		atoms := strings.Split(scanner.Text(), "|")
		if len(atoms) < 6 {
			os.Exit(1)
		}

		switch atoms[0] {
		case "report":
			trigger(reporters, atoms)
		case "filter":
			trigger(filters, atoms)
		default:
			os.Exit(1)
		}
	}
}
