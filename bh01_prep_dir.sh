#!/bin/bash
# preparation script for DICOM to BIDS conversion using heudiconv
# Part1. organize directory structure
# K.Nemoto 24 May 2025

# For debugging
# set -x

if [[ $# -lt 1 ]]; then
    echo "Create a new BIDS conversion study with organized directory structure"
    echo "Usage: $0 <study_name>"
    echo ""
    echo "Examples:"
    echo "  $0 resting_state_2024    # Creates 'resting_state_2024' study"
    echo "  $0 pilot_dwi_study       # Creates 'pilot_dwi_study' study"
    echo "  $0 longitudinal_cohort   # Creates 'longitudinal_cohort' study"
    echo ""
    echo "This will create a complete workspace under '<study_name>/' containing:"
    echo "  - DICOM/original/   : Place your DICOM files here"
    echo "  - DICOM/sorted/     : For organized DICOM files"
    echo "  - bids/rawdata/     : Final BIDS output"
    echo "  - bids/derivatives/ : For processed data"
    echo "  - code/             : Heuristic files"
    echo "  - tmp/              : Working files"
    exit 1
fi

# First argument is a name of study (e.g. resting_state_2024)
study_name=${1%/}

# Specify the path of bh00_addpath.sh
batchpath=$(dirname $(command -v bh00_addpath.sh))

# prepare working directory
[[ -d $study_name ]] || mkdir $study_name
cd $study_name

# prepare directory structure
declare -a dirs=(
    "DICOM/original"
    "DICOM/sorted"
    "DICOM/converted"
    "bids/derivatives"
    "bids/rawdata"
    "tmp"
    "code"
)

for dir in "${dirs[@]}"; do
    [[ -d $dir ]] || mkdir -p $dir
done

# Copy heuristics if they exist in batchpath
if [[ -d ${batchpath}/code ]]; then
    cp -r ${batchpath}/code/* code/
else
    echo "Warning: No template heuristics found in ${batchpath}/code"
fi

echo "Directory structure for study '${study_name}' has been prepared:"
echo ""
echo "Next steps:"
echo "1. Copy your DICOM files to: ${study_name}/DICOM/original/"
echo "2. Run: bh02_sort_dicom.sh ${study_name}"
echo ""
echo "Directory structure created:"
echo "  ${study_name}/"
echo "  ├── DICOM/"
echo "  │   ├── original/    # Place your original DICOM files here"
echo "  │   ├── sorted/      # Sorted DICOM files will be stored here"
echo "  │   └── converted/   # Backup of processed DICOM files"
echo "  ├── bids/"
echo "  │   ├── rawdata/     # BIDS-formatted output will be stored here"
echo "  │   └── derivatives/ # Processed data location"
echo "  ├── code/            # Heuristic files for this study"
echo "  └── tmp/             # Working files"

exit 0
