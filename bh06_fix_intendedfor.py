#!/usr/bin/env python3
# fix_intended_for.py - Fix IntendedFor field in fieldmap JSON files

import os
import json
import glob
import re
import argparse

def main():
    # Set up command line arguments
    parser = argparse.ArgumentParser(description='Fix IntendedFor field in fieldmap JSON files')
    parser.add_argument('working_dir', help='Working directory path')
    args = parser.parse_args()
    
    # Construct the BIDS directory path
    bids_dir = os.path.join(args.working_dir, 'bids', 'rawdata')
    
    # Check if BIDS directory exists
    if not os.path.exists(bids_dir):
        print(f"Error: BIDS directory not found at {bids_dir}")
        return
    
    print(f"Processing BIDS data in: {bids_dir}")
    
    # Track number of fixed files
    fixed_files_count = 0
    
    # Process each subject
    for subject_dir in glob.glob(os.path.join(bids_dir, 'sub-*')):
        # Process each session
        session_dirs = glob.glob(os.path.join(subject_dir, 'ses-*'))
        
        # If no session directories exist, process the subject directory directly
        if not session_dirs:
            session_dirs = [subject_dir]
            
        for session_dir in session_dirs:
            # Look for all JSON files in the fmap directory
            fmap_dir = os.path.join(session_dir, 'fmap')
            if not os.path.exists(fmap_dir):
                continue
                
            for fmap_json in glob.glob(os.path.join(fmap_dir, '*_epi.json')):
                # Extract direction information from the JSON filename
                direction_match = re.search(r'_dir-([A-Z]+)_', os.path.basename(fmap_json))
                if not direction_match:
                    continue
                    
                direction = direction_match.group(1)  # 'AP' or 'PA'
                
                # Load the JSON file
                with open(fmap_json, 'r') as f:
                    data = json.load(f)
                
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
                    with open(fmap_json, 'w') as f:
                        json.dump(data, f, indent=2)
                    
                    fixed_files_count += 1
                    print(f"Updated {os.path.basename(fmap_json)}: IntendedFor reduced from {original_count} to {len(filtered_intended_for)} entries")

    print(f"Done. Fixed {fixed_files_count} files.")

if __name__ == "__main__":
    main()
