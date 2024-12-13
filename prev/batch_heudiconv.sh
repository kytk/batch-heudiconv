#!/bin/bash

# script to execute heudiconv
# Usage: batch_heudiconv.sh heuristic.py subjlist
# Please see heuristic_template.py and subjlist.sample.txt
# to prepare the files

# Prerequisites: install dcm2niix and heudiconv

# Dicom must be sorted beforehand using dcm_sort_dir.py

# K. Nemoto 04 Apr 2023

set -x

# assign heuristic.py to $heuristic and subjlist.txt to $subjlist
heuristic=$1
subjlist=$2

# Make sure you specify a heuristic.py for the first argument
heuext=${heuristic##*.}
if [[ $heuext != 'py' ]]; then
  echo "Please specify heuristic.py first"
  echo "Usage: $0 heuristic.py subjlist.txt"
  exit 1
fi

# delete previous .heudiconv
[[ -d Nifti/.heudiconv ]] && rm -rf Nifti/.heudiconv 

# Run heudiconv
# remove blank line beforehand using sed '/^$/d'
tail +7 ${subjlist} | sed '/^$/d' | while read dname subj session
do
  heudiconv -d DICOM/sorted/${dname}/*/* \
	-o Nifti -f ${heuristic} \
	-s ${subj} -ss ${session} \
	-c dcm2niix -b --overwrite 
done

# change permission
find Nifti -type d -exec chmod 755 {} \;
find Nifti -type f -exec chmod 644 {} \;


