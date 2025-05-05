#!/usr/bin/env python3

import os
import json
import sys
import glob
import shutil
import argparse
import pandas as pd
import re

def check_image_type(json_file):
    """Check ImageType from JSON file"""
    try:
        with open(json_file, 'r') as f:
            data = json.load(f)
            if 'ImageType' in data:
                image_types = data['ImageType']
                if isinstance(image_types, list):
                    for img_type in image_types:
                        if 'MAGNITUDE' in str(img_type).upper():
                            return 'magnitude'
                        elif 'PHASE' in str(img_type).upper():
                            return 'phase'
                return 'unknown'
    except:
        return 'unknown'
    return 'unknown'

def update_scans_tsv(scans_file, rename_mapping, files_deleted):
    """Update the scans.tsv file with new filenames and remove deleted files"""
    try:
        df = pd.read_csv(scans_file, sep='\t')
        
        # Update filenames in the mapping
        for old_file, new_file in rename_mapping.items():
            old_path = f"fmap/{old_file}"
            new_path = f"fmap/{new_file}"
            
            if old_path in df['filename'].values:
                df.loc[df['filename'] == old_path, 'filename'] = new_path
                print(f"Updated scans.tsv: {old_path} -> {new_path}")
        
        # Remove entries for deleted files
        for deleted_file in files_deleted:
            deleted_path = f"fmap/{deleted_file}"
            if deleted_path in df['filename'].values:
                df = df[df['filename'] != deleted_path]
                print(f"Removed from scans.tsv: {deleted_path}")
        
        # Save updated dataframe
        df.to_csv(scans_file, sep='\t', index=False)
        print(f"Saved updated scans.tsv")
        
    except Exception as e:
        print(f"Error updating scans.tsv: {e}")

def reorganize_fieldmaps(subject_dir, keep_extra=False):
    """Reorganize GE fieldmap files after BIDS conversion"""
    
    fmap_dir = os.path.join(subject_dir, 'fmap')
    if not os.path.exists(fmap_dir):
        print(f"Fieldmap directory not found: {fmap_dir}")
        return {}, []
    
    rename_mapping = {}
    files_deleted = []
    
    # Process all nii.gz files
    all_files = glob.glob(os.path.join(fmap_dir, '*.nii.gz'))
    
    for nii_file in all_files:
        base_name = os.path.splitext(os.path.splitext(nii_file)[0])[0]
        json_file = base_name + '.json'
        
        # Process magnitude files
        for echo_num in ['1', '2']:
            if f'magnitude{echo_num}' in os.path.basename(nii_file):
                if os.path.exists(json_file):
                    img_type = check_image_type(json_file)
                    
                    old_basename = os.path.basename(nii_file)
                    
                    if img_type == 'phase':
                        # Rename magnitude to phase
                        new_base = base_name.replace(f'magnitude{echo_num}', f'phase{echo_num}')[:-1]
                        new_nii = new_base + '.nii.gz'
                        new_json = new_base + '.json'
                        new_basename = os.path.basename(new_nii)
                        
                        print(f"Renaming phase: {old_basename} -> {new_basename}")
                        rename_mapping[old_basename] = new_basename
                        
                        # Remove existing file if it exists
                        if os.path.exists(new_nii):
                            os.remove(new_nii)
                        if os.path.exists(new_json):
                            os.remove(new_json)
                        
                        os.rename(nii_file, new_nii)
                        os.rename(json_file, new_json)
                        
                    elif img_type == 'magnitude':
                        # Rename magnitude to simplified name
                        new_base = base_name.replace(f'magnitude{echo_num}', f'magnitude{echo_num}')[:-1]
                        new_nii = new_base + '.nii.gz'
                        new_json = new_base + '.json'
                        new_basename = os.path.basename(new_nii)
                        
                        print(f"Renaming magnitude: {old_basename} -> {new_basename}")
                        rename_mapping[old_basename] = new_basename
                        
                        # Remove existing file if it exists
                        if os.path.exists(new_nii):
                            os.remove(new_nii)
                        if os.path.exists(new_json):
                            os.remove(new_json)
                        
                        os.rename(nii_file, new_nii)
                        os.rename(json_file, new_json)
    
    # Remove numbered magnitude files
    print("\nRemoving numbered magnitude files...")
    for pattern in ['*.nii.gz', '*.json']:
        for file in glob.glob(os.path.join(fmap_dir, f'*{pattern}')):
            basename = os.path.basename(file)
            # Check if it matches pattern like "magnitude12", "magnitude14", etc.
            if re.search(r'magnitude[12][1-4]\.(nii\.gz|json)$', basename):
                print(f"Removing: {basename}")
                files_deleted.append(basename)
                os.remove(file)
    
    # Remove extra files (real and imaginary) by default
    if not keep_extra:
        print("Removing real and imaginary files...")
        for pattern in ['*_real.*', '*_imaginary.*']:
            for file in glob.glob(os.path.join(fmap_dir, pattern)):
                basename = os.path.basename(file)
                print(f"Removing: {basename}")
                files_deleted.append(basename)
                os.remove(file)
    
    # List final contents
    print("\nFinal fieldmap directory contents:")
    for file in sorted(os.listdir(fmap_dir)):
        print(f"  {file}")
    
    return rename_mapping, files_deleted

def main():
    parser = argparse.ArgumentParser(description='Reorganize GE fieldmap files after BIDS conversion')
    parser.add_argument('set_name', help='Set name (e.g., OSKX_MR3_S1)')
    parser.add_argument('--keep-extra', action='store_true', help='Keep real and imaginary files')
    
    args = parser.parse_args()
    
    # Construct rawdata path
    rawdata_path = os.path.join(args.set_name, 'bids', 'rawdata')
    
    if not os.path.exists(rawdata_path):
        print(f"Error: Rawdata directory not found: {rawdata_path}")
        sys.exit(1)
    
    # Find all subject directories
    subject_dirs = glob.glob(os.path.join(rawdata_path, 'sub-*'))
    
    if not subject_dirs:
        print(f"Error: No subject directories found in {rawdata_path}")
        sys.exit(1)
    
    # Process each subject
    for subject_dir in subject_dirs:
        subject_id = os.path.basename(subject_dir)
        print(f"\nProcessing {subject_id}...")
        
        # Reorganize fieldmaps and get rename mapping and deleted files
        rename_mapping, files_deleted = reorganize_fieldmaps(subject_dir, args.keep_extra)
        
        # Update scans.tsv with both renamed and deleted files
        scans_file = os.path.join(subject_dir, f"{subject_id}_scans.tsv")
        if os.path.exists(scans_file):
            update_scans_tsv(scans_file, rename_mapping, files_deleted)
        else:
            print(f"Warning: scans.tsv not found at {scans_file}")
    
    print("\nDone.")

if __name__ == '__main__':
    main()
