#!/bin/bash

# preparation script for batch-heudiconv

# Specify the path of batch_heudiconv.sh
batchpath=$(dirname $(command -v batch_heudiconv.sh))

# prepare working directory
[[ -d workingDir ]] || mkdir workingDir

cd workingDir

# prepare DICOM/original directory
[[ -d DICOM/original ]] || mkdir -p DICOM/original

# copy "code" and subjlist.sample.txt
cp -r ${batchpath}/code .
cp ${batchpath}/subjlist*txt .

echo "Preparation is done."

exit


