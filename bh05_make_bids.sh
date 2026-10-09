#!/bin/bash
# Script to convert DICOM to BIDS using heudiconv
# Run this script after bh04_make_heuristic.sh
# Prerequisites: dcm2niix and heudiconv
# K.Nemoto 09 Oct 2026

# For debugging
#set -x

usage() {
    echo "Convert sorted DICOM files to BIDS format for your study"
    echo "Usage: $0 <study_name> [--merge]"
    echo ""
    echo "Options:"
    echo "  --merge    Create code/merge.json ({\"merge_imgs\": true}) for double-echo"
    echo "             fieldmaps whose two echoes must be merged by dcm2niix"
    echo ""
    echo "If <study_name>/code/merge.json exists, it is passed to heudiconv"
    echo "(--dcmconfig) for all subjects."
    echo ""
    echo "Prerequisites:"
    echo "  - Study setup completed with previous bh0X scripts"
    echo "  - Sorted DICOM files in: <study_name>/DICOM/sorted/"
    echo "  - Subject list: <study_name>/tmp/subjlist_<study_name>.tsv"
    echo "  - Heuristic file: <study_name>/code/heuristic_<study_name>.py"
    echo ""
    echo "This script will:"
    echo "1. Convert DICOM to BIDS format using heudiconv"
    echo "2. Populate IntendedFor of fieldmaps (via POPULATE_INTENDED_FOR_OPTS in heuristic)"
    echo "3. Move DICOM files of successfully converted subjects to DICOM/converted/"
    echo "4. Check IntendedFor fields of fieldmaps"
    echo ""
    echo "Output: <study_name>/bids/rawdata/ (BIDS dataset)"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

# Parameters
study_name=${1%/}
shift
create_merge=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --merge) create_merge=1 ;;
        *) echo "Error: Unknown option: $1"; echo ""; usage ;;
    esac
    shift
done
merge_config="code/merge.json"
heuristic="code/heuristic_${study_name}.py"
subjlist="tmp/subjlist_${study_name}.tsv"
logdir="tmp/logs"

# Check required commands
for cmd in heudiconv dcm2niix python3; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "Error: '$cmd' not found in PATH"
        exit 1
    fi
done

# Check if study directory exists
if [[ ! -d "$study_name" ]]; then
    echo "Error: Study directory '$study_name' does not exist"
    echo "Please run: bh01_prep_dir.sh $study_name"
    exit 1
fi

cd "$study_name" || exit 1

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

# Check IntendedFor settings in heuristic
# (lines starting with '#' are ignored)
if ! grep -q '^[[:space:]]*POPULATE_INTENDED_FOR_OPTS' "$heuristic"; then
    if grep -v '^[[:space:]]*#' "$heuristic" | grep -q "create_key(.*/fmap/"; then
        echo "Warning: POPULATE_INTENDED_FOR_OPTS is not defined in $heuristic"
        echo "         IntendedFor of fieldmaps will not be populated"
        echo ""
    fi
elif grep -v '^[[:space:]]*#' "$heuristic" | grep -q "ModalityAcquisitionLabel"; then
    # ModalityAcquisitionLabel requires acq-<func|dwi|anat> in every fmap key
    no_acq=$(grep -v '^[[:space:]]*#' "$heuristic" | grep "create_key(.*/fmap/" | grep -v "_acq-")
    if [[ -n "$no_acq" ]]; then
        echo "Error: ModalityAcquisitionLabel is used, but some fmap keys have no acq- label:"
        echo "$no_acq" | sed 's/^[[:space:]]*/  /'
        echo "Add acq-func, acq-dwi, or acq-anat to these keys (e.g. ..._acq-func_phasediff)"
        exit 1
    fi
fi

# dcm2niix configuration (e.g. merging double-echo fieldmaps)
if [[ $create_merge -eq 1 && ! -f $merge_config ]]; then
    echo '{"merge_imgs": true}' > "$merge_config"
    echo "Created $merge_config"
fi
dcmconfig_opt=()
if [[ -f $merge_config ]]; then
    dcmconfig_opt=(--dcmconfig "$merge_config")
fi

# Extract pattern from subject list file
pattern=$(grep '^# pattern:' "$subjlist" | sed 's/^# pattern: //')
if [[ -z "$pattern" ]]; then
    echo "Warning: Pattern not found in subject list file"
    echo "Using default pattern: {subject}"
    pattern="{subject}"
fi

echo "Pattern detected from subject list: $pattern"

mkdir -p "$logdir"

# Process subjects
echo "Starting BIDS conversion for study: $study_name"
echo "Using heuristic: $heuristic"
echo "Using pattern: $pattern"
if [[ ${#dcmconfig_opt[@]} -gt 0 ]]; then
    echo "Using dcm2niix config: $merge_config ($(tr -d '\n' < "$merge_config"))"
fi
echo "Logs: $study_name/$logdir/"
echo ""

# Subject list without comment, header, and empty lines
subjects=$(grep -v '^#' "$subjlist" | tail -n +2 | grep -v '^[[:space:]]*$')
total_subjects=$(echo -n "$subjects" | grep -c '^')
current_subject=0
succeeded=()
failed=()

while IFS=$'\t' read -r dirpattern subject session
do
    current_subject=$((current_subject + 1))
    echo "[$current_subject/$total_subjects] Processing: Subject=$subject Session=$session (Directory: $dirpattern)"

    # Remove cached heudiconv info for this subject/session
    # so that changes in the heuristic are always applied
    rm -rf "bids/rawdata/.heudiconv/${subject}/ses-${session}"

    logfile="${logdir}/heudiconv_${subject}_${session}.log"
    echo "  Using DICOM pattern: DICOM/sorted/${pattern}/*/*"
    echo "  Running heudiconv... (log: $logfile)"

    # heudiconv expands the pattern by itself, so keep it quoted
    # stdin is redirected not to consume the subject list
    heudiconv -d "DICOM/sorted/${pattern}/*/*" \
              -o bids/rawdata \
              -f "$heuristic" \
              -s "$subject" \
              -ss "$session" \
              -c dcm2niix \
              "${dcmconfig_opt[@]}" \
              -b \
              --overwrite \
              < /dev/null > "$logfile" 2>&1

    if [[ $? -ne 0 ]]; then
        echo "  ✗ heudiconv reported an error for subject $subject session $session"
        tail -n 5 "$logfile" | sed 's/^/    /'
        failed+=("$dirpattern")
    else
        echo "  ✓ Successfully processed subject $subject"
        succeeded+=("$dirpattern")
    fi
    echo ""
done <<< "$subjects"

# Remove events.tsv stubs generated by heudiconv for resting-state runs
# (only untouched stubs are removed)
events_stub=$'onset\tduration\ttrial_type\tresponse_time\tstim_file\tTODO -- fill in rows and add more tab-separated columns if desired'
while IFS= read -r -d '' events_file; do
    if [[ "$(cat "$events_file")" == "$events_stub" ]]; then
        rm -f "$events_file"
        echo "Removed events.tsv stub: ${events_file#bids/rawdata/}"
    fi
done < <(find bids/rawdata -path '*/func/*task-rest*_events.tsv' -print0 2>/dev/null)

# Set appropriate permissions
echo "Setting file permissions..."
chmod -R u=rwX,go=rX bids/rawdata 2>/dev/null

# Backup DICOM files of successfully converted subjects
# DICOM files of failed subjects are left in DICOM/sorted and DICOM/original
echo "Backing up DICOM files..."
timestamp=$(date +%Y%m%d-%H%M%S)
for dirpattern in "${succeeded[@]}"; do
    for src in sorted original; do
        [[ -d "DICOM/${src}/${dirpattern}" ]] || continue
        dest="DICOM/converted/${src}/${dirpattern}"
        mkdir -p "DICOM/converted/${src}"
        # Do not overwrite previous backup
        if [[ -e "$dest" ]]; then
            dest="${dest}_${timestamp}"
            echo "  Previous backup exists; saving as $dest"
        fi
        mv "DICOM/${src}/${dirpattern}" "$dest"
    done
done

# Keep empty directories for future use
mkdir -p DICOM/sorted DICOM/original

# Check IntendedFor of fieldmaps
echo ""
echo "Checking IntendedFor fields of fieldmaps..."
python3 - bids/rawdata << 'PYEOF'
import glob
import json
import os
import sys

bids_dir = sys.argv[1]
n_fmap = 0
problems = []
for fmap_json in sorted(glob.glob(os.path.join(bids_dir, 'sub-*', '**', 'fmap', '*.json'),
                                  recursive=True)):
    n_fmap += 1
    rel = os.path.relpath(fmap_json, bids_dir)
    subj_dir = os.path.join(bids_dir, rel.split(os.sep)[0])
    try:
        with open(fmap_json) as f:
            intended_for = json.load(f).get('IntendedFor')
    except Exception as e:
        problems.append(f'{rel}: cannot read ({e})')
        continue
    if not intended_for:
        problems.append(f'{rel}: IntendedFor is missing or empty')
        continue
    if isinstance(intended_for, str):
        intended_for = [intended_for]
    for target in intended_for:
        # BIDS URI is relative to the dataset root; otherwise relative to subject
        if target.startswith('bids::'):
            path = os.path.join(bids_dir, target[len('bids::'):])
        else:
            path = os.path.join(subj_dir, target)
        if not os.path.exists(path):
            problems.append(f'{rel}: target not found: {target}')

if n_fmap == 0:
    print('  No fieldmaps found')
elif problems:
    print(f'  Warning: {len(problems)} issue(s) found in {n_fmap} fieldmap JSON files')
    for p in problems:
        print(f'    - {p}')
    print('  Fix the fmap keys / POPULATE_INTENDED_FOR_OPTS in the heuristic and re-run,')
    print('  or re-populate without conversion:')
    print('    heudiconv --command populate-intended-for -o bids/rawdata -f <heuristic> [-s <ID> -ss <ID>]')
else:
    print(f'  ✓ IntendedFor is set in all {n_fmap} fieldmap JSON files')
PYEOF

echo ""
echo "============================================"
echo "BIDS conversion completed for study: $study_name"
echo "============================================"
echo ""
echo "Results:"
echo "  - BIDS dataset: $study_name/bids/rawdata/"
echo "  - Succeeded: ${#succeeded[@]} / $total_subjects"
echo "  - Failed:    ${#failed[@]} / $total_subjects"
for dirpattern in "${failed[@]}"; do
    echo "      $dirpattern (DICOM left in DICOM/sorted/)"
done
echo "  - Pattern used: $pattern"
echo "  - DICOM backup: $study_name/DICOM/converted/"
echo "  - Logs: $study_name/$logdir/"
echo ""
echo "Next steps:"
echo "1. Validate BIDS dataset: https://bids-standard.github.io/bids-validator/"
echo "2. Review conversion logs for any warnings"
echo "3. Check dataset_description.json and README files"
echo ""
echo "Optional post-processing:"
echo "  - Reorganize GE fieldmaps: bh_reorganize_fieldmaps.py $study_name"

if [[ ${#failed[@]} -gt 0 ]]; then
    exit 1
fi
exit 0
