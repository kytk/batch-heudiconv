#!/bin/bash
# script to create heuristic.py for BIDS conversion of neuroimaging data
# Designed to handle both standard Siemens/GE sequences and 
# multiband acquisitions
# K.Nemoto 06 May 2025

# For debugging
#set -x

usage() {
    echo "Create neuroimaging-specific heuristic.py by analyzing DICOM directory structure"
    echo "Usage: $0 <setname> [scanner_type]"
    echo
    echo "Parameters:"
    echo "  setname      : Name of the sequence set"
    echo "  scanner_type : Optional - specify 'siemens' or 'ge' (default: auto-detect)"
    echo
    echo "This script will:"
    echo "1. Analyze your neuroimaging DICOM directory structure"
    echo "2. Identify sequence types (T1w, T2w, fMRI, DWI, fieldmaps)"
    echo "3. Generate a customized heuristic.py file for BIDS conversion"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

setname=${1%/}
scanner_type=${2:-"auto"}

# Check prerequisites
if [[ ! -d $setname/DICOM/sorted ]]; then
    echo "Error: Sorted DICOM directory not found"
    echo "Please run bh02_sort_dicom.sh first"
    exit 1
fi

if [[ ! -f $setname/tmp/subjlist_${setname}.tsv ]]; then
    echo "Error: Subject list not found"
    echo "Please run bh03_make_subjlist.sh first"
    exit 1
fi

# Create temporary files
mkdir -p "$setname/tmp"
mkdir -p "$setname/code"
series_list="$setname/tmp/series_list.txt"
template_file="$setname/code/heuristic_${setname}.py"

# Clear and create series list
> "$series_list"

echo "Scanning directory structure in $setname/DICOM/sorted..."

# Extract sequence patterns from directory names
seq_dirs=$(find "$setname/DICOM/sorted" -mindepth 2 -maxdepth 2 -type d)

# Auto-detect scanner type if not specified
if [[ "$scanner_type" == "auto" ]]; then
    if grep -q "GRE-EPI" <<< "$seq_dirs" || grep -q "SPGR" <<< "$seq_dirs"; then
        scanner_type="ge"
        echo "Auto-detected GE scanner"
    else
        scanner_type="siemens"
        echo "Auto-detected Siemens scanner (default)"
    fi
fi

# Process sequence directories to identify patterns
echo "Analyzing sequence directories..."

# Function to extract sequence details
analyze_sequence_dir() {
    local dir_path="$1"
    local dirname=$(basename "$dir_path")
    
    # Extract sequence name, removing any numbering suffixes
    local series_desc=$(echo "$dirname" | sed -E 's/_[0-9]+$|^[0-9]+_//')
    
    # Skip scout, localizer, and derived images
    if [[ "$series_desc" =~ (Scout|scout|Localizer|localizer|MPR_|setup|TRACEW|FA$|ColFA) ]]; then
        echo "$dirname|SKIP|0" >> "$series_list"
        return
    fi
    
    # Set defaults
    local seq_type="unknown"
    local direction="none"
    local is_sbref="no"
    local dim4=1
    
    # Extract phase encoding direction (AP/PA) if present
    if [[ "$series_desc" =~ _AP ]]; then
        direction="AP"
    elif [[ "$series_desc" =~ _PA ]]; then
        direction="PA"
    fi
    
    # Detect single-band reference images if present
    if [[ "$series_desc" =~ SBRef ]]; then
        is_sbref="yes"
    fi
    
    # Categorize by sequence type
    if [[ "$series_desc" =~ (^|_)T1(_|$) || "$series_desc" =~ T1_MPR || "$series_desc" =~ MPRAGE ]]; then
        seq_type="T1w"
    elif [[ "$series_desc" =~ (^|_)T2(_|$) || "$series_desc" =~ T2_SPC ]]; then
        seq_type="T2w"
    elif [[ "$series_desc" =~ BOLD || "$series_desc" =~ REST || "$series_desc" =~ Resting_State ]]; then
        seq_type="func_rest"
        dim4=200  # Typical length for resting state
    elif [[ "$series_desc" =~ DWI || "$series_desc" =~ DTI || "$series_desc" =~ diff_30dir ]]; then
        seq_type="dwi"
        dim4=30  # Typical DWI volume count
    elif [[ "$series_desc" =~ SEField || "$series_desc" =~ field_map || "$series_desc" =~ Field_mapping ]]; then
        # Check if using standard fieldmap or spin-echo fieldmap format
        if [[ "$series_desc" =~ SEField ]]; then
            seq_type="fieldmap_spinecho"
        else
            seq_type="fieldmap_standard"
        fi
    fi
    
    # Output formatted entry
    echo "$dirname|$seq_type|$direction|$is_sbref|$dim4" >> "$series_list"
    echo "  Analyzed: $dirname -> Type: $seq_type, Direction: $direction, SBRef: $is_sbref"
}

# Process each directory
for dir in $seq_dirs; do
    analyze_sequence_dir "$dir"
done

# Determine if session is used
use_session=false
if grep -q "{session}" "$setname/tmp/subjlist_${setname}.tsv"; then
    use_session=true
    echo "Detected session structure in subject list"
fi

# Check if we have multiband EPI or standard acquisitions
has_multiband=false
if grep -q "func_rest|AP\|PA" "$series_list" || grep -q "dwi|AP\|PA" "$series_list"; then
    has_multiband=true
    echo "Detected multiband acquisition with phase encoding directions"
fi

# Check if we have standard fieldmaps or spin-echo fieldmaps
has_standard_fieldmap=false
has_spinecho_fieldmap=false
if grep -q "fieldmap_standard" "$series_list"; then
    has_standard_fieldmap=true
    echo "Detected standard fieldmap acquisition (magnitude/phase)"
fi
if grep -q "fieldmap_spinecho" "$series_list"; then
    has_spinecho_fieldmap=true
    echo "Detected spin-echo fieldmap acquisition (EPI-based)"
fi

# Generate the heuristic file
echo "Generating heuristic.py file..."

# Create header
cat > "$template_file" << EOF
# heuristic.py for ${setname}
# Generated by enhanced bh04_make_heuristic.sh
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

# Create key templates based on session usage and acquisition type
if $use_session; then
    # With session
    if $has_multiband; then
        # Multiband with directions
        cat >> "$template_file" << EOF
    # T1
    t1w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T1w')

    # T2
    t2w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T2w')

    # Resting-state (PA and AP)
    func_rest_PA = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_dir-PA_task-rest_run-{item:02d}_bold')
    func_rest_PA_sbref = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_dir-PA_task-rest_run-{item:02d}_sbref')
    func_rest_AP = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_dir-AP_task-rest_run-{item:02d}_bold')
    func_rest_AP_sbref = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_dir-AP_task-rest_run-{item:02d}_sbref')

    # DWI (PA and AP)
    dwi_PA = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-PA_run-{item:02d}_dwi')
    dwi_PA_sbref = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-PA_run-{item:02d}_sbref')
    dwi_AP = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-AP_run-{item:02d}_dwi')
    dwi_AP_sbref = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-AP_run-{item:02d}_sbref')
EOF
    else
        # Standard acquisition
        cat >> "$template_file" << EOF
    # T1
    t1w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T1w')

    # T2
    #t2w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T2w')

    # Resting-state (only one phase encoding)
    func_rest = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_run-{item:02d}_bold')

    # DWI (only one phase encoding)
    dwi = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_run-{item:02d}_dwi')
EOF
    fi
else
    # Without session
    if $has_multiband; then
        # Multiband with directions
        cat >> "$template_file" << EOF
    # T1
    t1w = create_key('sub-{subject}/anat/sub-{subject}_run-{item:02d}_T1w')

    # T2
    t2w = create_key('sub-{subject}/anat/sub-{subject}_run-{item:02d}_T2w')

    # Resting-state (PA and AP)
    func_rest_PA = create_key('sub-{subject}/func/sub-{subject}_dir-PA_task-rest_run-{item:02d}_bold')
    func_rest_PA_sbref = create_key('sub-{subject}/func/sub-{subject}_dir-PA_task-rest_run-{item:02d}_sbref')
    func_rest_AP = create_key('sub-{subject}/func/sub-{subject}_dir-AP_task-rest_run-{item:02d}_bold')
    func_rest_AP_sbref = create_key('sub-{subject}/func/sub-{subject}_dir-AP_task-rest_run-{item:02d}_sbref')

    # DWI (PA and AP)
    dwi_PA = create_key('sub-{subject}/dwi/sub-{subject}_dir-PA_run-{item:02d}_dwi')
    dwi_PA_sbref = create_key('sub-{subject}/dwi/sub-{subject}_dir-PA_run-{item:02d}_sbref')
    dwi_AP = create_key('sub-{subject}/dwi/sub-{subject}_dir-AP_run-{item:02d}_dwi')
    dwi_AP_sbref = create_key('sub-{subject}/dwi/sub-{subject}_dir-AP_run-{item:02d}_sbref')
EOF
    else
        # Standard acquisition
        cat >> "$template_file" << EOF
    # T1
    t1w = create_key('sub-{subject}/anat/sub-{subject}_run-{item:02d}_T1w')

    # T2
    #t2w = create_key('sub-{subject}/anat/sub-{subject}_run-{item:02d}_T2w')

    # Resting-state (only one phase encoding)
    func_rest = create_key('sub-{subject}/func/sub-{subject}_task-rest_run-{item:02d}_bold')

    # DWI (only one phase encoding)
    dwi = create_key('sub-{subject}/dwi/sub-{subject}_run-{item:02d}_dwi')
EOF
    fi
fi

# Add fieldmap keys based on detected types
if $has_standard_fieldmap; then
    if $use_session; then
        cat >> "$template_file" << EOF
    # Fieldmap (magnitude and phasediff: Siemens)
    fmap_mag = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_magnitude')
    fmap_phase = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_phasediff')
EOF
    else
        cat >> "$template_file" << EOF
    # Fieldmap (magnitude and phasediff: Siemens)
    fmap_mag = create_key('sub-{subject}/fmap/sub-{subject}_magnitude')
    fmap_phase = create_key('sub-{subject}/fmap/sub-{subject}_phasediff')
EOF
    fi
fi

if $has_spinecho_fieldmap; then
    if $use_session; then
        cat >> "$template_file" << EOF
    # Field map (two phases: Siemens)
    fmap_PA = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_acq-func_dir-PA_run-{item:02d}_epi')
    fmap_AP = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_acq-func_dir-AP_run-{item:02d}_epi')
EOF
    else
        cat >> "$template_file" << EOF
    # Field map (two phases: Siemens)
    fmap_PA = create_key('sub-{subject}/fmap/sub-{subject}_acq-func_dir-PA_run-{item:02d}_epi')
    fmap_AP = create_key('sub-{subject}/fmap/sub-{subject}_acq-func_dir-AP_run-{item:02d}_epi')
EOF
    fi
fi

# Initialize info dictionary based on detected sequence types
cat >> "$template_file" << EOF

EOF

echo -n "    info = {" >> "$template_file"
if $has_multiband; then
    echo -n "t1w: [], t2w: [], func_rest_PA: [], func_rest_PA_sbref: [], func_rest_AP: [], func_rest_AP_sbref: [], dwi_PA: [], dwi_PA_sbref: [], dwi_AP: [], dwi_AP_sbref: []" >> "$template_file"
else
    echo -n "t1w: [], func_rest: [], dwi: []" >> "$template_file"
fi

if $has_standard_fieldmap; then
    echo -n ", fmap_mag: [], fmap_phase: []" >> "$template_file"
fi

if $has_spinecho_fieldmap; then
    echo -n ", fmap_PA: [], fmap_AP: []" >> "$template_file"
fi

echo "}" >> "$template_file"

# Add seqinfo documentation
cat >> "$template_file" << EOF

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

        ### extract keywords from sorted DICOM series-based sub-directories and dimensions ###

EOF

# Generate sequence matching rules based on analyzed directories
if ! $has_multiband; then
    # Standard acquisition style rules
    
    # T1w rules
    grep "|T1w|" "$series_list" | while IFS='|' read -r dirname seq_type direction is_sbref dim4; do
        # Extract only the part after the number (e.g., from "MPRAGE_GRAPPA2_8" to "MPRAGE_GRAPPA2")
        pattern=$(echo "$dirname" | sed -E 's/_[0-9]+$//')
        echo "        # T1w" >> "$template_file"
        echo "        if '$pattern' in s.dcm_dir_name:" >> "$template_file"
        echo "            info[t1w].append(s.series_id)" >> "$template_file"
        echo >> "$template_file"
    done

    # Func rules
    grep "|func_rest|" "$series_list" | while IFS='|' read -r dirname seq_type direction is_sbref dim4; do
        pattern=$(echo "$dirname" | sed -E 's/_[0-9]+$//')
        echo "        # rs-fMRI" >> "$template_file"
        echo "        if '$pattern' in s.dcm_dir_name:" >> "$template_file"
        echo "            info[func_rest].append(s.series_id)" >> "$template_file"
        echo >> "$template_file"
    done

    # Dwi rules
    grep "|dwi|" "$series_list" | while IFS='|' read -r dirname seq_type direction is_sbref dim4; do
        pattern=$(echo "$dirname" | sed -E 's/_[0-9]+$//')
        echo "        # DWI" >> "$template_file"
        echo "        if '$pattern' in s.dcm_dir_name:" >> "$template_file"
        echo "            info[dwi].append(s.series_id)" >> "$template_file"
        echo >> "$template_file"
    done

    # Fieldmap rules for standard acquisition
    if $has_standard_fieldmap; then
        # First field mapping directory
        fieldmap_dir=$(grep "|fieldmap_standard|" "$series_list" | head -n 1 | cut -d'|' -f1)
        pattern=$(echo "$fieldmap_dir" | sed -E 's/_[0-9]+$//')
        
        echo "        # Fieldmap (magnitude and phasediff: Siemens)" >> "$template_file"
        echo "        if '$pattern' in s.dcm_dir_name and 'M' in s.image_type:" >> "$template_file"
        echo "            info[fmap_mag].append(s.series_id)" >> "$template_file"
        echo "        if '$pattern' in s.dcm_dir_name and 'P' in s.image_type:" >> "$template_file"
        echo "            info[fmap_phase].append(s.series_id)" >> "$template_file"
        echo >> "$template_file"
    fi
else
    # Multiband acquisition style rules
    
    # T1w rules
    grep "|T1w|" "$series_list" | while IFS='|' read -r dirname seq_type direction is_sbref dim4; do
        echo "        # T1w" >> "$template_file"
        echo "        if '${dirname#*_}' in s.dcm_dir_name:" >> "$template_file"
        echo "            info[t1w].append(s.series_id)" >> "$template_file"
        echo >> "$template_file"
    done

    # T2w rules
    grep "|T2w|" "$series_list" | while IFS='|' read -r dirname seq_type direction is_sbref dim4; do
        echo "        # T2w" >> "$template_file"
        echo "        if '${dirname#*_}' in s.dcm_dir_name:" >> "$template_file"
        echo "            info[t2w].append(s.series_id)" >> "$template_file"
        echo >> "$template_file"
    done

    # Functional scans with direction
    echo "        # Functional scans - PA direction" >> "$template_file"
    grep "|func_rest|PA|" "$series_list" | while IFS='|' read -r dirname seq_type direction is_sbref dim4; do
        if [[ "$is_sbref" == "yes" ]]; then
            echo "        if ('${dirname#*_}' in s.dcm_dir_name) and ('PA' in s.dcm_dir_name) and ('SBRef' in s.dcm_dir_name):" >> "$template_file"
            echo "            info[func_rest_PA_sbref].append(s.series_id)" >> "$template_file"
        else
            echo "        if ('${dirname#*_}' in s.dcm_dir_name) and ('PA' in s.dcm_dir_name) and (s.dim4 >= 100):" >> "$template_file"
            echo "            info[func_rest_PA].append(s.series_id)" >> "$template_file"
        fi
    done

    echo >> "$template_file"
    echo "        # Functional scans - AP direction" >> "$template_file"
    grep "|func_rest|AP|" "$series_list" | while IFS='|' read -r dirname seq_type direction is_sbref dim4; do
        if [[ "$is_sbref" == "yes" ]]; then
            echo "        if ('${dirname#*_}' in s.dcm_dir_name) and ('AP' in s.dcm_dir_name) and ('SBRef' in s.dcm_dir_name):" >> "$template_file"
            echo "            info[func_rest_AP_sbref].append(s.series_id)" >> "$template_file"
        else
            echo "        if ('${dirname#*_}' in s.dcm_dir_name) and ('AP' in s.dcm_dir_name) and (s.dim4 >= 100):" >> "$template_file"
            echo "            info[func_rest_AP].append(s.series_id)" >> "$template_file"
        fi
    done

    # Diffusion scans with direction
    echo >> "$template_file"
    echo "        # Diffusion scans - PA direction" >> "$template_file"
    grep "|dwi|PA|" "$series_list" | while IFS='|' read -r dirname seq_type direction is_sbref dim4; do
        if [[ "$is_sbref" == "yes" ]]; then
            echo "        if ('${dirname#*_}' in s.dcm_dir_name) and ('PA' in s.dcm_dir_name) and ('SBRef' in s.dcm_dir_name):" >> "$template_file"
            echo "            info[dwi_PA_sbref].append(s.series_id)" >> "$template_file"
        else
            echo "        if ('${dirname#*_}' in s.dcm_dir_name) and ('PA' in s.dcm_dir_name) and (s.dim4 >= 5):" >> "$template_file"
            echo "            info[dwi_PA].append(s.series_id)" >> "$template_file"
        fi
    done

    echo >> "$template_file"
    echo "        # Diffusion scans - AP direction" >> "$template_file"
    grep "|dwi|AP|" "$series_list" | while IFS='|' read -r dirname seq_type direction is_sbref dim4; do
        if [[ "$is_sbref" == "yes" ]]; then
            echo "        if ('${dirname#*_}' in s.dcm_dir_name) and ('AP' in s.dcm_dir_name) and ('SBRef' in s.dcm_dir_name):" >> "$template_file"
            echo "            info[dwi_AP_sbref].append(s.series_id)" >> "$template_file"
        else
            echo "        if ('${dirname#*_}' in s.dcm_dir_name) and ('AP' in s.dcm_dir_name) and (s.dim4 >= 5):" >> "$template_file"
            echo "            info[dwi_AP].append(s.series_id)" >> "$template_file"
        fi
    done

    # Spin-echo fieldmaps
    if $has_spinecho_fieldmap; then
        echo >> "$template_file"
        echo "        # Field maps" >> "$template_file"
        grep "|fieldmap_spinecho|PA|" "$series_list" | while IFS='|' read -r dirname seq_type direction is_sbref dim4; do
            echo "        if ('${dirname#*_}' in s.dcm_dir_name) and ('PA' in s.dcm_dir_name):" >> "$template_file"
            echo "            info[fmap_PA].append(s.series_id)" >> "$template_file"
        done
        
        grep "|fieldmap_spinecho|AP|" "$series_list" | while IFS='|' read -r dirname seq_type direction is_sbref dim4; do
            echo "        if ('${dirname#*_}' in s.dcm_dir_name) and ('AP' in s.dcm_dir_name):" >> "$template_file"
            echo "            info[fmap_AP].append(s.series_id)" >> "$template_file"
        done
    fi
fi

# Add return statement
cat >> "$template_file" << EOF
            
    return info
EOF

echo "Heuristic file created: $template_file"
echo
echo "Please review and edit the file if necessary."
echo "The generated file contains:"
echo "1. Anatomical scan definitions"
echo "2. Functional scans"
echo "3. Diffusion weighted imaging"
echo "4. Fieldmaps"
echo "5. Appropriate handling of phase encoding directions if detected"

# Cleanup
rm -f "$series_list"

exit 0
