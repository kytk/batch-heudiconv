#!/bin/bash
# Script to convert DICOM to BIDS using heudiconv
# Special handling for double-echo field map data using merge.json
# Run this script after bh03_make_subjlist.sh
# Prerequisites: dcm2niix and heudiconv
# K.Nemoto 13 Dec 2024

# For debugging
#set -x

usage() {
    echo "Convert sorted DICOM files to BIDS format (with double-echo fieldmap handling)"
    echo "Usage: $0 <setname> [fieldmap_threshold]"
    echo "Parameters:"
    echo "  setname            : Name of the sequence set"
    echo "  fieldmap_threshold : Number of expected files for double-echo fieldmap (default: 78)"
    echo
    echo "Prerequisites:"
    echo "  - Sorted DICOM files in DICOM/sorted/"
    echo "  - Subject list in tmp/subjlist_<setname>.tsv"
    echo "  - Heuristic file in code/heuristic_<setname>.py"
    echo "  - merge.json in code/ (required for double-echo fieldmap merging)"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

# Parameters
setname=${1%/}
fmapthr=${2:-78}  # Default threshold is 78
heuristic="code/heuristic_${setname}.py"
subjlist="tmp/subjlist_${setname}.tsv"
merge_config="code/merge.json"

# Check if setname directory exists
if [[ ! -d $setname ]]; then
    echo "Error: Directory $setname does not exist"
    exit 1
fi

cd $setname

# Check prerequisites
if [[ ! -f $subjlist ]]; then
    echo "Error: Subject list not found: $subjlist"
    echo "Please run bh03_make_subjlist.sh first"
    exit 1
fi

if [[ ! -f $heuristic ]]; then
    echo "Error: Heuristic file not found: $heuristic"
    echo "Please prepare your heuristic file"
    exit 1
fi

if [[ ! -d DICOM/sorted ]]; then
    echo "Error: Sorted DICOM directory not found"
    echo "Please run bh02_sort_dicom.sh first"
    exit 1
fi

# Create merge.json if it doesn't exist
if [[ ! -f $merge_config ]]; then
    echo "Creating merge.json for double-echo fieldmap processing..."
    mkdir -p $(dirname $merge_config)
    cat > $merge_config << 'EOF'
{
"merge_imgs": true
}
EOF
    echo "Created $merge_config"
fi

# Clean up any previous heudiconv directory
[[ -d bids/.heudiconv ]] && rm -rf bids/.heudiconv

# Process subjects
echo "Starting BIDS conversion with double-echo fieldmap handling..."
echo "Using fieldmap threshold: $fmapthr files"

tail -n +2 "$subjlist" | while IFS=$'\t' read -r dirname subject session
do
    echo "Processing: Subject=$subject Session=$session"
    
    # Check for double-echo fieldmap conditions
    ndirs=$(find "DICOM/sorted/${dirname}/"*[Ff]ield* -type d 2>/dev/null | wc -l)
    nfiles=$(find "DICOM/sorted/${dirname}/"*[Ff]ield* -type f 2>/dev/null | wc -l)
    
    if [[ $ndirs -eq 2 ]] && [[ $nfiles -eq $fmapthr ]]; then
        echo "Detected double-echo fieldmap for ${subject}_${session}"
        heudiconv -d "DICOM/sorted/${dirname}/*/*" \
                  -o bids \
                  -f "$heuristic" \
                  -s "$subject" \
                  -ss "$session" \
                  -c dcm2niix \
                  --dcmconfig "$merge_config" \
                  -b \
                  --overwrite
    else
        echo "Warning: Subject ${subject}_${session} does not match double-echo fieldmap criteria"
        echo "  - Number of fieldmap directories: $ndirs (expected: 2)"
        echo "  - Number of fieldmap files: $nfiles (expected: $fmapthr)"
        echo "Please check if this subject should be processed with bh04_make_bids.sh instead"
        exit 1
    fi
done

# Set appropriate permissions
echo "Setting permissions..."
find bids -type d -exec chmod 755 {} \;
find bids -type f -exec chmod 644 {} \;

# Backup DICOM files
echo "Backing up DICOM files..."
cp -ar DICOM/sorted/ DICOM/converted/
cp -ar DICOM/original/ DICOM/converted/

# Clean up
echo "Cleaning up..."
rm -rf DICOM/sorted/*
rm -rf DICOM/original/*

echo "BIDS conversion completed successfully"
echo "- BIDS data is in: bids/"
echo "- Converted DICOM files are backed up in: DICOM/converted/"
echo "Please validate your BIDS dataset using the BIDS Validator"

exit 0
