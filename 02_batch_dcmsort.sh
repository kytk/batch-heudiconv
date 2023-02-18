#!/bin/bash

cd workingDir/DICOM/original
for dir in *
do
  dcm_sort_dir.py $dir
done

tree workingDir/DICOM/sort -d

exit

