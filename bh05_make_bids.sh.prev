#!/bin/bash
# Script to convert DICOM to BIDS using heudiconv
# Run this script after bh04_make_heuristic.sh
# Prerequisites: dcm2niix and heudiconv
# K.Nemoto 13 Dec 2024

# For debugging
#set -x

usage() {
    echo "Convert sorted DICOM files to BIDS format"
    echo "Usage: $0 <setname>"
    echo "Prerequisites:"
    echo "  - Sorted DICOM files in DICOM/sorted/"
    echo "  - Subject list in tmp/subjlist_<setname>.tsv"
    echo "  - Heuristic file in code/heuristic_<setname>.py"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

# Parameters
setname=${1%/}
heuristic="code/heuristic_${setname}.py"
subjlist="tmp/subjlist_${setname}.tsv"

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
    echo "Please run bh04_make_heuristic.sh first"
    exit 1
fi

if [[ ! -d DICOM/sorted ]]; then
    echo "Error: Sorted DICOM directory not found"
    echo "Please run bh02_sort_dicom.sh first"
    exit 1
fi

# Clean up any previous heudiconv directory
[[ -d bids/.heudiconv ]] && rm -rf bids/.heudiconv

# Process subjects
echo "Starting BIDS conversion..."

# Process each subject
tail -n +2 "$subjlist" | while IFS=$'\t' read -r dirpattern subject session
do
    echo "Processing: Subject=$subject Session=$session"
    
    # Use the dicom_pattern directly from the first column of subjlist
    dicom_pattern="DICOM/sorted/${dirpattern}/*/*"
    
    # Run heudiconv
    heudiconv -d "$dicom_pattern" \
              -o bids/rawdata \
              -f "$heuristic" \
              -s "$subject" \
              -ss "$session" \
              -c dcm2niix \
              -b \
              --overwrite
              
    # Check heudiconv exit status
    if [[ $? -ne 0 ]]; then
        echo "Warning: heudiconv reported an error for subject $subject session $session"
    fi
done

# Set appropriate permissions
echo "Setting permissions..."
find bids/rawdata -type d -exec chmod 755 {} \;
find bids/rawdata -type f -exec chmod 644 {} \;

# Backup DICOM files
echo "Backing up DICOM files..."
#cp -ar DICOM/sorted/ DICOM/converted/
#cp -ar DICOM/original/ DICOM/converted/
mv DICOM/sorted DICOM/converted/
mv DICOM/original DICOM/converted/

# Clean up
echo "Cleaning up..."
rm -rf DICOM/sorted/*
rm -rf DICOM/original/*

echo "BIDS conversion completed"
echo "- BIDS data is in: bids/"
echo "- Converted DICOM files are backed up in: DICOM/converted/"
echo "Please validate your BIDS dataset using the BIDS Validator"

exit 0
