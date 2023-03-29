#!/bin/bash

# Script to sort DICOM files using dcm_sort_dir.py
# Usage: dcm_sort_dir_batch.sh <ID(s)>
# Wild card can be used.

# 25 Feb 2023 K. Nemoto

# Check arguments
if [[ $# -lt 1 ]]; then
  echo "Please specify ID(s)!"
  echo "Usage: $0 <ID(s)>"
  echo "Wild card can be used."
  exit 1
fi

for dir in "$@"
do
  dcm_sort_dir.py $dir
done

