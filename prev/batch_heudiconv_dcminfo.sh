#!/bin/bash

# script to execute heudiconv
# Usage: batch_heudiconv_dcminfo.sh subjlist
# Please see heuristic_template.py and subjlist.sample.txt
# to prepare the files

# Prerequisites: install dcm2niix and heudiconv

# Dicom must be sorted beforehand using dcm_sort_dir.py

# K. Nemoto 04 Apr 2023

set -x

# assign subjlist.txt to $subjlist
subjlist=$1

# Make sure you specify a heuristic.py for the first argument
heuext=${heuristic##*.}
if [[ $# -lt 1 ]]; then
  echo "Please specify subjlist.txt"
  echo "Usage: $0 subjlist.txt"
  exit 1
fi

# delete previous .heudiconv
[[ -d Nifti/.heudiconv ]] && rm -rf Nifti/.heudiconv 

# Run heudiconv
# remove blank line beforehand using sed '/^$/d'
tail +7 ${subjlist} | sed '/^$/d' | while read dname subj session
do
  heudiconv -d DICOM/sorted/${dname}/*/* \
	-o Nifti -f convertall \
	-s ${subj} -ss ${session} \
	-c none -b --overwrite 
done

# change permission
find Nifti -type d -exec chmod 755 {} \;
find Nifti -type f -exec chmod 644 {} \;


