import os
import json
import stat

# Fill IntendedFor automatically: fmap with acq-dwi -> dwi/, acq-func -> func/, etc.
POPULATE_INTENDED_FOR_OPTS = {
    'matching_parameters': ['ModalityAcquisitionLabel'],
    'criterion': 'Closest'
}

def filter_dicom(dcmdata):
    """Return True to skip a DICOM file: drop phase images (e.g. the PHASE MAP in T1W_3D_TFE)"""
    image_type = [str(x).upper() for x in dcmdata.get('ImageType', [])]
    return 'PHASE MAP' in image_type or 'P' in image_type

# Philips does not store PE polarity / TotalReadoutTime in DICOM.
# dcm2niix NIfTI j axis = P->A, so dir-AP -> j-, dir-PA -> j
PE_POLARITY = {'dir-AP': 'j-', 'dir-PA': 'j'}

def custom_callable(prefix, outtypes, item_dicoms):
    """Called by heudiconv after each series is converted:
    add PhaseEncodingDirection and TotalReadoutTime to the sidecar"""
    json_file = prefix + '.json'
    label = next((k for k in PE_POLARITY if f'_{k}_' in os.path.basename(prefix)), None)
    if label is None or not os.path.exists(json_file):
        return
    with open(json_file) as f:
        d = json.load(f)
    # Guard against non-axial acquisitions
    if d.get('PhaseEncodingAxis', 'j') != 'j':
        raise ValueError(f"{json_file}: unexpected PhaseEncodingAxis {d['PhaseEncodingAxis']}")
    d['PhaseEncodingDirection'] = PE_POLARITY[label]
    if 'TotalReadoutTime' not in d and 'EstimatedTotalReadoutTime' in d:
        d['TotalReadoutTime'] = d['EstimatedTotalReadoutTime']
    # heudiconv may make sidecars read-only
    os.chmod(json_file, os.stat(json_file).st_mode | stat.S_IWUSR)
    with open(json_file, 'w') as f:
        json.dump(d, f, indent=2)

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

    # Resting-state (AP; the PA series is a field map, see fmap_func_PA below)
    func_rest_AP = create_key('sub-{subject}/{session}/func/sub-{subject}_{session}_task-rest_dir-AP_run-{item:02d}_bold')

    # fMRI field map (reversed phase encoding: PA, 10 volumes)
    fmap_func_PA = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_acq-func_dir-PA_epi')

    # DWI (only one phase encoding: PA)
    dwi = create_key('sub-{subject}/{session}/dwi/sub-{subject}_{session}_dir-PA_run-{item:02d}_dwi')

    # DWI field map (b0 with reversed phase encoding: AP and PA)
    fmap_dwi_AP = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_acq-dwi_dir-AP_epi')
    fmap_dwi_PA = create_key('sub-{subject}/{session}/fmap/sub-{subject}_{session}_acq-dwi_dir-PA_epi')

    info = {t1w: [], func_rest_AP: [], fmap_func_PA: [], dwi: [], fmap_dwi_AP: [], fmap_dwi_PA: []}

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
        if 'T1W_3D_TFE_Sag' in s.dcm_dir_name:
            info[t1w].append(s.series_id)

        # Philips classic DICOM: heudiconv reports dim4 = 1 and dim3 = slices x volumes,
        # so volume counts are checked via dim3 (46 slices per volume)

        # rs-fMRI
        if ('fMRI_fat_shift_direction_AP_MB' in s.dcm_dir_name) and (s.dim3 >= 46 * 200) :    
            info[func_rest_AP].append(s.series_id)

        # rs-fMRI fieldmap
        if ('fMRI_PA_MB' in s.dcm_dir_name) and (s.dim3 >= 46 * 10) :    
            info[fmap_func_PA].append(s.series_id)

        # DWI
        if 'DTI_32d_2mm_MB' in s.dcm_dir_name:    
            info[dwi].append(s.series_id)

        # DWI field map (b0, AP and PA)
        if 'DTI_32d_2mm_fat_shift_direction_AP_MB' in s.dcm_dir_name:
            info[fmap_dwi_AP].append(s.series_id)
        if 'DTI_32d_2mm_fat_shift_direction_PA_MB' in s.dcm_dir_name:
            info[fmap_dwi_PA].append(s.series_id)

            
    return info
