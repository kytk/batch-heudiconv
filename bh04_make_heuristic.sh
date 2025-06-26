#!/bin/bash
# Script to create heuristic.py for BIDS conversion
# Run this script after bh03_make_subjlist.sh
# K.Nemoto 24 May 2025

# For debugging
#set -x

usage() {
    echo "Create heuristic file by analyzing your study's DICOM structure"
    echo "Usage: $0 <study_name>"
    echo ""
    echo "This script will:"
    echo "1. Analyze your DICOM directory structure"
    echo "2. Identify sequence types (T1w, fMRI, DWI, fieldmaps)"
    echo "3. Generate code/heuristic_<study_name>.py"
    echo ""
    echo "Prerequisites:"
    echo "  - DICOM files sorted with: bh02_sort_dicom.sh <study_name>"
    echo "  - Subject list created with: bh03_make_subjlist.sh <study_name> '<pattern>'"
    echo ""
    echo "Output: <study_name>/code/heuristic_<study_name>.py"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

study_name=${1%/}

# Check prerequisites
if [[ ! -d $study_name/DICOM/sorted ]]; then
    echo "Error: Study '$study_name' - sorted DICOM directory not found"
    echo "Please run: bh02_sort_dicom.sh $study_name"
    exit 1
fi

if [[ ! -f $study_name/tmp/subjlist_${study_name}.tsv ]]; then
    echo "Error: Study '$study_name' - subject list not found"
    echo "Please run: bh03_make_subjlist.sh $study_name '<pattern>'"
    exit 1
fi

# Create temporary files
mkdir -p "$study_name/tmp"
mkdir -p "$study_name/code"
series_list="$study_name/tmp/series_list.txt"
template_file="$study_name/code/heuristic_${study_name}.py"

# Function to get dim4 from DICOM files
get_dim4_from_dicom() {
    local dir=$1
    local dim4=1
    
    # Try multiple methods to get the number of volumes
    if command -v dcmdump >/dev/null 2>&1; then
        local example_dcm=$(find "$dir" -type f \( -name "*.dcm" -o -name "*.IMA" \) | head -n 1)
        if [[ -n "$example_dcm" ]]; then
            # Try NumberOfTemporalPositions first
            local temp_pos=$(dcmdump "$example_dcm" 2>/dev/null | grep "NumberOfTemporalPositions" | grep -o '[0-9]\+' | head -n 1)
            if [[ -n "$temp_pos" && "$temp_pos" -gt 1 ]]; then
                dim4=$temp_pos
            else
                # Fallback: count DICOM files in directory
                local file_count=$(find "$dir" -type f \( -name "*.dcm" -o -name "*.IMA" \) | wc -l)
                if [[ $file_count -gt 1 ]]; then
                    dim4=$file_count
                fi
            fi
        fi
    else
        # If dcmdump is not available, count files
        local file_count=$(find "$dir" -type f \( -name "*.dcm" -o -name "*.IMA" \) | wc -l)
        if [[ $file_count -gt 1 ]]; then
            dim4=$file_count
        fi
    fi
    
    echo $dim4
}

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
        *"MPRAGE"*|*"T1W"*|*"T1"*|*"3D_T1"*|*"IR-FSPGR"*|*"BRAVO"*|*"SAG"*|*"SPGR"*)
            echo "T1w"
            ;;
        
        # T2w patterns - Siemens & GE
        *"T2W"*|*"T2"*|*"T2_TSE"*|*"SPC_T2"*|*"FLAIR"*|*"CUBE"*|*"T2FLAIR"*)
            echo "T2w"
            ;;
        
        # Resting-state fMRI patterns
        *"REST"*|*"RESTING"*|*"RESTING_STATE"*|*"RS_MB"*|*"RESTING_STATE_FMRI"*|*"FMRI_RESTING"*)
            if [[ $dim4 -gt 100 ]]; then
                echo "func_rest"
            else
                echo "unknown"
            fi
            ;;
        
        # DWI patterns
        *"DWI"*|*"DTI"*|*"DIFF"*|*"EP2D_DIFF"*|*"DTI_30"*|*"TENSOR"*|*"DTI_MPG"*|*"DTIMPG"*)
            if [[ $dim4 -gt 5 ]]; then
                echo "dwi"
            else
                echo "unknown"
            fi
            ;;
        
        # Fieldmap patterns
        *"FIELD"*|*"FIELD_MAP"*|*"FIELD_MAPPING"*|*"2D-FIELD_MAP"*)
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

echo "Analyzing DICOM structure for study: $study_name"
echo ""

# Clear and create series list
> "$series_list"

# Process each directory and create series list
while IFS= read -r dir; do
    series_name=$(basename "$dir")
    # Get dim4 from DICOM files
    dim4=$(get_dim4_from_dicom "$dir")
    sequence_type=$(detect_sequence_type "$series_name" "$dim4")
    echo "$series_name|$sequence_type|$dim4" >> "$series_list"
done < <(find "$study_name/DICOM/sorted" -mindepth 2 -maxdepth 2 -type d)

# Check if series list was created successfully
if [[ ! -s "$series_list" ]]; then
    echo "Error: No series found in DICOM/sorted/"
    exit 1
fi

echo "Found sequences in study '$study_name':"
echo "----------------------------------------"
while IFS='|' read -r series_name seq_type dim4; do
    printf "%-30s -> %-15s (volumes: %s)\n" "$series_name" "$seq_type" "$dim4"
done < "$series_list"
echo ""

# Generate heuristic.py
echo "Generating heuristic file: code/heuristic_${study_name}.py"

# Generate header and fixed parts
cat > "$template_file" << EOF
# heuristic.py for study: ${study_name}
# Generated by bh04_make_heuristic.sh on $(date +%Y-%m-%d)
# Please review and modify as needed for your specific study

import os

def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return template, outtype, annotation_classes

def infotodict(seqinfo):
    """Heuristic evaluator for determining which runs belong where
    
    This function maps DICOM series to BIDS file naming conventions
    for study: ${study_name}

    allowed template fields - follow python string module:

    item: index within category
    subject: participant id
    seqitem: run number during scanning
    subindex: sub index within group
    """

    ##### BIDS templates for study: ${study_name} ############
EOF

# Add key definitions based on whether session is used
if grep -q "{session}" "$study_name/tmp/subjlist_${study_name}.tsv"; then
    cat >> "$template_file" << 'KEYS_WITH_SESSION'
    
    # Anatomical scans
    t1w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T1w')
    #t2w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T2w')

    # Functional scans
    func_rest = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_run-{item:02d}_bold')
    #func_rest_PA = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_dir-PA_task-rest_run-{item:02d}_bold')
    #func_rest_AP = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_dir-AP_task-rest_run-{item:02d}_bold')

    # Diffusion scans
    dwi = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_run-{item:02d}_dwi')
    #dwi_PA = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-PA_run-{item:02d}_dwi')
    #dwi_AP = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-AP_run-{item:02d}_dwi')

    # Fieldmaps
    fmap_mag = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_magnitude')
    fmap_phase = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_phasediff')
    #fmap_PA = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-PA_fieldmap')
    #fmap_AP = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-AP_fieldmap')
KEYS_WITH_SESSION
else
    cat >> "$template_file" << 'KEYS_WITHOUT_SESSION'
    
    # Anatomical scans
    t1w = create_key('sub-{subject}/anat/sub-{subject}_run-{item:02d}_T1w')
    #t2w = create_key('sub-{subject}/anat/sub-{subject}_run-{item:02d}_T2w')

    # Functional scans
    func_rest = create_key('sub-{subject}/func/sub-{subject}_task-rest_run-{item:02d}_bold')
    #func_rest_PA = create_key('sub-{subject}/func/sub-{subject}_dir-PA_task-rest_run-{item:02d}_bold')
    #func_rest_AP = create_key('sub-{subject}/func/sub-{subject}_dir-AP_task-rest_run-{item:02d}_bold')

    # Diffusion scans
    dwi = create_key('sub-{subject}/dwi/sub-{subject}_run-{item:02d}_dwi')
    #dwi_PA = create_key('sub-{subject}/dwi/sub-{subject}_dir-PA_run-{item:02d}_dwi')
    #dwi_AP = create_key('sub-{subject}/dwi/sub-{subject}_dir-AP_run-{item:02d}_dwi')

    # Fieldmaps
    fmap_mag = create_key('sub-{subject}/fmap/sub-{subject}_magnitude')
    fmap_phase = create_key('sub-{subject}/fmap/sub-{subject}_phasediff')
KEYS_WITHOUT_SESSION
fi

# Add info dictionary initialization and seqinfo documentation
cat >> "$template_file" << 'COMMON'

    # Initialize dictionary to collect series
    info = {t1w: [], func_rest: [], dwi: [], fmap_mag: [], fmap_phase: []}

    ############################################################################
    # Series identification rules for this study
    ############################################################################

    for idx, s in enumerate(seqinfo):
        """
        The namedtuple `s` contains the following fields:
        * total_files_till_now, example_dcm_file, series_id, dcm_dir_name
        * dim1, dim2, dim3, dim4, TR, TE, protocol_name
        * is_motion_corrected, is_derived, patient_id, study_description
        * referring_physician_name, series_description, image_type
        """

COMMON

# Add sequence matching rules
echo "        # Sequence matching rules based on your study's DICOM structure" >> "$template_file"
echo "" >> "$template_file"

# Create temporary file to track processed conditions (for old bash compatibility)
conditions_file="$study_name/tmp/conditions_added.txt"
> "$conditions_file"

while IFS='|' read -r dirname seqtype dim4; do
    series_desc=${dirname#[0-9]*_}  # Remove series number
    case $seqtype in
        "T1w")
            condition_key="T1w_${series_desc}"
            if ! grep -q "^${condition_key}$" "$conditions_file" 2>/dev/null; then
                echo "        # T1-weighted: $series_desc" >> "$template_file"
                echo "        if '${series_desc}' in s.dcm_dir_name:" >> "$template_file"
                echo "            info[t1w].append(s.series_id)" >> "$template_file"
                echo >> "$template_file"
                echo "$condition_key" >> "$conditions_file"
            fi
            ;;
        "func_rest")
            condition_key="func_rest_${series_desc}"
            if ! grep -q "^${condition_key}$" "$conditions_file" 2>/dev/null; then
                echo "        # Resting-state fMRI: $series_desc" >> "$template_file"
                echo "        if '${series_desc}' in s.dcm_dir_name:" >> "$template_file"
                echo "            info[func_rest].append(s.series_id)" >> "$template_file"
                echo >> "$template_file"
                echo "$condition_key" >> "$conditions_file"
            fi
            ;;
        "dwi")
            condition_key="dwi_${series_desc}"
            if ! grep -q "^${condition_key}$" "$conditions_file" 2>/dev/null; then
                echo "        # Diffusion-weighted: $series_desc" >> "$template_file"
                echo "        if '${series_desc}' in s.dcm_dir_name:" >> "$template_file"
                echo "            info[dwi].append(s.series_id)" >> "$template_file"
                echo >> "$template_file"
                echo "$condition_key" >> "$conditions_file"
            fi
            ;;
        "fieldmap_siemens")
            condition_key="fieldmap_siemens_${series_desc}"
            if ! grep -q "^${condition_key}$" "$conditions_file" 2>/dev/null; then
                echo "        # Fieldmap (magnitude and phasediff: Siemens): $series_desc" >> "$template_file"
                echo "        if '${series_desc}' in s.dcm_dir_name and 'M' in s.image_type:" >> "$template_file"
                echo "            info[fmap_mag].append(s.series_id)" >> "$template_file"
                echo "        if '${series_desc}' in s.dcm_dir_name and 'P' in s.image_type:" >> "$template_file"
                echo "            info[fmap_phase].append(s.series_id)" >> "$template_file"
                echo >> "$template_file"
                echo "$condition_key" >> "$conditions_file"
            fi
            ;;
        "fieldmap_ge")
            condition_key="fieldmap_ge_${series_desc}"
            if ! grep -q "^${condition_key}$" "$conditions_file" 2>/dev/null; then
                echo "        # Fieldmap (magnitude and field: GE): $series_desc" >> "$template_file"
                echo "        if '${series_desc}' in s.dcm_dir_name:" >> "$template_file"
                echo "            # GE fieldmaps need special handling - review and adjust" >> "$template_file"
                echo "            info[fmap_mag].append(s.series_id)" >> "$template_file"
                echo >> "$template_file"
                echo "$condition_key" >> "$conditions_file"
            fi
            ;;
    esac
done < "$series_list"

# Add return statement and IntendedFor
cat >> "$template_file" << EOF

    return info

# Automatic IntendedFor field population
POPULATE_INTENDED_FOR_OPTS = {
    'matching_parameters': ['ImagingVolume', 'Shims'],
    'criterion': 'Closest'
}
EOF

echo ""
echo "Heuristic file created successfully!"
echo ""
echo "File: $study_name/code/heuristic_${study_name}.py"
echo ""
echo "Next steps:"
echo "1. Review the generated heuristic file"
echo "2. Modify sequence matching rules if needed"
echo "3. Run BIDS conversion: bh05_make_bids.sh $study_name"
echo ""
echo "Note: The heuristic file may need manual adjustments for:"
echo "  - Complex sequence naming patterns"
echo "  - Multiple phase encoding directions"
echo "  - Multi-echo sequences"

# Cleanup
rm -f "$series_list" "$study_name/tmp/conditions_added.txt"

exit 0
