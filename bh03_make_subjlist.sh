#!/bin/bash
# Script to create subject list for BIDS conversion
# Run this script after bh02_sort_dicom.sh
# K.Nemoto 24 May 2025

# For debugging
#set -x

usage() {
    echo "Create subject list from directory names for your study"
    echo "Usage: $0 <study_name> <pattern>"
    echo ""
    echo "Pattern examples:"
    echo "  '{subject}_{session}'  - For directories like 'sub001_ses01'"
    echo "  '{subject}-{session}'  - For directories like 'sub001-ses01'"
    echo "  '{subject}'           - For directories like 'sub001' (single session)"
    echo ""
    echo "Prerequisites:"
    echo "  - Study directory created with: bh01_prep_dir.sh <study_name>"
    echo "  - DICOM files sorted with: bh02_sort_dicom.sh <study_name>"
    echo ""
    echo "This creates: <study_name>/tmp/subjlist_<study_name>.tsv"
    exit 1
}

if [[ $# -lt 2 ]]; then
    usage
fi

# Parameters
study_name=${1%/}
pattern=$2

# Check if study directory exists
if [[ ! -d $study_name ]]; then
    echo "Error: Study directory '$study_name' does not exist"
    echo "Please run: bh01_prep_dir.sh $study_name"
    exit 1
fi

cd $study_name

# Check if there are sorted DICOM directories
if [[ ! -d DICOM/sorted ]]; then
    echo "Error: DICOM/sorted directory not found"
    echo "Please run: bh02_sort_dicom.sh $study_name"
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
            echo -e "$dirname\t$subject\t$session"
        fi
    elif [[ "$pattern" == *"{subject}-{session}"* ]]; then
        # For patterns with session, split on the last hyphen
        if [[ $dirname =~ ^(.*)-([^-]*)$ ]]; then
            subject="${BASH_REMATCH[1]}"
            session="${BASH_REMATCH[2]}"
            echo -e "$dirname\t$subject\t$session"
        fi
    else
        # For patterns without session, use the whole name as subject
        if [[ $dirname =~ ^(.*)$ ]]; then
            subject="${BASH_REMATCH[1]}"
            echo -e "$dirname\t$subject\t01"  # Default session to "01"
        fi
    fi
}

# Create subject list file with pattern information at the top
subjlist_file="tmp/subjlist_${study_name}.tsv"

# Write pattern as metadata comment and header
cat > "$subjlist_file" << EOF
# pattern: $pattern
directory	subject_ID	session
EOF

# Process each directory
for dir in DICOM/sorted/*; do
    if [[ -d $dir ]]; then
        dirname=$(basename "$dir")
        extract_info "$dirname" "$pattern" >> "$subjlist_file"
    fi
done

# Check if any subjects were found
if [[ $(grep -v '^#' "$subjlist_file" | wc -l) -le 1 ]]; then
    echo "Error: No matching directories found with pattern: $pattern"
    echo ""
    echo "Available directories in DICOM/sorted/:"
    ls -1 DICOM/sorted/
    echo ""
    echo "Common patterns:"
    echo "  - If directories are like 'sub001_ses01': use '{subject}_{session}'"
    echo "  - If directories are like 'sub001': use '{subject}'"
    rm "$subjlist_file"
    exit 1
fi

echo "Subject list created successfully: $subjlist_file"
echo ""
echo "Content preview:"
cat "$subjlist_file"
echo ""
echo "Study: $study_name"
echo "Pattern used: $pattern"
echo "Subjects found: $(($(grep -v '^#' "$subjlist_file" | wc -l) - 1))"
echo ""

# Check if heuristic file already exists and suggest appropriate next step
heuristic_file="code/heuristic_${study_name}.py"
if [[ -f $heuristic_file ]]; then
    echo "Next step: Convert to BIDS with: bh05_make_bids.sh $study_name"
    echo "Note: Heuristic file already exists at: $heuristic_file"
else
    echo "Next step: Create heuristic file with: bh04_make_heuristic.sh $study_name"
fi

exit 0
