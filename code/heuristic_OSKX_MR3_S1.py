# heuristic.py for OSKX_MR3_S1
# K. Nemoto 17 Apr 2025

import os
import json

def create_key(template, outtype=('nii.gz',), annotation_classes=None):
    if template is None or not template:
        raise ValueError('Template must be a valid format string')
    return template, outtype, annotation_classes

def infotodict(seqinfo):
    """Heuristic evaluator for determining which runs belong where

    allowed template fields - follow python string module:

    item: index within category
    subject: participant id
    seqitem: run number during scanning
    subindex: sub index within group
    """

    ##### list keys for t1w, t2w, dwi, rs-fMRI, and filedmaps below ############

    # T1
    t1w = create_key('sub-{subject}/anat/sub-{subject}_run-{item:02d}_T1w')

    # T2
    #t2w = create_key('sub-{subject}/anat/sub-{subject}_run-{item:02d}_T2w')

    # Resting-state (only one phase encoding)
    func_rest = create_key('sub-{subject}/func/sub-{subject}_task-rest_run-{item:02d}_bold')

    # Resting-state (PA and AP)
    #func_rest_PA = create_key('sub-{subject}/func/sub-{subject}_dir-PA_task-rest_run-{item:02d}_bold')
    #func_rest_AP = create_key('sub-{subject}/func/sub-{subject}_dir-AP_task-rest_run-{item:02d}_bold')

    # DWI (only one phase encoding)
    dwi = create_key('sub-{subject}/dwi/sub-{subject}_run-{item:02d}_dwi')

    # DWI (PA and AP)
    #dwi_PA = create_key('sub-{subject}/dwi/sub-{subject}_dir-PA_run-{item:02d}_dwi')
    #dwi_AP = create_key('sub-{subject}/dwi/sub-{subject}_dir-AP_run-{item:02d}_dwi')

    # Filed map (magnitude and phasediff: Siemens)
    # If you have double echo field maps, convert phasediff first, then convert magnitude later. 
    #fmap_mag =  create_key('sub-{subject}/fmap/sub-{subject}_magnitude')
    #fmap_phase = create_key('sub-{subject}/fmap/sub-{subject}_phasediff')

    # Field map (two phases: Siemens)
    #fmap_PA =  create_key('sub-{subject}/fmap/sub-{subject}_dir-PA_fieldmap')
    #fmap_AP =  create_key('sub-{subject}/fmap/sub-{subject}_dir-AP_fieldmap')

    # Field map (magnitude and field: GE)
    fmap_mag1 =  create_key('sub-{subject}/fmap/sub-{subject}_magnitude1')
    fmap_mag2 =  create_key('sub-{subject}/fmap/sub-{subject}_magnitude2')
    fmap_phase1 = create_key('sub-{subject}/fmap/sub-{subject}_phase1')
    fmap_phase2 = create_key('sub-{subject}/fmap/sub-{subject}_phase2')
    

    info = {t1w: [], func_rest: [], dwi: [], 
            fmap_mag1: [], fmap_phase1: [],
            fmap_mag2: [], fmap_phase2: []}

    ############################################################################

    for idx, s in enumerate(seqinfo):
        """
        The namedtuple `s` contains the following fields:

        * total_files_till_now
        * example_dcm_file
        * series_id
        * dcm_dir_name
        * unspecified2
        * unspecified3
        * dim1
        * dim2
        * dim3
        * dim4
        * TR
        * TE
        * protocol_name
        * is_motion_corrected
        * is_derived
        * patient_id
        * study_description
        * referring_physician_name
        * series_description
        * image_type
        """

        ### extract keywords from sorted DICOM series-based sub-directories and dimensions ###

        # T1w
        if 'IR400_SPGR' in s.dcm_dir_name:
            info[t1w].append(s.series_id)

        # T2w
        #if 'dir_name_for_T2' in s.dcm_dir_name:
        #    info[t2w].append(s.series_id)

        # rs-fMRI
        if 'fMRI_Resting' in s.dcm_dir_name:    
            info[func_rest].append(s.series_id)

        #if ('BOLD_REST1_PA' in s.dcm_dir_name) and (s.dim4 >= 200) :    
        #    info[func_rest_PA].append(s.series_id)
        #if ('BOLD_REST1_AP' in s.dcm_dir_name) and (s.dim4 >= 200) :    
        #    info[func_rest_AP].append(s.series_id)

        # DWI
        if 'DTIMPG15_b1000' in s.dcm_dir_name:    
            info[dwi].append(s.series_id)

        #if ('DWI_PA' in s.dcm_dir_name) and (s.dim4 >= 30):    
        #    info[dwi_PA].append(s.series_id)
        #if ('DWI_AP' in s.dcm_dir_name) and (s.dim4 >= 30):    
        #    info[dwi_AP].append(s.series_id)

        # Fieldmap
        # Fieldmap (magnitude and phasediff: Siemens)
        #if 'Field_mapping' in s.dcm_dir_name and 'M' in s.image_type:    
        #    info[fmap_mag].append(s.series_id)
        #if 'Field_mapping' in s.dcm_dir_name and 'P' in s.image_type:    
        #    info[fmap_phase].append(s.series_id)

        # Fieldmap (opposite phases: Siemens)
        #if 'dir_name_for_fieldmap_PA' in s.dcm_dir_name:    
        #    info[fmap_PA].append(s.series_id)
        #if 'dir_name_for_fieldmap_AP' in s.dcm_dir_name:    
        #    info[fmap_AP].append(s.series_id)

        # Fieldmap (magnitude and phase: GE)
        # Do not classify anything here - let heudiconv convert everything first
        # The classification will be done in the MetadataExtras
        if '2D-field_map1' in s.dcm_dir_name:
            # Temporary placeholder - this will create all files
            info[fmap_mag1].append(s.series_id)
        
        if '2D-field_map2' in s.dcm_dir_name:
            # Temporary placeholder - this will create all files  
            info[fmap_mag2].append(s.series_id)

    return info

# Add metadata extractor function to handle the post-processing
def MetadataExtras(outdict):
    """Add additional metadata and reorganize fieldmap files"""
    import shutil
    import glob
    
    # Find all fmap files
    fmap_dir = os.path.join(os.path.dirname(outdict.get('anat', [])[0] if 'anat' in outdict else '.'), 'fmap')
    
    if os.path.exists(fmap_dir):
        files = glob.glob(os.path.join(fmap_dir, '*.json'))
        
        for json_file in files:
            base_name = json_file[:-5]  # Remove .json
            nii_file = base_name + '.nii.gz'
            
            try:
                # Read JSON to check ImageType
                with open(json_file, 'r') as f:
                    metadata = json.load(f)
                    
                if 'ImageType' in metadata:
                    image_type_list = metadata['ImageType']
                    if isinstance(image_type_list, list) and len(image_type_list) > 0:
                        last_type = str(image_type_list[-1]).upper()
                        
                        # Determine echo number from file name
                        echo = ''
                        if 'magnitude11' in json_file or 'magnitude12' in json_file or \
                           'magnitude13' in json_file or 'magnitude14' in json_file:
                            echo = '1'
                        elif 'magnitude21' in json_file or 'magnitude22' in json_file or \
                             'magnitude23' in json_file or 'magnitude24' in json_file:
                            echo = '2'
                        
                        # Rename file based on type
                        if 'MAGNITUDE' in last_type and echo:
                            new_json = json_file.replace(f'magnitude{echo}', f'magnitude{echo}')
                            new_nii = nii_file.replace(f'magnitude{echo}', f'magnitude{echo}')
                        elif 'PHASE' in last_type and echo:
                            # Extract the sequence number (11, 12, etc)
                            import re
                            match = re.search(r'magnitude(\d\d)', os.path.basename(json_file))
                            if match:
                                seq_num = match.group(1)[1]  # Get second digit (1, 2, 3, 4)
                                new_json = json_file.replace(f'magnitude{echo}{seq_num}', f'phase{echo}')
                                new_nii = nii_file.replace(f'magnitude{echo}{seq_num}', f'phase{echo}')
                        else:
                            # Keep original names for non-fieldmap files
                            continue
                        
                        # Rename the files if needed
                        if new_json != json_file:
                            if os.path.exists(new_json):
                                os.remove(new_json)
                            shutil.move(json_file, new_json)
                            
                        if new_nii != nii_file and os.path.exists(nii_file):
                            if os.path.exists(new_nii):
                                os.remove(new_nii)
                            shutil.move(nii_file, new_nii)
                            
            except Exception as e:
                print(f"Error processing {json_file}: {e}")
    
    return None
