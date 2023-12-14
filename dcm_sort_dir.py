#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# DICOM sorting script using pydicom
# Part of this script is based on the script provided by Yuya Saito
# Prerequisite: pydicom

# 11 Sep 2023 K. Nemoto

import sys
import os
import time
import re
import shutil
import argparse
import pydicom

__version__ = '20230911'

__desc__ = '''
Sort DICOM files.
Please note that the PatientID is assumed from the directory name.
Non-imaging DICOM files will be skipped.
'''
__epilog__ = '''
examples:
  dcm_sort_dir.py DICOM_DIR [DICOM_DIR ...]
'''

def generate_dest_dir_name(dicom_dataset):
    series_number = str(dicom_dataset.SeriesNumber).zfill(2)
    series_description = dicom_dataset.SeriesDescription.replace(' ', '_')
    rule_text = f'{series_number}_{series_description}'
    return re.sub(r'[\\|/|:|?|"|<|>|\|]|\*', '', rule_text)

def copy_dicom_files(src_dir):
    # Relative path to the sorted directory
    sorted_dir = '../sorted/'

    # Create the sorted_dir if it doesn't exist
    if not os.path.exists(sorted_dir):
        os.makedirs(sorted_dir)

    # Copy files
    for root, dirs, files in os.walk(src_dir):
        for file in files:
            try:
                src_file = os.path.join(root, file)
                ds = pydicom.dcmread(src_file)
                if hasattr(ds, 'pixel_array'):
                    dest_dir_name = generate_dest_dir_name(ds)
                    out_dir = f'{sorted_dir}{src_dir.replace("/", "")}'
                    print(src_file, dest_dir_name)
                    dest_dir = os.path.join(out_dir, dest_dir_name)
                    os.makedirs(dest_dir, exist_ok=True)
                    shutil.copy2(src_file, dest_dir)
                    print(f"copy {src_file} -> {dest_dir}")
            except:
                pass

def main():
    start_time = time.time()
    parser = argparse.ArgumentParser(description=__desc__, epilog=__epilog__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('dirs', metavar='DICOM_DIR', help='DICOM directory or directories to process.', nargs='+')

    err = 0
    try:
        args = parser.parse_args()
        for dir in args.dirs:
            print(dir)
            copy_dicom_files(dir)
        print(f"Execution time: {time.time() - start_time:.2f} seconds.")
    except Exception as e:
        print(f"{__file__}: error: {str(e)}")
        err = 1

    sys.exit(err)

if __name__ == '__main__':
    main()
