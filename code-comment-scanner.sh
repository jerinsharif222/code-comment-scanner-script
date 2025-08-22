#!/bin/bash
# Jerin Sharif - Aug 21, 2025

# This script searches for comments in a code base. It will
# go through each listed file and related comments.

# Directory to search. Defaults to current location.
SEARCH_DIR="."

# Initializes true and false global constants.
declare -i TRUE=0
declare -i FALSE=1

# Debug mode.
DEBUG=$FALSE

# Delimiter to separate comment block regex.
#
#   EXAMPLE : "''';'''"
#
#   '''
#   This is a block comment
#   in python that all lines
#   would be counted.
#   '''
DELIMITER=";"

# Initializes commented lines and non-blank lines at count 0.
declare -i COMMENTED_LINES=0
declare -i NONBLANK_LINES=0

# Initializes lock for comment blocks / flag for comment count.
declare -i COMMENT_BLOCK_LOCK=$FALSE
declare -i IS_COMMENTED=$FALSE

# Arguments for each language.
#
# [0:1] is file type to use regex on
# [1:]  is regular expressions to check for
#
# For comment blocks, use DELIMITER between regex to delimit the beginning and end value.
# EXAMPLE : "^#", "''';'''"
PYTHON=(".py" "^#" "'''$DELIMITER'''")
ADA_A=(".a" "^--")
ADA_ADB=(".adb" "^--")
ADA_ADS=(".ads" "^--")
PASCAL=( ".pas" "^//" "\{$DELIMITER\}" "\(\*$DELIMITER\*\)" )
C=(".c" "^//" "/\*$DELIMITER\*/")
CPP=(".cpp" "^//" "/\*$DELIMITER\*/")
HEADER=(".h" "^//" "/\*$DELIMITER\*/")

# Main function. Total non-blank lines account for all non-empty lines (I.E. new lines), including
# commented lines.
main() { 
    cd "$SEARCH_DIR" || { echo "Error: Directory not found."; exit 1; }
    #search_files ${PYTHON[@]}
    #search_files ${ADA_A[@]}
    #search_files ${ADA_ADB[@]}
    #search_files ${ADA_ADS[@]}
    search_files ${PASCAL[@]}
    #search_files ${C[@]}
    #search_files ${CPP[@]}
    #search_files ${HEADER[@]}
    echo "==========================================="
    echo "Results "
    echo ""
    echo "Total non-blank lines : $NONBLANK_LINES"
    echo "Total commented lines : $COMMENTED_LINES"
}

# Usage function. Prints how to use this script to user.
usage() {
	echo "Usage: code-comment-scanner.sh [directory] [--debug]"
	echo "  directory       Directory to search (default: current directory)"
    echo "  --debug | -d    Print debug statements"
	echo ""
	echo "Examples:"
	echo "  code-comment-scanner.sh                              # Search text files for common markings in current directory"
	echo "  code-comment-scanner.sh /path/to/search              # Search text files in specified directory"
	echo "  code-comment-scanner.sh /path/to/search --debug      # Search text files in specified directory and print debug statements"
	exit 1
}

# Argument handler. Helps users point to directory and display usage information.
while [[ $# -gt 0 ]]; do
	case $1 in
        -d|--debug)
            DEBUG=0
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option $1"
            usage
            ;;
        *)
            SEARCH_DIR="$1"
            shift
            ;;
	esac
done

# Loops through files with specific extension and runs regex on patterns.
# Switches Internal Field Separator (IFS) to get all files regardless of spaces.
# search_files(String type, Array<String> patterns)
#
# String type : Extention type.  (STRING)
#
# Array<Strings> patterns : Array of patterns. (STRINGS)
search_files() {
    echo "Seaching for files with extention $1..."
    local total_count=$(find . -maxdepth 1 -type f -name "*$1"| wc -l)
    echo "There are $total_count total. Beginning search..."
    declare -i curr_count=1
    local patterns=${@:2}
	for file in *"$1"; do
        if [ -f "$file" ]; then
            echo -e "( $curr_count / $total_count ) Searching \"${file:0:15}\"..."
            debug_search_files "$file" ${patterns[@]}
            search_file "$file" ${patterns[@]}
            curr_count+=1
        fi
	done
}

# Debug for search_files.
# debug_search_files(File file, Array<String> patterns)
#
# File file : Passed file. (FILE)
#
# Array<Strings> patterns : Array of patterns. (STRINGS)
debug_search_files() {
    local file=$1
    local patterns=${@:2}
    if [ $DEBUG = 0 ]; then
        echo "==========================================="
        echo "Searching file $file..."
        echo ""
        echo "Looking for patterns ${patterns[@]}"
        echo ""
    fi
}

# Loops through lines with specific file and runs regex on patterns.
# search_file(File file, Array<String> patterns)
#
# File file : Passed file. (FILE)
#
# Array<Strings> patterns : Array of patterns. (STRINGS)
search_file() {
	local file=$1
    local patterns=${@:2}
	while read line; do
        debug_search_file "$line" 
        if is_blank $line; then continue; fi
        NONBLANK_LINES+=1
        search_line "$line" $patterns
	done <"$file"
}

# Debug for search_file.
# debug_search_file(String line)
#
# String line : String of an individual line. (STRING)
debug_search_file() {
    local line=$1
    if [ $DEBUG = 0 ]; then
        echo "| $line"
        if [[ $COMMENT_BLOCK_LOCK = $TRUE ]]; then
        echo "| | Currently locked inside of comment block!"
        fi
    fi
}

# Loops through patterns and runs regex with a specific line.
# search_line(String line, Integer comment_block_lock, Array<String> patterns)
#
# String line : String of an individual line. (STRING)
# 
# Array<Strings> patterns : Array of patterns. (STRINGS)
search_line() {
    local line=$1
    local patterns=${@:2}
    local IS_COMMENTED=$FALSE
    for pattern in $patterns; do
        search_pattern "$line" "$pattern"
    done
    if [ $IS_COMMENTED = $TRUE ]; then
        comment_count_incr
    fi
}


# Searches pattern within a line. Will use comment block methods if there is a delimiter
# and will avoid detecting normal comments if within a comment block.
# search_line(String line, String pattern)
#
# String line : String of an individual line. (STRING)
# 
# Strings pattern : Pattern to search for. (STRING)
search_pattern() {
    local line=$1
    local pattern=$2
    if [[ $pattern =~ $DELIMITER ]]; then
        search_block_comment "$line" "$pattern"
    elif [[ $COMMENT_BLOCK_LOCK = $FALSE ]]; then
        search_normal_comment "$line" "$pattern"
    fi
}

# Searches for normal pattern. This means a traditional single lined comment.
# search_normal_comment(String line, String pattern)
#
# String line : String of an individual line. (STRING)
# 
# Strings pattern : Pattern to search for. (STRING)
search_normal_comment() {
    local line=$1
    local pattern=$2
    if [[ $line =~ $pattern ]]; then
        debug_search_normal_comment $pattern
        IS_COMMENTED=$TRUE
    fi
}

# Debug for search_normal_comment.
# debug_search_normal_comment(String pattern)
# 
# Strings pattern : Pattern to search for. (STRING)
debug_search_normal_comment() {
    local pattern=$1
    if [ $DEBUG = 0 ]; then
        echo "| | Found pattern $pattern! (Traditional Comment)"
    fi
}

# Searches for comment block pattern. If it is an inline / single line comment
# block then it will exit immidiately, count the line and not lock the comment_block_lock.
# Otherwise it will pass to the function for managing the comment block lock code.
# This code also sends the pattern to be delimited.
# search_block_comment(String line, Integer comment_block_lock, String pattern)
#
# String line : String of an individual line. (STRING)
#
# Integer comment_block_lock : State of comment block lock. Changes what to search for. (INTEGER)
# 
# Strings pattern : Pattern to search for. (STRING)
search_block_comment() {
    local line=$1
    local pattern=$2
    local block_patterns=($(delimit_pattern $pattern))
    local begin_block_pattern=${block_patterns[0]}
    local end_block_pattern=${block_patterns[1]}
    if is_single_lined_comment_block "$line" $begin_block_pattern $end_block_pattern; then
        debug_single_lined_comment_block $pattern
        IS_COMMENTED=$TRUE
    else
        control_comment_block_lock "$line" $begin_block_pattern $end_block_pattern
    fi
}

# Debug for single_lined_comment_block logic.
# debug_single_lined_comment_block(String pattern)
# 
# Strings pattern : Pattern to search for. (STRING)
debug_single_lined_comment_block() {
    local pattern=$1
    if [ $DEBUG = 0 ]; then
        echo "| | Found pattern $pattern! (Inline / Single Line Comment Block)"
    fi
}

# Manages comment block lock code and logic for adding each line within a comment block.
# It will lock comment_block_lock if it is in a comment block and unlock on exit. This lock 
# will add each line to the comment count when locked.
# control_comment_block_lock(String line, String begin_block_pattern, String end_block_pattern)
#
# String line : String of an individual line. (STRING)
#
# String begin_block_pattern : Beginning of comment block pattern to search for. (STRING)
# 
# Strings end_block_pattern : End of comment block pattern to search for. (STRING)
control_comment_block_lock() {
    local line=$1
    local begin_block_pattern=$2
    local end_block_pattern=$3
    if [[ $COMMENT_BLOCK_LOCK = $TRUE ]]; then
        attempt_unlock "$line" $end_block_pattern
        IS_COMMENTED=$TRUE
    elif [[ $line =~ ^$begin_block_pattern ]]; then
        debug_control_comment_block_locked $begin_block_pattern
        COMMENT_BLOCK_LOCK=$TRUE
        IS_COMMENTED=$TRUE
    fi
}

# Debug for debug_control_comment_block_locked logic.
# debug_control_comment_block_locked(String pattern)
# 
# Strings pattern : Pattern to search for. (STRING)
debug_control_comment_block_locked() {
    local pattern=$1
    if [ $DEBUG = 0 ]; then
        echo "| | Found pattern $pattern! (Beginning of Multi-lined Comment Block)"
    fi
}

# Attempts exiting comment block via unlocking the comment_block_lock.
# attempt_unlock(String line, String end_block_pattern)
#
# String line : String of an individual line. (STRING)
# 
# Strings end_block_pattern : End of comment block pattern to search for. (STRING)
attempt_unlock() {
    local line=$1
    local end_block_pattern=$2
    if [[ $line =~ $end_block_pattern ]]; then
        debug_attempt_unlock $end_block_pattern
        COMMENT_BLOCK_LOCK=$FALSE
    fi
}

# Debug for debug_attempt_unlock logic.
# debug_attempt_unlock(String pattern)
# 
# Strings pattern : Pattern to search for. (STRING)
debug_attempt_unlock() {
    local pattern=$1
    if [ $DEBUG = 0 ]; then
        echo "| | | Found pattern $pattern! (End of Multi-lined Comment Block)"
    fi
}

# Checks if it is an inline / single line comment.
# is_single_lined_comment_block(String begin_block_pattern, String end_block_pattern)
#
# Strings begin_block_pattern : Begin of comment block pattern to search for. (STRING)
#
# Strings end_block_pattern : End of comment block pattern to search for. (STRING)
is_single_lined_comment_block() {
    local line=$1
    local begin_block_pattern=$2
    local end_block_pattern=$3
    [[ $line =~ ^$begin_block_pattern ]] && [[ ${line:${#begin_block_pattern}} =~ $end_block_pattern ]]
}

# Checks if it is an inline / single line comment.
# delimit_pattern(String pattern)
#
# Strings pattern : Pattern to delimit. (STRING)
delimit_pattern() {
    local pattern=$1
    IFS=$DELIMITER read -ra split <<<$pattern
    local begin_pattern="${split[0]}"
    local end_pattern="${split[1]}"
    echo "$begin_pattern $end_pattern"
}

# Checks if line is blank.
# is_blank(String line)
#
# String line : String of an individual line. (STRING)
is_blank() {
    local line=$1
    [ -z "${line//[[:space:]]/}" ]
}

# Increment commented line count.
comment_count_incr() {
    debug_comment_count_incr
    COMMENTED_LINES+=1
}

 # Debug comment_count_incr.
debug_comment_count_incr() {
    if [ $DEBUG = 0 ]; then
        echo "| | | This is a commented line!"
    fi
}

# Run main
main
