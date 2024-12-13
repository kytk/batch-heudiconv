#!/bin/bash
# preparation script for DICOM to BIDS conversion using heudiconv
# Part1. organize directory structure
# K.Nemoto 13 Dec 2024

# For debugging
# set -x

if [[ $# -lt 1 ]]; then
    echo "Please specify a name of sequence sets"
    echo "Usage: $0 <name of sequence set>"
    exit 1
fi

# First argument is a name of sequence set (e.g. MR0042)
setname=${1%/}

# Specify the path of bh00_addpath.sh
batchpath=$(dirname $(command -v bh00_addpath.sh))

# prepare working directory
[[ -d $setname ]] || mkdir $setname
cd $setname

# prepare directory structure
declare -a dirs=(
    "DICOM/original"
    "DICOM/sorted"
    "DICOM/converted"
    "bids/derivatives"
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
    echo "Warning: No heuristics found in ${batchpath}/code"
fi

echo "Directory structure for ${setname} has been prepared:"
echo "- DICOM/original/  : Place your original DICOM files here"
echo "- DICOM/sorted/    : Sorted DICOM files will be stored here"
echo "- DICOM/converted/ : Backup of processed DICOM files"
echo "- bids/           : BIDS-formatted output will be stored here"
echo "- code/           : Location for heuristic files"
echo "- tmp/            : Temporary files"
echo
echo "Please copy DICOM files to DICOM/original/ directory to proceed."

exit 0
