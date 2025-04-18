#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# DICOM sorting script using pydicom
# Part of this script is based on the script provided by Yuya Saito
# Prerequisite: pydicom and numpy

# 18 Apr 2025 K. Nemoto

import os
import time
import re
import shutil
import argparse
import pydicom

__version__ = '20250418'

__desc__ = '''
Sort DICOM files.
Please note that the PatientID is assumed from the directory name.
Non-imaging DICOM files will be skipped.
Special handling for GE field map images to separate real, imaginary, phase, and magnitude images.
'''
__epilog__ = '''
examples:
  dcm_sort_dir.py DICOM_DIR [DICOM_DIR ...]
'''

def generate_dest_dir_name(dicom_dataset: pydicom.dataset.FileDataset) -> str:
    series_number = str(dicom_dataset.SeriesNumber).zfill(2)
    series_description = dicom_dataset.SeriesDescription.replace(' ', '_')
    
    # Check if manufacturer is GE and if this is a field map series
    is_ge = False
    if hasattr(dicom_dataset, 'Manufacturer'):
        is_ge = 'GE' in dicom_dataset.Manufacturer.upper()
    
    if is_ge and 'field_map' in series_description.lower():
        # Get tag (0043,102F) for image type
        image_type_tag = (0x0043, 0x102F)
        
        if image_type_tag in dicom_dataset:
            image_type_value = dicom_dataset[image_type_tag].value
            
            # Add suffix based on image type
            if image_type_value == 0:
                series_description += '_0_magnitude'
            elif image_type_value == 1:
                series_description += '_1_phase'
            elif image_type_value == 2:
                series_description += '_2_real'
            elif image_type_value == 3:
                series_description += '_3_imaginary'
    
    rule_text = f'{series_number}_{series_description}'
    return re.sub(r'[(\\/:?*"<>|)]', '', rule_text)

def copy_dicom_files(src_dir: str, sorted_dir: str = '../sorted/') -> None:
    # Strip trailing slashes from the source directory
    src_dir = src_dir.rstrip('/')
    
    if not os.path.exists(sorted_dir):
        os.makedirs(sorted_dir)

    for root, _, files in os.walk(src_dir):
        for file in files:
            src_file = os.path.join(root, file)
            try:
                ds = pydicom.dcmread(src_file)
                if hasattr(ds, 'pixel_array'):
                    dest_dir_name = generate_dest_dir_name(ds)
                    out_dir = os.path.join(sorted_dir, os.path.basename(src_dir))
                    dest_dir = os.path.join(out_dir, dest_dir_name)
                    os.makedirs(dest_dir, exist_ok=True)
                    shutil.copy2(src_file, dest_dir)
                    print(f"Copy {src_file} -> {dest_dir}")
            except Exception as e:
                print(f"Failed to process {src_file}: {e}")

def main() -> int:
    start_time = time.time()
    parser = argparse.ArgumentParser(description=__desc__, epilog=__epilog__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('dirs', metavar='DICOM_DIR', help='DICOM directory or directories to process.', nargs='+')

    try:
        args = parser.parse_args()
        for dir in args.dirs:
            print(f"Processing directory: {dir}")
            copy_dicom_files(dir)
        elapsed_time = time.time() - start_time
        print(f"Execution time: {elapsed_time:.2f} seconds.")
        return 0
    except Exception as e:
        print(f"Error: {e}")
        return 1

if __name__ == '__main__':
    import sys
    sys.exit(main())
