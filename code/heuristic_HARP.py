# heuristic.py for HARP protocol
# 03 May 2025 K. Nemoto

import os, re


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

    # Define keys for various modalities
    t1w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T1w')
    t2w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T2w')
    func_rest_PA = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_dir-PA_run-{item:02d}_bold')
    func_rest_PA_sbref = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_dir-PA_run-{item:02d}_sbref')
    func_rest_AP = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_dir-AP_run-{item:02d}_bold')
    func_rest_AP_sbref = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_dir-AP_run-{item:02d}_sbref')
    dwi_PA = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-PA_run-{item:02d}_dwi')
    dwi_PA_sbref = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-PA_run-{item:02d}_sbref')
    dwi_AP = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-AP_run-{item:02d}_dwi')
    dwi_AP_sbref = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-AP_run-{item:02d}_sbref')
    
    # Field map keys - use acq- label to match with the func dir
    fmap_PA = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_acq-func_dir-PA_run-{item:02d}_epi')
    fmap_AP = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_acq-func_dir-AP_run-{item:02d}_epi')
    
    info = {t1w: [], t2w: [], func_rest_PA: [], func_rest_PA_sbref: [], func_rest_AP: [], func_rest_AP_sbref: [], 
            dwi_PA: [], dwi_PA_sbref: [], dwi_AP: [], dwi_AP_sbref: [], fmap_PA: [], fmap_AP: []}

    # Extract run numbers from fieldmap directories to match with func runs
    #fieldmap_runs = {}
    #for s in seqinfo:
        #if 'SEField' in s.dcm_dir_name:
            #run_match = re.search(r'SEField(\d+)_([A-Z]+)', s.dcm_dir_name)
            #if run_match:
                #run_num = int(run_match.group(1))
                #direction = run_match.group(2)
                #fieldmap_runs[s.series_id] = (run_num, direction)

    # Main processing loop for categorizing scans
    for idx, s in enumerate(seqinfo):
        # Anatomical scans
        if 'T1_MPR' in s.dcm_dir_name:
            info[t1w].append(s.series_id)
        if 'T2_SPC' in s.dcm_dir_name:
            info[t2w].append(s.series_id)
            
        # Functional scans - PA direction
        if ('BOLD_REST' in s.dcm_dir_name) and ('PA' in s.dcm_dir_name) and (s.dim4 >= 200):    
            info[func_rest_PA].append(s.series_id)
        if ('BOLD_REST' in s.dcm_dir_name) and ('PA' in s.dcm_dir_name) and ('SBRef' in s.dcm_dir_name):    
            info[func_rest_PA_sbref].append(s.series_id)
            
        # Functional scans - AP direction
        if ('BOLD_REST' in s.dcm_dir_name) and ('AP' in s.dcm_dir_name) and (s.dim4 >= 200):    
            info[func_rest_AP].append(s.series_id)
        if ('BOLD_REST' in s.dcm_dir_name) and ('AP' in s.dcm_dir_name) and ('SBRef' in s.dcm_dir_name):    
            info[func_rest_AP_sbref].append(s.series_id)
            
        # Diffusion scans - PA direction
        if ('DWI_PA' in s.dcm_dir_name) and (s.dim4 >= 30):    
            info[dwi_PA].append(s.series_id)
        if ('DWI_PA' in s.dcm_dir_name) and ('SBRef' in s.dcm_dir_name):    
            info[dwi_PA_sbref].append(s.series_id)
            
        # Diffusion scans - AP direction
        if ('DWI_AP' in s.dcm_dir_name) and (s.dim4 >= 30):    
            info[dwi_AP].append(s.series_id)
        if ('DWI_AP' in s.dcm_dir_name) and ('SBRef' in s.dcm_dir_name):    
            info[dwi_AP_sbref].append(s.series_id)
            
        # Field maps
        if ('SEField' in s.dcm_dir_name) and ('PA' in s.dcm_dir_name):    
            info[fmap_PA].append(s.series_id)
        if ('SEField' in s.dcm_dir_name) and ('AP' in s.dcm_dir_name):    
            info[fmap_AP].append(s.series_id)
    
    return info


# Define options for automatic IntendedFor field population
POPULATE_INTENDED_FOR_OPTS = {
    'matching_parameters': ['ImagingVolume','ModalityAcquisitionLabel'],
    'criterion': 'Closest'
}

