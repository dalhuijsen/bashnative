#!/bin/bash
# tdd.sh - A testing script 
# Copyright 2012 Thijs Dalhuijsen <dalhuijsen@gmail.com>
# This program is distributed under the terms of the GNU General Public License
# (GPLv3) as published by the Free Software Foundation. 
# <http://www.gnu.org/licenses/>


# Usage: ./tdd.sh IDENTIFIER [IDENTIFIER]...  # run specific tests
#   or:  ./tdd.sh                             # run all known tests
#
# Adding tests:
# either put the tests inline here, following a test_IDENTIFIER naming convention
# or put them as separate files in a subdirectory named tests following the same 
# naming convention as above.
# 
# eg. $PWD/tests/test_IDENTIFIER or 'function test_IDENTIFIER () { return 0 }'
#
# only tests returning 0 will be called successful, returning anything other than
# zero will cause further testing to be halted.
# only when all tests have been found and exited successfully will tdd.sh return 
# true itself. Failure of finding a test will not however halt further testing.
#
# Environment variables:
# KNOWNTESTPROGS
# The space separated list of IDENTIFIERS used for automatic running of all test
# (invocation of tdd.sh without any parameters) can be overidden from the 
# environment by setting KNOWNTESTPROGS, or  by modifying its default setting below.
#
#
# Examples:
# if ./tdd.sh true true false true; then echo all tests succeeded; fi
# ## lol, now try the same, but remove the false.


KNOWNTESTPROGS=${KNOWNTESTPROGS:-"basename cat date ps seq tr uptime"}

DOTESTNUM=0
NOTESTNUM=0
TESTINGNUM=0

main () {
	if [[ -d "tests" ]]; then
		PATH="${PATH}:tests"
	fi
	if [[ -n "$1" ]]; then
		X=0
		while (( X++ < ${#} )); do
			runtest "${!X}"
		done
	else
		echo "Performing tests for all known programs"
		for P in $KNOWNTESTPROGS; do
			runtest "$P"
		done
	fi
	echo
	echo "All tests completed. Found ${DOTESTNUM} tests for a total of ${TESTINGNUM} tried."
	if [[ ${NOTESTNUM} != 0 ]]; then
		echo "WARNING: ${NOTESTNUM} missing tests ( from a total of ${TESTINGNUM} )"
		exit 1
	else
		exit 0
	fi
}

runtest () {
	TESTINGNUM=$(( TESTINGNUM + 1 ))
	type "test_${1}" >/dev/null 2>&1
	if [[ ${?} == 0 ]]; then
		DOTESTNUM=$(( DOTESTNUM + 1 ))
		echo "Test #${DOTESTNUM}	found, performing test_${1}:"
		test_${1}
		if [[ ! ${?} == 0 ]]; then
			echo -e "\e[1mERROR:\e[0m Test #${DOTESTNUM}: \"test_${1}\" failed with exitcode ${?}, please check above for details." >&2
			exit 1
		else
			echo "Test #${DOTESTNUM}	test_${1} succeeded!"
		fi
	else
		NOTESTNUM=$(( NOTESTNUM + 1 ))
		echo "Bah, no test found for \"${1}\"." >&2
	fi
}


#bintests
test_true () {
	echo dummy test, testing for true...
	return 0
}
test_false () {
	echo dummy test, testing for false...
	return 1
}

#functiontests








main "$@"
