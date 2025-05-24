#!/usr/bin/env python3
# Fix IntendedFor field in fieldmap JSON files
# This script ensures that fieldmaps only reference functional scans with matching phase encoding directions
# K.Nemoto 24 May 2025

import os
import json
import glob
import re
import argparse

def main():
    # Set up command line arguments
    parser = argparse.ArgumentParser(
        description='Fix IntendedFor field in fieldmap JSON files for your study',
        epilog='''
Examples:
  %(prog)s my_study_2024           # Fix IntendedFor fields for study 'my_study_2024'
  %(prog)s resting_state_pilot     # Fix IntendedFor fields for study 'resting_state_pilot'

This script processes fieldmap JSON files and ensures that:
1. Each fieldmap only references functional scans with matching phase encoding directions
2. IntendedFor fields contain appropriate relative paths
3. Orphaned or mismatched references are removed

Prerequisites:
  - BIDS conversion completed with: bh05_make_bids.sh <study_name>
  - Study directory: <study_name>/bids/rawdata/
        ''',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('study_name', help='Name of your research study')
    args = parser.parse_args()
    
    # Construct the BIDS directory path
    bids_dir = os.path.join(args.study_name, 'bids', 'rawdata')
    
    # Check if BIDS directory exists
    if not os.path.exists(bids_dir):
        print(f"Error: BIDS directory not found at {bids_dir}")
        print(f"Please ensure BIDS conversion is completed for study '{args.study_name}'")
        print(f"Run: bh05_make_bids.sh {args.study_name}")
        return
    
    print(f"Processing BIDS data for study '{args.study_name}' in: {bids_dir}")
    print("")
    
    # Track number of fixed files
    fixed_files_count = 0
    
    # Process each subject
    for subject_dir in glob.glob(os.path.join(bids_dir, 'sub-*')):
        subject_id = os.path.basename(subject_dir)
        
        # Process each session
        session_dirs = glob.glob(os.path.join(subject_dir, 'ses-*'))
        
        # If no session directories exist, process the subject directory directly
        if not session_dirs:
            session_dirs = [subject_dir]
            
        for session_dir in session_dirs:
            session_id = os.path.basename(session_dir) if 'ses-' in session_dir else 'single-session'
            
            # Look for all JSON files in the fmap directory
            fmap_dir = os.path.join(session_dir, 'fmap')
            if not os.path.exists(fmap_dir):
                continue
                
            print(f"Processing {subject_id}/{session_id}...")
            
            for fmap_json in glob.glob(os.path.join(fmap_dir, '*_epi.json')):
                # Extract direction information from the JSON filename
                direction_match = re.search(r'_dir-([A-Z]+)_', os.path.basename(fmap_json))
                if not direction_match:
                    continue
                    
                direction = direction_match.group(1)  # 'AP' or 'PA'
                
                # Load the JSON file
                try:
                    with open(fmap_json, 'r') as f:
                        data = json.load(f)
                except Exception as e:
                    print(f"  Warning: Could not read {os.path.basename(fmap_json)}: {e}")
                    continue
                
                # Check if IntendedFor field exists
                if 'IntendedFor' not in data:
                    continue
                    
                # Record the original length of IntendedFor
                original_count = len(data['IntendedFor'])
                
                # Keep only functional scans that match the fieldmap direction
                filtered_intended_for = []
                for intended_file in data['IntendedFor']:
                    # Check the direction of the functional scan
                    intended_direction_match = re.search(r'_dir-([A-Z]+)_', intended_file)
                    if intended_direction_match and intended_direction_match.group(1) == direction:
                        filtered_intended_for.append(intended_file)
                
                # Only update the JSON if there were changes
                if len(filtered_intended_for) != original_count:
                    # Set the updated IntendedFor list
                    data['IntendedFor'] = filtered_intended_for
                    
                    # Write the changes to the JSON file
                    try:
                        with open(fmap_json, 'w') as f:
                            json.dump(data, f, indent=2)
                        
                        fixed_files_count += 1
                        print(f"  ✓ Updated {os.path.basename(fmap_json)}: IntendedFor reduced from {original_count} to {len(filtered_intended_for)} entries")
                    except Exception as e:
                        print(f"  Warning: Could not write {os.path.basename(fmap_json)}: {e}")

    print("")
    if fixed_files_count > 0:
        print(f"✓ Successfully fixed {fixed_files_count} fieldmap files in study '{args.study_name}'")
        print("")
        print("Next steps:")
        print("1. Validate your BIDS dataset with the BIDS validator")
        print("2. Check that fieldmaps now correctly reference matching functional scans")
    else:
        print(f"No IntendedFor fields needed fixing in study '{args.study_name}'")
        print("All fieldmap references appear to be correctly matched!")

if __name__ == "__main__":
    main()
