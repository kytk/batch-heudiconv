# heuristic.py for HARP protocol
# 17 Feb 2023 K. Nemoto

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

##### list keys for t1w, dwi, rs-fMRI below ###########################################################################

    t1w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T1w')
    t2w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T2w')
    func_rest_PA = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_dir-PA_task-rest_run-{item:02d}_bold')
    func_rest_AP = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_dir-AP_task-rest_run-{item:02d}_bold')
    dwi_PA = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-PA_run-{item:02d}_dwi')
    dwi_AP = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-AP_run-{item:02d}_dwi')
    fmap_PA =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-PA_run-{item:02d}_fieldmap')
    fmap_AP =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-AP_{item:02d}_fieldmap')
    info = {t1w: [], t2w: [], func_rest_PA: [], func_rest_AP: [], dwi_PA: [], dwi_AP: [], fmap_PA: [], fmap_AP: []}

#######################################################################################################################

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

##### extract keywords from sorted DICOM series-based sub-directories ##########

        if 'T1_MPR' in s.dcm_dir_name:
            info[t1w].append(s.series_id)
        if 'T2_SPC' in s.dcm_dir_name:
            info[t2w].append(s.series_id)
        if ('BOLD_REST' in s.dcm_dir_name) and ('PA' in s.dcm_dir_name) and (s.dim4 >= 200):    
            info[func_rest_PA].append(s.series_id)
        if ('BOLD_REST' in s.dcm_dir_name) and ('AP' in s.dcm_dir_name) and (s.dim4 >= 200):    
            info[func_rest_AP].append(s.series_id)
        if ('DWI_PA' in s.dcm_dir_name) and (s.dim4 >= 30):    
            info[dwi_PA].append(s.series_id)
        if ('DWI_AP' in s.dcm_dir_name) and (s.dim4 >= 30):    
            info[dwi_AP].append(s.series_id)
        if ('SEField' in s.dcm_dir_name) and ('PA' in s.dcm_dir_name):    
            info[fmap_PA].append(s.series_id)
        if ('SEField' in s.dcm_dir_name) and ('AP' in s.dcm_dir_name):    
            info[fmap_AP].append(s.series_id)

################################################################################
            
    return info
