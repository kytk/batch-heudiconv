#!/bin/bash
# Script to create subject list for BIDS conversion
# Run this script after 02_sort_dicom.sh
# K.Nemoto 13 Dec 2024

# For debugging
#set -x

usage() {
    echo "Create subject list from directory names using specified pattern"
    echo "Usage: $0 <setname> <pattern>"
    echo "Patterns examples:"
    echo "  {subject}_{session}  - For directories like 'id0001_01'"
    echo "  {subject}-{session}  - For directories like 'id0001-01'"
    echo "  {subject}           - For directories like 'id0001'"
    exit 1
}

if [[ $# -lt 2 ]]; then
    usage
fi

# Parameters
setname=${1%/}
pattern=$2

# Check if setname directory exists
if [[ ! -d $setname ]]; then
    echo "Error: Directory $setname does not exist"
    echo "Please run 01_prep_dir.sh first"
    exit 1
fi

cd $setname

# Check if there are sorted DICOM directories
if [[ ! -d DICOM/sorted ]]; then
    echo "Error: DICOM/sorted directory not found"
    echo "Please run bh02_sort_dicom.sh first"
    exit 1
fi

# Create temporary directory if not exists
[[ -d tmp ]] || mkdir tmp

# Function to extract subject and session from directory name
extract_info() {
    local dirname=$1
    local pattern=$2
    
    # Handle subject and session extraction based on pattern
    if [[ "$pattern" == *"{subject}_{session}"* ]]; then
        # For patterns with session, split on the last underscore
        if [[ $dirname =~ ^(.*)_([^_]*)$ ]]; then
            subject="${BASH_REMATCH[1]}"
            session="${BASH_REMATCH[2]}"
            echo -e "{subject}_{session}\t$subject\t$session"
        fi
    else
        # For patterns without session, use the whole name as subject
        if [[ $dirname =~ ^(.*)$ ]]; then
            subject="${BASH_REMATCH[1]}"
            echo -e "{subject}\t$subject\t01"  # Default session to "01"
        fi
    fi
}

# Create header for subject list
echo -e "directory\tsubject_ID\tsession" > "tmp/subjlist_${setname}.tsv"

# Process each directory
for dir in DICOM/sorted/*; do
    if [[ -d $dir ]]; then
        dirname=$(basename "$dir")
        extract_info "$dirname" "$pattern" >> "tmp/subjlist_${setname}.tsv"
    fi
done

# Check if any subjects were found
if [[ $(wc -l < "tmp/subjlist_${setname}.tsv") -le 1 ]]; then
    echo "Error: No matching directories found with pattern: $pattern"
    echo "Available directories:"
    ls -1 DICOM/sorted/
    rm "tmp/subjlist_${setname}.tsv"
    exit 1
fi

echo "Subject list has been created: tmp/subjlist_${setname}.tsv"
echo "Content of the subject list:"
cat "tmp/subjlist_${setname}.tsv"
echo
echo "Please verify the subject list before proceeding with BIDS conversion."

exit 0
