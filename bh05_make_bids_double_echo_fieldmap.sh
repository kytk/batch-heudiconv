#!/bin/bash
# Script to convert DICOM to BIDS using heudiconv
# Special handling for double-echo field map data using merge.json
# Run this script after bh04_make_heuristic.sh
# Prerequisites: dcm2niix and heudiconv
# K.Nemoto 24 May 2025

# For debugging
#set -x

usage() {
    echo "Convert sorted DICOM files to BIDS format (with double-echo fieldmap handling)"
    echo "Usage: $0 <study_name> [fieldmap_threshold]"
    echo ""
    echo "Parameters:"
    echo "  study_name            : Name of your research study"
    echo "  fieldmap_threshold    : Number of expected files for double-echo fieldmap (default: 78)"
    echo ""
    echo "Prerequisites:"
    echo "  - Study setup completed with previous bh0X scripts"
    echo "  - Sorted DICOM files in: <study_name>/DICOM/sorted/"
    echo "  - Subject list: <study_name>/tmp/subjlist_<study_name>.tsv"
    echo "  - Heuristic file: <study_name>/code/heuristic_<study_name>.py"
    echo "  - merge.json in code/ (required for double-echo fieldmap merging)"
    echo ""
    echo "This script is specifically for studies with double-echo fieldmaps that need special processing."
    echo "For standard BIDS conversion, use: bh05_make_bids.sh <study_name>"
    echo ""
    echo "Output: <study_name>/bids/rawdata/ (BIDS dataset)"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

# Parameters
study_name=${1%/}
fmapthr=${2:-78}  # Default threshold is 78
heuristic="code/heuristic_${study_name}.py"
subjlist="tmp/subjlist_${study_name}.tsv"
merge_config="code/merge.json"

# Check if study directory exists
if [[ ! -d $study_name ]]; then
    echo "Error: Study directory '$study_name' does not exist"
    echo "Please run: bh01_prep_dir.sh $study_name"
    exit 1
fi

cd $study_name

# Check prerequisites
if [[ ! -f $subjlist ]]; then
    echo "Error: Subject list not found: $subjlist"
    echo "Please run: bh03_make_subjlist.sh $study_name '<pattern>'"
    exit 1
fi

if [[ ! -f $heuristic ]]; then
    echo "Error: Heuristic file not found: $heuristic"
    echo "This file defines how DICOM sequences in '$study_name' should be converted to BIDS"
    echo "Please run: bh04_make_heuristic.sh $study_name"
    exit 1
fi

if [[ ! -d DICOM/sorted ]]; then
    echo "Error: Sorted DICOM directory not found"
    echo "Please run: bh02_sort_dicom.sh $study_name"
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
echo "Starting BIDS conversion with double-echo fieldmap handling for study: $study_name"
echo "Using fieldmap threshold: $fmapthr files"
echo "Using heuristic: $heuristic"
echo ""

# Count total subjects
total_subjects=$(($(wc -l < "$subjlist") - 1))
current_subject=0

tail -n +2 "$subjlist" | while IFS=$'\t' read -r dirname subject session
do
    current_subject=$((current_subject + 1))
    echo "[$current_subject/$total_subjects] Processing: Subject=$subject Session=$session"
    
    # Check for double-echo fieldmap conditions
    ndirs=$(find "DICOM/sorted/${dirname}/"*[Ff]ield* -type d 2>/dev/null | wc -l)
    nfiles=$(find "DICOM/sorted/${dirname}/"*[Ff]ield* -type f 2>/dev/null | wc -l)
    
    if [[ $ndirs -eq 2 ]] && [[ $nfiles -eq $fmapthr ]]; then
        echo "  ✓ Detected double-echo fieldmap for ${subject}_${session}"
        heudiconv -d "DICOM/sorted/${dirname}/*/*" \
                  -o bids/rawdata \
                  -f "$heuristic" \
                  -s "$subject" \
                  -ss "$session" \
                  -c dcm2niix \
                  --dcmconfig "$merge_config" \
                  -b \
                  --overwrite
                  
        # Check heudiconv exit status
        if [[ $? -ne 0 ]]; then
            echo "  Warning: heudiconv reported an error for subject $subject session $session"
            echo "  Check the logs and heuristic file for issues"
        else
            echo "  ✓ Successfully processed subject $subject"
        fi
    else
        echo "  Warning: Subject ${subject}_${session} does not match double-echo fieldmap criteria"
        echo "    - Number of fieldmap directories: $ndirs (expected: 2)"
        echo "    - Number of fieldmap files: $nfiles (expected: $fmapthr)"
        echo "    Please check if this subject should be processed with bh05_make_bids.sh instead"
        exit 1
    fi
    echo ""
done

# Set appropriate permissions
echo "Setting file permissions..."
find bids/rawdata -type d -exec chmod 755 {} \; 2>/dev/null
find bids/rawdata -type f -exec chmod 644 {} \; 2>/dev/null

# Backup DICOM files
echo "Backing up DICOM files..."
if [[ ! -d DICOM/converted ]]; then
    mkdir -p DICOM/converted
fi

# Move instead of copy to save space
if [[ -d DICOM/sorted ]]; then
    mv DICOM/sorted DICOM/converted/sorted_$(date +%Y%m%d_%H%M%S)
fi
if [[ -d DICOM/original ]]; then
    mv DICOM/original DICOM/converted/original_$(date +%Y%m%d_%H%M%S)
fi

# Create empty directories for future use
mkdir -p DICOM/sorted DICOM/original

echo ""
echo "============================================"
echo "Double-echo fieldmap BIDS conversion completed for study: $study_name"
echo "============================================"
echo ""
echo "Results:"
echo "  - BIDS dataset: $study_name/bids/rawdata/"
echo "  - Subjects processed: $total_subjects"
echo "  - DICOM backup: $study_name/DICOM/converted/"
echo ""
echo "Next steps:"
echo "1. Validate BIDS dataset: https://bids-standard.github.io/bids-validator/"
echo "2. Review conversion logs for any warnings"
echo "3. Check dataset_description.json and README files"
echo ""
echo "Optional post-processing:"
echo "  - Fix IntendedFor fields: bh_fix_intendedfor.py $study_name"
echo "  - Reorganize GE fieldmaps: bh_reorganize_fieldmaps.py $study_name"

exit 0
