#!/bin/bash

# script to execute heudiconv for double-echo fieldmap
# This will generate a magnitude nifti image

# Usage: batch_heudiconv2 heuristic.py subjlist
# Please see heuristic_template.py and subjlist_template.txt
# to prepare the files

# batch_heudiconv1.sh must be executed befor running this script

# K. Nemoto 02 Jan 2023


heuristics=$1
subjlist=$2

tail +7 subjlist.txt | while read dname subj session
do
  heudiconv -d DICOM/sorted/${dname}/*/*.dcm \
	-o Nifti -f ${heuristics} \
	-s ${subj} -ss ${session} \
	-c dcm2niix -b --overwrite \
        --dcmconfig code/merge.json
done
    
