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


KNOWNTESTPROGS=${KNOWNTESTPROGS:-"basename cat date ps seq tr uptime rand rand_element"}

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

test_rand () {
    # 
    # The function $( rand N ) must return a value in the range (0,N], and enforce a very lax test
    # of random statistical distribution (increases allowed variance at the square of the difference
    # in the order of count and range; in other words, the bigger the number of samples and hence
    # counts in each range bucket, the smaller the allowed variance).  This is bash, not a
    # cryptography library, after all, and we want to guarantee test success in all but the most
    # extreme failures of pseudo-randomness.
    # 
    . ../function/rand
    errors=0
    verbose=1
    range=10
    count=10000
    target=$(( count / range ))
    order=$(( ${#count} - ${#range} ))		# poor-man's approx log base 10
    variance=$(( target * 2 / order / order ))	# works fine for count >= range x 10
    incidence=()
    (( verbose )) \
        && echo "Test rand: Testing $count samples in range (0,$range]; allowing max. variance $target +/- $variance ($(( variance * 100 / target ))%)"
    for (( c = 0; c < count; ++c )); do
        (( ++incidence[$( rand $range )] ))
    done
    if (( ${#incidence[@]} != range )); then
        echo "Test rand: Unexpected number of distinct results; found ${#incidence[@]}, expected $range"
        (( ++errors ))
    fi
    for (( i = 0; i < ${#incidence[@]}; ++i )); do
        if (( i < 0 && i >= range )); then
            echo "Test rand: Result $i outside range (0,$range]"
            (( ++errors ))
        elif (( incidence[i] < target - variance || incidence[i] > target + variance )); then 
            echo "Test rand: Result $i incidence $(( incidence[i] )) is outside $target +/- $variance"
            (( ++errors ))
        fi
        (( verbose > 1 || errors )) \
            && printf "%3d: %6d %2d%%\n" $i ${incidence[$i]} $(( incidence[$i] * 100 / count ))
    done
    (( errors )) && return 1 || return 0
}

test_rand_element () {
    # 
    # The function $( rand_element "element1" "element2" ) returns a pseudo random choice of one of
    # its arguments (each of which may contain whitespace).
    # 
    . ../function/rand
    . ../function/rand_element
    errors=0
    verbose=1
    range=10
    count=10000
    values=()
    incidence=()

    (( verbose )) \
        && printf "Test rand_element: Testing %d samples of rand_element 'item%4d' ... 'item%4d'\n" $count 0 $(( range - 1 ))

    # Where N=$range, construct "rand_element 'item    1' 'item    2' ... 'item    N-1'" command
    for (( i = 0; i < range; ++i )); do
        values[$i]=$( printf "item %4d" $i )
    done
    command="rand_element"
    for (( i = 0; i < ${#values[@]}; ++i )); do
        command="${command} '${values[$i]}'"
    done
    (( verbose > 1 )) \
        && echo "Test $command"

    # Invoke rand_element command $count times
    for (( c = 0; c < count; ++c )); do
        v=$( eval "$command" )
        for (( i = 0; i < ${#values[@]}; ++i )); do
            if [[ "$v" == "${values[$i]}" ]]; then
                (( ++incidence[$i] ))
            fi
        done
    done

    # Ensure we recognized and enumerated each and every result
    sum=0
    for (( i = 0; i < ${#values[@]}; ++i )); do
        if (( incidence[$i] == 0 )); then
            echo "Test rand_item: Missing expected result $values[$i]"
            (( ++errors ))
        fi
        (( verbose > 1 || errors )) \
            && printf "%10s: %6d %2d%%%s\n" "${values[$i]}" ${incidence[$i]} $(( incidence[$i] * 100 / count ))
        (( sum += incidence[$i] ))
    done
    if (( sum != count )); then
        echo "Test rand_item: Unexpected total number of valid results; found $sum, expected $count"
        (( ++errors ))
    fi

    (( errors )) && return 1 || return 0
}





main "$@"
