# batch-heudiconv

These scripts help you generate BIDS dataset on your DICOM.
Please follow the instructions below.

## Preparation
- These scripts need the following software packages
    - dcm2niix
        - dcm2niix is included in MRIcroGL https://github.com/rordenlab/MRIcroGL/releases
        - Add the path to dcm2niix
    - pydicom
        - ```pip install pydicom``` or ```conda install pydicom``` based on your preference
    - heudiconv
        - ```pip install heudiconv```

## 1. Run dcm_sort_dir.py
- Before you run the scripts using heudiconv, sort DICOM using dcm_sort_dir.py
- Set path to this directory so that you can run the script.
- Please save your dicoms under path_to_DICOM/original/subjectid
- Run the following command
    ```
    cd path_to_DICOM/original
    dcm_sort_dir subjectid
    ```
    
- sorted DICOMs will be saved in path_to_DICOM/sorted/subjectid
