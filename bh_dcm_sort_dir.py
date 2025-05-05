#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# DICOM sorting script using pydicom
# Part of this script is based on the script provided by Yuya Saito
# Prerequisite: pydicom and numpy

# 05 May 2025 K. Nemoto

import os
import time
import re
import shutil
import argparse
import pydicom
import sys
import logging

__version__ = '20250505'

__desc__ = '''
Sort DICOM files.
Please note that the PatientID is assumed from the directory name.
Non-imaging DICOM files will be skipped.
'''
__epilog__ = '''
examples:
  dcm_sort_dir.py DICOM_DIR [DICOM_DIR ...]
'''

# Configure logging
logging.basicConfig(filename='dcm_sort.log', level=logging.INFO,
                   format='%(asctime)s %(levelname)s: %(message)s')

def generate_dest_dir_name(dicom_dataset: pydicom.dataset.FileDataset) -> str:
    """
    Generate a destination directory name based on DICOM series information.
    
    Args:
        dicom_dataset: A DICOM dataset object containing series information
        
    Returns:
        A string containing the formatted directory name (SeriesNumber_SeriesDescription)
    """
    # Pad series number with leading zeros
    series_number = str(dicom_dataset.SeriesNumber).zfill(2)
    # Replace spaces with underscores in series description
    series_description = dicom_dataset.SeriesDescription.replace(' ', '_')
    rule_text = f'{series_number}_{series_description}'
    # Remove characters that are invalid in directory names
    return re.sub(r'[(\\/:?*"<>|)]', '', rule_text)

def sort_dicom_files(src_dir: str, sorted_dir: str = '../sorted/') -> None:
    """
    Sort DICOM files from source directory into series-based subdirectories.
    
    Args:
        src_dir: Source directory containing DICOM files
        sorted_dir: Base directory where sorted files will be saved (default: '../sorted/')
    """
    # Strip trailing slashes from the source directory
    src_dir = src_dir.rstrip('/')
    
    # Create output directory if it doesn't exist
    if not os.path.exists(sorted_dir):
        os.makedirs(sorted_dir)

    # Walk through all files in the source directory
    for root, _, files in os.walk(src_dir):
        for file in files:
            src_file = os.path.join(root, file)
            try:
                # Read DICOM file
                ds = pydicom.dcmread(src_file)
                # Process only imaging DICOM files
                if hasattr(ds, 'pixel_array'):
                    # Generate destination directory name based on series info
                    dest_dir_name = generate_dest_dir_name(ds)
                    # Create full path for output directory
                    out_dir = os.path.join(sorted_dir, os.path.basename(src_dir))
                    dest_dir = os.path.join(out_dir, dest_dir_name)
                    os.makedirs(dest_dir, exist_ok=True)
                    # Save DICOM file to destination
                    dest_file = os.path.join(dest_dir, file)
                    ds.save_as(dest_file)
                    logging.info(f"Sorted {src_file} to {dest_file}")
                    print(f"Sorted {src_file} to {dest_file}")
            except Exception as e:
                error_msg = f"Failed to process {src_file}: {e}"
                logging.error(error_msg)
                print(error_msg)

def main() -> int:
    """
    Main function to handle command line arguments and orchestrate DICOM sorting.
    
    Returns:
        int: 0 for successful execution, 1 for errors
    """
    # Record start time for performance measurement
    start_time = time.time()
    
    # Set up command line argument parser
    parser = argparse.ArgumentParser(description=__desc__, epilog=__epilog__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('-v', '--version', action='version',
                       version=f'%(prog)s {__version__}')
    parser.add_argument('dirs', metavar='DICOM_DIR', 
                       help='DICOM directory or directories to process.', nargs='+')

    # Display help message if no arguments provided
    if len(sys.argv) == 1:
        parser.print_help()
        return 0

    try:
        args = parser.parse_args()
        # Process each specified directory
        for dir in args.dirs:
            # Verify that input is a directory
            if not os.path.isdir(dir):
                print(parser.format_usage().rstrip())
                print(f"Error: '{dir}' is not a directory")
                return 1
            logging.info(f"Processing directory: {dir}")
            print(f"Processing directory: {dir}")
            sort_dicom_files(dir)
            
        # Display execution time
        elapsed_time = time.time() - start_time
        execution_msg = f"Execution time: {elapsed_time:.2f} seconds."
        logging.info(execution_msg)
        print(execution_msg)
        return 0
    except Exception as e:
        error_msg = f"Error: {e}"
        logging.error(error_msg)
        print(error_msg)
        return 1

if __name__ == '__main__':
    sys.exit(main())
