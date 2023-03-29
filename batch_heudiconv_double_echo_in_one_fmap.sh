#!/bin/bash

# script to execute heudiconv for double-echo fieldmap in a special case
# This will generate a magnitude nifti image

# Usage: batch_heudiconv2 heuristic.py subjlist
# Please see heuristic_template.py and subjlist.sample.txt
# to prepare the files

# batch_heudiconv1.sh must be executed befor running this script

# K. Nemoto 08 Jan 2023


set -x

# assign heuristic.py to $heuristic and subjlist.txt to $subjlist
heuristic=$1
subjlist=$2

# Make sure you specify a heuristic.py for the first argument
heuext=${heuristic##*.}
if [[ $heuext != 'py' ]]; then
  echo "Please specify heuristic.py first"
  echo "Usage: $0 heuristics.py subjlist.txt"
  exit 1
fi

# Run heudiconv
# remove blank line beforehand using sed '/^$/d'
tail +7 ${subjlist} | sed '/^$/d' | while read dname subj session
do
  heudiconv -d DICOM/sorted/${dname}/*/*.dcm \
	-o Nifti -f ${heuristic} \
	-s ${subj} -ss ${session} \
	-c dcm2niix -b --overwrite \
        --dcmconfig code/merge.json
done

