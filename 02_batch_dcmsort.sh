#!/bin/bash
# Script to sort DICOM using dcm_sort_dir.py in batch
# 23 Feb 2023 K.Nemoto

# Prerequisite
# Please place your DICOM directories under DICOM/original
# sorted directories will be DICOM/sorted

# Acquire parntDir where workingDir exists
cwd=$(dirname $PWD)
parentDir=$(echo ${cwd%workingDir*})
if [[ $? -ne 0 ]]; then
  echo "You are not in the right directory."
  echo "Please run this script where you executed 01_prep_heudiconv.sh"
  exit 1
fi

# cd DICOM/original
cd ${parentDir}/workingDir/DICOM/original

# Sort DICOMs
for dir in $(ls -F | grep /)
do
  dcm_sort_dir.py $dir
done

tree ${parentDir}/workingDir/DICOM/sorted -d

exit

