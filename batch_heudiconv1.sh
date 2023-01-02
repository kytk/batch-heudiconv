#!/bin/bash

# script to execute heudiconv
# Usage: batch_heudiconv1 heuristic.py subjlist
# Please see heuristic_template.py and subjlist_template.txt
# to prepare the files

# Prerequisites: install dcm2niix and heudiconv

# Dicom must be sorted beforehand using dcm_sort_dir.py

# K. Nemoto 02 Jan 2023


heuristics=$1
subjlist=$2

tail +7 ${subjlist} | while read dname subj session
do
  heudiconv -d DICOM/sorted/${dname}/*/*.dcm \
	-o Nifti -f ${heuristics} \
	-s ${subj} -ss ${session} \
	-c dcm2niix -b --overwrite 
done

