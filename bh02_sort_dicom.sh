#!/bin/bash
# Script to sort DICOM files using bh_dcm_sort_dir.py
# K.Nemoto 24 May 2025

# For debugging
#set -x

if [[ $# -lt 1 ]]; then
    echo "Sort DICOM files into series-based directories for BIDS conversion"
    echo "Usage: $0 <study_name>"
    echo ""
    echo "Prerequisites:"
    echo "  - Study directory created with: bh01_prep_dir.sh <study_name>"
    echo "  - DICOM files placed in: <study_name>/DICOM/original/"
    echo ""
    echo "This script will:"
    echo "  1. Organize DICOM files by series number and description"
    echo "  2. Clean up filenames (replace spaces with underscores)"
    echo "  3. Create sorted directory structure for heudiconv"
    exit 1
fi

# First argument is a name of study
study_name=${1%/}

# Specify the path of bh00_addpath.sh
batchpath=$(dirname $(command -v bh00_addpath.sh))

# Check if the study directory exists
if [[ ! -d $study_name ]]; then
    echo "Error: Study directory '$study_name' does not exist"
    echo "Please run: bh01_prep_dir.sh $study_name"
    exit 1
fi

cd $study_name

# Check if there are DICOM directories in original
dicom_dirs=$(ls -d DICOM/original/*/ 2>/dev/null)
if [[ -z "$dicom_dirs" ]]; then
    echo "Error: No directories found in DICOM/original/"
    echo "Please copy DICOM directories to DICOM/original/ first"
    echo ""
    echo "Expected structure:"
    echo "  ${study_name}/DICOM/original/"
    echo "  ├── subject_01/"
    echo "  ├── subject_02/"
    echo "  └── ..."
    exit 1
fi

# Replace spaces with underscores in directory and file names
echo "Cleaning up filenames (replacing spaces with underscores)..."
# Single find command to handle all files and directories with spaces
find DICOM/original -name '* *' | \
while read -r line; do
    newline=$(echo "$line" | sed -e 's/ /_/g' -e 's/__/_/g')
    # Check if source path still exists (in case parent was already renamed)
    [[ -e "$line" ]] && mv "$line" "$newline"
done

# Sort DICOM files
echo "Sorting DICOM files by series..."
cd DICOM/original
${batchpath}/bh_dcm_sort_dir.py *

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

echo ""
echo "DICOM sorting completed successfully!"
echo ""
echo "Next steps:"
echo "1. Create subject list: bh03_make_subjlist.sh $study_name '<pattern>'"
echo ""
echo "   <pattern> should be one of the following:"
echo "   '{subject}_{session}'  - for directories like 'sub001_ses01'"
echo "   '{subject}-{session}'  - for directories like 'sub001-ses01'"
echo "   '{subject}'           - for directories like 'sub001' (single session)"
echo ""
echo "   Example: bh03_make_subjlist.sh $study_name '{subject}_{session}'"
echo ""
echo "2. Review sorted structure in: ${study_name}/DICOM/sorted/"
echo ""
echo "File locations:"
echo "  - Original files: DICOM/original/ (preserved)"
echo "  - Sorted files:   DICOM/sorted/ (ready for conversion)"

exit 0
