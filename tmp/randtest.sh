function rand () {
	echo -n "$((  $(( ${1} * $(( $(( RANDOM * 100 )) / 32767 )) )) / 100 ))"
}

function rand_element () {
    local TH;
    for x in "$@"; do
        TH[${#TH[*]}]="$x";
    done
    unset TH[0]
    echo -n "${TH[$(($(rand "${#TH[*]}")+1))]}"
}

rand2() {
	printf $((  ($1 * (( RANDOM * 100 ) / 32767 )) / 100 ))
}

rand_element2() {
    local -a th=("$@")
    unset th[0]
    printf '%s' "${th[$(rand2 "${#TH[@]}") + 1]}"
}
rand_element4() {
    local -a th=("$@")
    unset th[0]
    printf '%s' "${th[$(rand2 "${#TH[*]}") + 1]}"
}

function rand_element3 () {
    local TH;
    for x in "$@"; do
        TH[${#TH[*]}]="$x";
    done
    unset TH[0]
    echo -n "${TH[$(($(rand "${#TH[*]}")+1))]}"
}
rand_element5() {
    local -a th=("$@")
    unset th[0]
    printf $'%s\n'  "${th[$(($(rand "${#TH[*]}")+1))]}"
}

rand 5
rand 5
rand2 5
rand2 5
echo $(rand_element boer aap noot mies)
echo $(rand_element2 boer aap noot mies)
echo $(rand_element2 boer aap noot mies)
echo $(rand_element2 boer aap noot mies)
echo $(rand_element2 boer aap noot mies)
echo $(rand_element2 boer aap noot mies)
echo $(rand_element2 boer aap noot mies)
echo $(rand_element3 boer aap noot mies)
echo $(rand_element3 boer aap noot mies)
echo $(rand_element3 boer aap noot mies)
echo $(rand_element3 boer aap noot mies)
echo $(rand_element4 boer aap noot mies)
echo $(rand_element4 boer aap noot mies)
echo $(rand_element4 boer aap noot mies)
echo $(rand_element4 boer aap noot mies)
echo $(rand_element5 boer aap noot mies)
echo $(rand_element5 boer aap noot mies)
echo $(rand_element5 boer aap noot mies)
echo $(rand_element5 boer aap noot mies)

echo DUS
rand_element () {

    local -a th=("$@")
    unset th[0]
    printf $'%s\n' "${th[$(($(rand "${#th[*]}")+1))]}"
}
echo $(rand_element6 boer aap noot mies)
echo $(rand_element6 boer aap noot mies)
echo $(rand_element6 boer aap noot mies)
echo $(rand_element6 boer aap noot mies)
echo $(rand_element6 boer aap noot mies)




