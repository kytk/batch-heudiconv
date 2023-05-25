# heuristic.py for MR0011
# Sample heuristic files for a Siemens Scanner

# K. Nemoto 25 May 2023

import os


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
    t1w = create_key('sub-{subject}/{session}/anat/sub-{subject}_{session}_run-{item:02d}_T1w')

    # Resting-state fMRI
    func_rest = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_run-{item:02d}_bold')

    # DWI
    dwi = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_run-{item:02d}_dwi')

    # Fieldmap
    fmap_mag =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_run-{item:02d}_magnitude')

    fmap_phase = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_run-{item:02d}_phasediff')

    info = {t1w: [], func_rest: [], dwi: [], fmap_mag: [], fmap_phase: []}

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

        if 'MPRAGE' in s.dcm_dir_name:
            info[t1w].append(s.series_id)
        if 'resting-state_fMRI' in s.dcm_dir_name:    
            info[func_rest].append(s.series_id)
        if 'DTI_b1000' in s.dcm_dir_name:    
            info[dwi].append(s.series_id)
        if 'field_mapping' in s.dcm_dir_name and 'M' in s.image_type:    
            info[fmap_mag].append(s.series_id)
        if 'field_mapping' in s.dcm_dir_name and 'P' in s.image_type:    
            info[fmap_phase].append(s.series_id)
            
    return info
