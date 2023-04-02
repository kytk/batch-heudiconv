#!/bin/bash

# script to execute heudiconv
# Usage: batch_heudiconv1 heuristic.py subjlist
# Please see heuristic_template.py and subjlist.sample.txt
# to prepare the files

# Prerequisites: install dcm2niix and heudiconv

# Dicom must be sorted beforehand using dcm_sort_dir.py

# K. Nemoto 08 Jan 2023

set -x

# assign heuristic.py to $heuristic and subjlist.txt to $subjlist
heuristic=$1
subjlist=$2

# Make sure you specify a heuristic.py for the first argument
heuext=${heuristic##*.}
if [[ $heuext != 'py' ]]; then
  echo "Please specify heuristics.py first"
  echo "Usage: $0 heuristics.py subjlist.txt"
  exit 1
fi

# Run heudiconv
# remove blank line beforehand using sed '/^$/d'
tail +7 ${subjlist} | sed '/^$/d' | while read dname subj session
do
  heudiconv -d DICOM/sorted/${dname}/*/* \
	-o Nifti -f ${heuristic} \
	-s ${subj} -ss ${session} \
	-c dcm2niix -b --overwrite \
        --dcmconfig code/merge.json
done

