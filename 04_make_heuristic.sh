#!/bin/bash
# Script to create heuristic.py for BIDS conversion
# Run this script after 03_make_subjlist.sh
# K.Nemoto 13 Dec 2024

# For debugging
#set -x

usage() {
    echo "Create heuristic.py by analyzing DICOM directory structure"
    echo "Usage: $0 <setname>"
    echo
    echo "This script will:"
    echo "1. Analyze your DICOM directory structure"
    echo "2. Help identify sequence types"
    echo "3. Generate a customized heuristic.py file"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

setname=${1%/}

# Check prerequisites
if [[ ! -d $setname/DICOM/sorted ]]; then
    echo "Error: Sorted DICOM directory not found"
    echo "Please run 02_sort_dicom.sh first"
    exit 1
fi

if [[ ! -f $setname/tmp/subjlist_${setname}.tsv ]]; then
    echo "Error: Subject list not found"
    echo "Please run 03_make_subjlist.sh first"
    exit 1
fi

# Create temporary files
mkdir -p "$setname/tmp"
mkdir -p "$setname/code"
series_list="$setname/tmp/series_list.txt"
template_file="$setname/code/heuristic_${setname}.py"

# Function to detect sequence type based on directory name and DICOM header
detect_sequence_type() {
    local dirname=$1
    local dim4=${2:-1}
    
    # Remove series number prefix (e.g., "01_" from "01_MPRAGE")
    local series_desc=${dirname#[0-9]*_}
    
    # Convert to uppercase for case-insensitive matching
    local desc_upper=$(echo "$series_desc" | tr '[:lower:]' '[:upper:]')
    
    case $desc_upper in
        # T1w patterns - Siemens & GE
        *"MPRAGE"*|*"T1W"*|*"T1"*|*"3D_T1"*|*"IR-FSPGR"*|*"BRAVO"*|*"SAG"*)
            echo "T1w"
            ;;
        
        # T2w patterns - Siemens & GE
        *"T2W"*|*"T2"*|*"T2_TSE"*|*"SPC_T2"*|*"FLAIR"*|*"CUBE"*|*"T2FLAIR"*)
            echo "T2w"
            ;;
        
        # Resting-state fMRI patterns
        *"REST"*|*"RESTING"*|*"RESTING_STATE"*|*"RS_MB"*|*"RESTING_STATE_FMRI"*)
            if [[ $dim4 -gt 100 ]]; then
                echo "func_rest"
            else
                echo "unknown"
            fi
            ;;
        
        # DWI patterns
        *"DWI"*|*"DTI"*|*"DIFF"*|*"EP2D_DIFF"*|*"DTI_30"*|*"TENSOR"*)
            if [[ $dim4 -gt 5 ]]; then
                echo "dwi"
            else
                echo "unknown"
            fi
            ;;
        
        # Fieldmap patterns
        *"FIELD"*|*"FIELD_MAP"*|*"FIELD_MAPPING"*)
            if [[ $desc_upper == *"MAPPING"* ]]; then
                echo "fieldmap_siemens"
            else
                echo "fieldmap_ge"
            fi
            ;;
        
        # Phase encoding patterns
        *"_AP"*|*"_PA"*|*"_LR"*|*"_RL"*)
            if [[ $desc_upper =~ (REST|RESTING|RS) ]]; then
                echo "func_rest_dir"
            elif [[ $desc_upper =~ (DWI|DTI|DIFF) ]]; then
                echo "dwi_dir"
            else
                echo "unknown"
            fi
            ;;
        
        *)
            echo "unknown"
            ;;
    esac
}

echo "Analyzing DICOM directory structure..."

# Clear and create series list
> "$series_list"

# Process each directory and create series list
while IFS= read -r dir; do
    series_name=$(basename "$dir")
    # Get dim4 from example DICOM if possible
    dim4=1
    if command -v dcmdump >/dev/null 2>&1; then
        example_dcm=$(find "$dir" -type f -name "*.dcm" -o -name "*.IMA" | head -n 1)
        if [[ -n "$example_dcm" ]]; then
            dim4=$(dcmdump "$example_dcm" 2>/dev/null | grep NumberOfTemporalPositions || echo "1")
        fi
    fi
    sequence_type=$(detect_sequence_type "$series_name" "$dim4")
    echo "$series_name|$sequence_type|$dim4" >> "$series_list"
done < <(find "$setname/DICOM/sorted" -mindepth 2 -maxdepth 2 -type d)

# Check if series list was created successfully
if [[ ! -s "$series_list" ]]; then
    echo "Error: No series found in DICOM/sorted/"
    exit 1
fi

echo "Found sequences:"
cat "$series_list"
echo

# Generate heuristic.py
echo "Generating heuristic.py..."

# Generate header and fixed parts
cat > "$template_file" << EOF
# heuristic.py for ${setname}
# Generated by 04_make_heuristic.sh
# $(date +%Y-%m-%d)

import os

def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return template, outtype, annotation_classes

def infotodict(seqinfo):
    """Heuristic evaluator for determining which runs belong where

    allowed template fields - follow python string module:

    item: index within category
    subject: participant id
    seqitem: run number during scanning
    subindex: sub index within group
    """

    ##### list keys for t1w, t2w, dwi, rs-fMRI, and filedmaps below ############
EOF

# Add key definitions based on whether session is used
if grep -q "{session}" "$setname/tmp/subjlist_${setname}.tsv"; then
    cat >> "$template_file" << 'KEYS_WITH_SESSION'
    # T1
    t1w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T1w')

    # T2
    #t2w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T2w')

    # Resting-state (only one phase encoding)
    func_rest = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_run-{item:02d}_bold')

    # Resting-state (PA and AP)
    #func_rest_PA = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_dir-PA_task-rest_run-{item:02d}_bold')
    #func_rest_AP = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_dir-AP_task-rest_run-{item:02d}_bold')

    # DWI (only one phase encoding)
    dwi = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_run-{item:02d}_dwi')

    # DWI (PA and AP)
    #dwi_PA = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-PA_run-{item:02d}_dwi')
    #dwi_AP = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-AP_run-{item:02d}_dwi')

    # Filed map (magnitude and phasediff: Siemens)
    # If you have double echo field maps, convert phasediff first, then convert magnitude later. 
    fmap_mag =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_magnitude')
    fmap_phase = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_phasediff')

    # Field map (two phases: Siemens)
    #fmap_PA =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-PA_fieldmap')
    #fmap_AP =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-AP_fieldmap')

    # Field map (magnitude and field: GE)
    #fmap_mag =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_magnitude')
    #fmap_field = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_fieldmap')
KEYS_WITH_SESSION
else
    cat >> "$template_file" << 'KEYS_WITHOUT_SESSION'
    # T1
    t1w = create_key('sub-{subject}/anat/sub-{subject}_run-{item:02d}_T1w')

    # T2
    #t2w = create_key('sub-{subject}/anat/sub-{subject}_run-{item:02d}_T2w')

    # Resting-state (only one phase encoding)
    func_rest = create_key('sub-{subject}/func/sub-{subject}_task-rest_run-{item:02d}_bold')

    # Resting-state (PA and AP)
    #func_rest_PA = create_key('sub-{subject}/func/sub-{subject}_dir-PA_task-rest_run-{item:02d}_bold')
    #func_rest_AP = create_key('sub-{subject}/func/sub-{subject}_dir-AP_task-rest_run-{item:02d}_bold')

    # DWI (only one phase encoding)
    dwi = create_key('sub-{subject}/dwi/sub-{subject}_run-{item:02d}_dwi')

    # DWI (PA and AP)
    #dwi_PA = create_key('sub-{subject}/dwi/sub-{subject}_dir-PA_run-{item:02d}_dwi')
    #dwi_AP = create_key('sub-{subject}/dwi/sub-{subject}_dir-AP_run-{item:02d}_dwi')

    # Filed map (magnitude and phasediff: Siemens)
    # If you have double echo field maps, convert phasediff first, then convert magnitude later. 
    fmap_mag =  create_key('sub-{subject}/fmap/sub-{subject}_magnitude')
    fmap_phase = create_key('sub-{subject}/fmap/sub-{subject}_phasediff')
KEYS_WITHOUT_SESSION
fi

# Add info dictionary initialization and seqinfo documentation
cat >> "$template_file" << 'COMMON'

    info = {t1w: [], func_rest: [], dwi: [], fmap_mag: [], fmap_phase: []}

    ############################################################################

    for idx, s in enumerate(seqinfo):
        """
        The namedtuple `s` contains the following fields:

        * total_files_till_now
        * example_dcm_file
        * series_id
        * dcm_dir_name
        * unspecified2
        * unspecified3
        * dim1
        * dim2
        * dim3
        * dim4
        * TR
        * TE
        * protocol_name
        * is_motion_corrected
        * is_derived
        * patient_id
        * study_description
        * referring_physician_name
        * series_description
        * image_type
        """

COMMON

# Add sequence matching rules
while IFS='|' read -r dirname seqtype dim4; do
    series_desc=${dirname#[0-9]*_}  # Remove series number
    case $seqtype in
        "T1w")
            echo "        # T1w" >> "$template_file"
            echo "        if '${series_desc}' in s.dcm_dir_name:" >> "$template_file"
            echo "            info[t1w].append(s.series_id)" >> "$template_file"
            echo >> "$template_file"
            ;;
        "func_rest")
            echo "        # Resting-state fMRI" >> "$template_file"
            echo "        if '${series_desc}' in s.dcm_dir_name and s.dim4 >= 100:" >> "$template_file"
            echo "            info[func_rest].append(s.series_id)" >> "$template_file"
            echo >> "$template_file"
            ;;
        "dwi")
            echo "        # DWI" >> "$template_file"
            echo "        if '${series_desc}' in s.dcm_dir_name and s.dim4 > 5:" >> "$template_file"
            echo "            info[dwi].append(s.series_id)" >> "$template_file"
            echo >> "$template_file"
            ;;
        "fieldmap_siemens")
            echo "        # Fieldmap (Siemens)" >> "$template_file"
            echo "        if '${series_desc}' in s.dcm_dir_name:" >> "$template_file"
            echo "            if 'M' in s.image_type:" >> "$template_file"
            echo "                info[fmap_mag].append(s.series_id)" >> "$template_file"
            echo "            if 'P' in s.image_type:" >> "$template_file"
            echo "                info[fmap_phase].append(s.series_id)" >> "$template_file"
            echo >> "$template_file"
            ;;
    esac
done < "$series_list"

# Add return statement and IntendedFor
cat >> "$template_file" << 'EOF'
    return info

# IntendedFor
POPULATE_INTENDED_FOR_OPTS = {
    'matching_parameters': ['ImagingVolume', 'Shims'],
    'criterion': 'Closest'
}
EOF

echo "Heuristic file created: $template_file"
echo
echo "Please review and edit the file if necessary."
echo "You may need to:"
echo "1. Adjust the sequence matching conditions"
echo "2. Add phase encoding directions if needed"
echo "3. Modify the IntendedFor settings"

# Cleanup
rm -f "$series_list"

exit 0
