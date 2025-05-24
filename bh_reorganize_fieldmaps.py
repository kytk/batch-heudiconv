#!/usr/bin/env python3
# Reorganize GE fieldmap files after BIDS conversion
# This script handles the complex file naming issues that occur with GE fieldmaps during heudiconv processing
# K.Nemoto 24 May 2025

import os
import json
import sys
import glob
import shutil
import argparse
import pandas as pd
import re

def check_image_type(json_file):
    """Check ImageType from JSON file to determine if it's magnitude or phase"""
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
                print(f"  Updated scans.tsv: {old_path} -> {new_path}")
        
        # Remove entries for deleted files
        for deleted_file in files_deleted:
            deleted_path = f"fmap/{deleted_file}"
            if deleted_path in df['filename'].values:
                df = df[df['filename'] != deleted_path]
                print(f"  Removed from scans.tsv: {deleted_path}")
        
        # Save updated dataframe
        df.to_csv(scans_file, sep='\t', index=False)
        print(f"  ✓ Saved updated scans.tsv")
        
    except Exception as e:
        print(f"  Warning: Error updating scans.tsv: {e}")

def reorganize_fieldmaps(subject_dir, keep_extra=False):
    """Reorganize GE fieldmap files after BIDS conversion
    
    Args:
        subject_dir: Path to subject directory (e.g., study_name/bids/rawdata/sub-001)
        keep_extra: Whether to keep real and imaginary files (default: False)
    
    Returns:
        tuple: (rename_mapping, files_deleted) for updating scans.tsv
    """
    
    fmap_dir = os.path.join(subject_dir, 'fmap')
    if not os.path.exists(fmap_dir):
        print(f"  Fieldmap directory not found: {fmap_dir}")
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
                        
                        print(f"  Renaming phase: {old_basename} -> {new_basename}")
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
                        
                        print(f"  Renaming magnitude: {old_basename} -> {new_basename}")
                        rename_mapping[old_basename] = new_basename
                        
                        # Remove existing file if it exists
                        if os.path.exists(new_nii):
                            os.remove(new_nii)
                        if os.path.exists(new_json):
                            os.remove(new_json)
                        
                        os.rename(nii_file, new_nii)
                        os.rename(json_file, new_json)
    
    # Remove numbered magnitude files
    print("  Removing numbered magnitude files...")
    for pattern in ['*.nii.gz', '*.json']:
        for file in glob.glob(os.path.join(fmap_dir, f'*{pattern}')):
            basename = os.path.basename(file)
            # Check if it matches pattern like "magnitude12", "magnitude14", etc.
            if re.search(r'magnitude[12][1-4]\.(nii\.gz|json)$', basename):
                print(f"  Removing: {basename}")
                files_deleted.append(basename)
                os.remove(file)
    
    # Remove extra files (real and imaginary) by default
    if not keep_extra:
        print("  Removing real and imaginary files...")
        for pattern in ['*_real.*', '*_imaginary.*']:
            for file in glob.glob(os.path.join(fmap_dir, pattern)):
                basename = os.path.basename(file)
                print(f"  Removing: {basename}")
                files_deleted.append(basename)
                os.remove(file)
    
    # List final contents
    print("  Final fieldmap directory contents:")
    final_files = sorted(os.listdir(fmap_dir))
    if final_files:
        for file in final_files:
            print(f"    {file}")
    else:
        print("    (no files remaining)")
    
    return rename_mapping, files_deleted

def main():
    parser = argparse.ArgumentParser(
        description='Reorganize GE fieldmap files after BIDS conversion for your study',
        epilog='''
Examples:
  %(prog)s my_study_2024           # Reorganize GE fieldmaps for study 'my_study_2024'
  %(prog)s ge_pilot --keep-extra   # Keep real/imaginary files during reorganization

This script handles issues specific to GE fieldmap conversion:
1. Corrects magnitude/phase file naming based on DICOM ImageType
2. Removes duplicate and temporary files created during conversion
3. Updates scans.tsv files to reflect the changes
4. Cleans up real/imaginary files (unless --keep-extra is specified)

Prerequisites:
  - BIDS conversion completed with: bh05_make_bids.sh <study_name>
  - GE fieldmap data present in: <study_name>/bids/rawdata/sub-*/fmap/

Note: This script is specifically designed for GE scanner fieldmap data.
For other vendors, this reorganization may not be necessary.
        ''',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('study_name', help='Name of your research study')
    parser.add_argument('--keep-extra', action='store_true', 
                       help='Keep real and imaginary files (default: remove them)')
    
    args = parser.parse_args()
    
    # Construct rawdata path
    rawdata_path = os.path.join(args.study_name, 'bids', 'rawdata')
    
    if not os.path.exists(rawdata_path):
        print(f"Error: BIDS rawdata directory not found: {rawdata_path}")
        print(f"Please ensure BIDS conversion is completed for study '{args.study_name}'")
        print(f"Run: bh05_make_bids.sh {args.study_name}")
        sys.exit(1)
    
    # Find all subject directories
    subject_dirs = glob.glob(os.path.join(rawdata_path, 'sub-*'))
    
    if not subject_dirs:
        print(f"Error: No subject directories found in {rawdata_path}")
        sys.exit(1)
    
    print(f"Reorganizing GE fieldmaps for study '{args.study_name}'")
    print(f"Processing {len(subject_dirs)} subjects...")
    print("")
    
    # Process each subject
    subjects_processed = 0
    for subject_dir in subject_dirs:
        subject_id = os.path.basename(subject_dir)
        print(f"Processing {subject_id}...")
        
        # Check if subject has fieldmap directory
        fmap_dir = os.path.join(subject_dir, 'fmap')
        if not os.path.exists(fmap_dir):
            print(f"  No fieldmap directory found, skipping...")
            continue
            
        # Reorganize fieldmaps and get rename mapping and deleted files
        rename_mapping, files_deleted = reorganize_fieldmaps(subject_dir, args.keep_extra)
        
        # Update scans.tsv with both renamed and deleted files
        scans_file = os.path.join(subject_dir, f"{subject_id}_scans.tsv")
        if os.path.exists(scans_file):
            update_scans_tsv(scans_file, rename_mapping, files_deleted)
        else:
            print(f"  Warning: scans.tsv not found at {scans_file}")
            
        subjects_processed += 1
        print("")
    
    print("=" * 50)
    if subjects_processed > 0:
        print(f"✓ Successfully reorganized GE fieldmaps for {subjects_processed} subjects in study '{args.study_name}'")
        print("")
        print("Next steps:")
        print("1. Validate your BIDS dataset with the BIDS validator")
        print("2. Check that fieldmap files are correctly named and organized")
        if not args.keep_extra:
            print("3. Note: Real and imaginary files were removed (use --keep-extra to preserve them)")
    else:
        print(f"No subjects with fieldmap data found in study '{args.study_name}'")
        print("This script is specifically for GE fieldmap reorganization.")

if __name__ == '__main__':
    main()
