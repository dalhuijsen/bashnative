rand() {
	printf $((  ($1 * (( RANDOM * 100 ) / 32767 )) / 100 ))
}


rand_element () {
    local -a th=("$@")
    unset th[0]
    printf $'%s\n' "${th[$(($(rand "${#th[*]}")+1))]}"
}

rand_element monkey horse bird cow
rand_element monkey horse bird cow
rand_element monkey horse bird cow
rand_element monkey horse bird cow
rand_element monkey horse bird cow
