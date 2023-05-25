#!/bin/bash

# script to execute heudiconv for datasets with various fieldmaps

# Usage: batch_heudiconv_fmap.sh heuristic.py subjlist
# Please see heuristic_template.py and subjlist.sample.txt
# to prepare the files

# 25 May 2023 K. Nemoto


set -x

### number of slices of field mapping image ###
# Adjust with your dataset
fmap_slices=39
fmapthr=$((fmap_slices * 2))
###


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
  ndirs=$(find DICOM/sorted/${subj}_${session} -type d -name '*field_mapping*' | wc -l)
  nfiles=$(find DICOM/sorted/${subj}_${session} -type f -name '*field_mapping*' | wc -l)
  if [[ $ndirs -eq 2 ]] && [[ $nfiles -le ${fmapthr} ]]; then
    heudiconv -d DICOM/sorted/${dname}/*/*.dcm \
	-o Nifti -f ${heuristic} \
	-s ${subj} -ss ${session} \
	-c dcm2niix -b --overwrite \
	--dcmconfig code/merge.json

  else
    heudiconv -d DICOM/sorted/${dname}/*/*.dcm \
	-o Nifti -f ${heuristic} \
	-s ${subj} -ss ${session} \
	-c dcm2niix -b --overwrite 
  fi
done

# change permission
find Nifti -type d -exec chmod 755 {} \;
find Nifti -type f -exec chmod 644 {} \;

