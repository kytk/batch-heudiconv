# heuristic.py for OSKX_MR3_S1
# K. Nemoto 17 Apr 2025

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
    fmap_mag =  create_key('sub-{subject}/fmap/sub-{subject}_magnitude')
    fmap_phase = create_key('sub-{subject}/fmap/sub-{subject}_phase')
    

    info = {t1w: [], func_rest: [], dwi: [], fmap_mag: [], fmap_phase: []}

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
        if 'SPGR_TE' in s.dcm_dir_name and 'magnitude' in s.dcm_dir_name:
            info[fmap_mag].append(s.series_id)

        if 'SPGR_TE' in s.dcm_dir_name and 'phase' in s.dcm_dir_name:
            info[fmap_field].append(s.series_id)

    return info
