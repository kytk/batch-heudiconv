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

    ##### list keys for filedmaps below ############


    # Filed map (magnitude and phasediff: Siemens)
    # If you have double echo field maps, convert phasediff first, then convert magnitude later. 
    fmap_mag =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_magnitude')
    #fmap_phase = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_phasediff')

    # Field map (two phases: Siemens)
    #fmap_PA =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-PA_fieldmap')
    #fmap_AP =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_dir-AP_fieldmap')

    # Field map (magnitude and field: GE)
    #fmap_mag =  create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_magnitude')
    #fmap_field = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_fieldmap')
    

    #info = {t1w: [], func_rest: [], dwi: [], fmap_mag: [], fmap_phase: []}
    info = {fmap_mag: []}

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

        # Fieldmap
        # Fieldmap (magnitude and phasediff: Siemens)
        if 'dir_name_for_fieldmap_magnitude' in s.dcm_dir_name:    
            info[fmap_mag].append(s.series_id)
        #if 'dir_name_for_fieldmap_phasediff' in s.dcm_dir_name:    
        #    info[fmap_phase].append(s.series_id)

        # Fieldmap (two phases: Siemens)
        #if 'dir_name_for_fieldmap_PA' in s.dcm_dir_name:    
        #    info[fmap_PA].append(s.series_id)
        #if 'dir_name_for_fieldmap_AP' in s.dcm_dir_name:    
        #    info[fmap_AP].append(s.series_id)

        # Fieldmap (magnitude and field: GE)
        #if 'field_map1' in s.dcm_dir_name:    
        #    info[fmap_mag].append(s.series_id)
        #if 'field_map2' in s.dcm_dir_name:    
        #    info[fmap_field].append(s.series_id)

            
    return info
