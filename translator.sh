#!/bin/sh -

ARGV=$(getopt -o 'f:t:hl' -l 'from-code:,to-code:,help,list' -n "${0}" -- "$@")
eval set -- "$ARGV"

COOKIE_FILE='cookie.txt'
USER_AGENT='Mozilla/6.0 (Windows NT 6.2; WOW64; rv:16.0.1) Gecko/20121011 Firefox/16.0.1'
BASE_URL='http://translate.google.cn'

get_cookie() {
    curl -s -c "$COOKIE_FILE" -A "$USER_AGENT" "$BASE_URL" > /dev/null
}

get_javascript() {
    local from_code="$1"
    local to_code="$2"
    shift 2
    cat "$@" | curl -s -b "$COOKIE_FILE" -A "$USER_AGENT" -e "$BASE_URL" \
        -d "client=t&sl=${from_code}&tl=${to_code}&ie=UTF-8&oe=UTF-8" \
        --data-urlencode "text@-" "${BASE_URL}/translate_a/t"
}

parse_array() {
    local layer=-1
    local zero_layer_index=-2
    local first_layer_index
    local second_layer_index
    local result
    while read -r line
    do
        case $line in
            '[')
                (( layer += 1 ))
                case $layer in
                0)
                    (( zero_layer_index += 1 ))
                    first_layer_index=-2
                    ;;
                1)
                    (( zero_layer_index += 1 ))
                    (( first_layer_index += 1 ))
                    second_layer_index=-2
                    ;;
                2)
                    (( first_layer_index += 1 ))
                    (( second_layer_index += 1 ))
                    ;;
                esac
                ;;
            ']')
                (( layer -= 1 ))
                case $layer in
                -1)
                    zero_layer_index=-2
                    ;;
                0)
                    first_layer_index=-2
                    ;;
                1)
                    second_layer_index=-2
                    ;;
                esac
                ;;
            [[:digit:]])
                ;;
            *)
                case $layer in
                0)
                    (( zero_layer_index += 1 ))
                    ;;
                1)
                    (( first_layer_index += 1 ))
                    ;;
                2)
                    (( second_layer_index += 1 ))
                    ;;
                esac
                if [ $zero_layer_index -eq 0 ] && [ $second_layer_index -eq 0 ]
                then
                    result=$(sed -e 's/^"\(.*\)"$/\1/' <<< "$line")
                    printf '%b' "$result"
                fi
                ;;
        esac
    done
}

print_error() {
    local my_name="${0}"
    printf '%s\n' \
            "${my_name}: missing optstring argument" \
            "Try \`${my_name} --help' for more information." 1>&2
}

print_usage() {
    printf '%s\n' \
            "Usage: ${0} [OPTION...] [FILE...]" \
            'Translate language of given files from one language to another by Google translate.' \
            '' \
            ' Input/Output format specification:' \
            '  -f, --from-code=NAME       language of original text' \
            '  -t, --to-code=NAME         language for output' \
            '' \
            ' Information:' \
            '  -l, --list                 list all known language sets' \
            '' \
            ' Output control:' \
            '  -h, --help                 show this help list'
}

print_list() {
    printf '%s\n' \
            'The following languages are both supported in input and output:' \
            ' af, sq, ar, hy, az, eu, be, bn, bg, ca,' \
            ' zh-CN, hr, cs, da, nl, en, eo, et, tl, fi, fr,' \
            ' gl, ka, de, el, gu, ht, iw, hi, hu, is, id,' \
            ' ga, it, ja, kn, ko, lo, la, lv, lt, mk, ms,' \
            ' mt, no, fa, pl, pt, ro, ru, sr, sk, sl, es,' \
            ' sw, sv, ta, te, th, tr, uk, ur, vi, cy, yi' \
            '' \
            'The following languages are only supported in input:' \
            ' auto' \
            '' \
            'The following languages are only supported in output:' \
            ' zh-TW' \
            '' \
            'Default from-code value is auto' \
            'Default to-code value is en'
}

main() {
    local from_code='auto'
    local to_code='en'
    while true
    do
        case "${1}" in
            '-f'|'--from-code')
                from_code="${2}"
                shift 2
                ;;
            '-t'|'--to-code')
                to_code="${2}"
                shift 2
                ;;
            '-h'|'--help')
                print_usage
                break
                ;;
            '-l'|'--list')
                print_list
                break
                ;;
            '--')
                shift
                if [ $# -gt 0 ]
                then
                    get_cookie
                    get_javascript "$from_code" "$to_code" "$@" | grep -o '\[\|\]\|"\([^"]\|\\"\)*"\|[[:digit:]]' | parse_array
                    break
                else
                    print_error
                    return 2
                fi
                ;;
            *)
                print_error
                return 1
                ;;
        esac
    done
    return 0
}

main "$@"
