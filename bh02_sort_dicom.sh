#!/bin/bash
# Script to sort DICOM files using dcm_sort_dir.py
# K.Nemoto 13 Dec 2024

# For debugging
#set -x

if [[ $# -lt 1 ]]; then
    echo "Please specify a name of sequence sets"
    echo "Usage: $0 <name of sequence set>"
    exit 1
fi

# First argument is a name of sequence set
setname=${1%/}

# Specify the path of 00_addpath.sh
batchpath=$(dirname $(command -v bh00_addpath.sh))

# Check if the directory exists
if [[ ! -d $setname ]]; then
    echo "Error: Directory $setname does not exist"
    echo "Please run 01_prep_dir.sh first"
    exit 1
fi

cd $setname

# Check if there are DICOM directories in original
dicom_dirs=$(ls -d DICOM/original/*/ 2>/dev/null)
if [[ -z "$dicom_dirs" ]]; then
    echo "Error: No directories found in DICOM/original/"
    echo "Please copy DICOM directories to DICOM/original/ first"
    exit 1
fi

# Replace spaces with underscores in directory and file names
echo "Replacing spaces with underscores in directory and file names..."
# Single find command to handle all files and directories with spaces
find DICOM/original -name '* *' | \
while read -r line; do
    newline=$(echo "$line" | sed -e 's/ /_/g' -e 's/__/_/g')
    # Check if source path still exists (in case parent was already renamed)
    [[ -e "$line" ]] && mv "$line" "$newline"
done

# Sort DICOM files
echo "Sorting DICOM files..."
cd DICOM/original
${batchpath}/dcm_sort_dir.py *

# Move sorted files to the correct location
echo "Moving sorted files to DICOM/sorted/"
mv ../sorted/* ../sorted_tmp 2>/dev/null
cd ..
for dir in sorted_tmp/*; do
    if [[ -d $dir ]]; then
        mv "$dir" sorted/
    fi
done
rm -rf sorted_tmp 2>/dev/null

echo "DICOM sorting completed:"
echo "- Original files remain in: DICOM/original/"
echo "- Sorted files are in: DICOM/sorted/"
echo
echo "You can now proceed with creating the subject list."

exit 0
