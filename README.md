# batch-heudiconv

These scripts help you generate BIDS dataset on your DICOM.
Please follow the instructions below.

## Preparation
- These scripts need the following software packages.
    - dcm2niix
        - dcm2niix is included in MRIcroGL https://github.com/rordenlab/MRIcroGL/releases
        - Add the path to dcm2niix
    - pydicom
        - ```pip install pydicom``` or ```conda install pydicom``` based on your preference
    - heudiconv
        - ```pip install heudiconv```

- You have an option to use Docker. In this case, when you run the batch, please use batch_heudiconv{1,2}_docker.sh (preparing, not available yet).

## 1. Run dcm_sort_dir.py
- Before you run the scripts using heudiconv, sort DICOM using dcm_sort_dir.py.
- Set path to this directory so that you can run the script.
- Please save your dicoms under `path_to_DICOM/original/subjectid`.
- Run the following command.
    ```
    cd path_to_DICOM/original
    dcm_sort_dir subjectid
    ```
- sorted DICOMs will be saved in `path_to_DICOM/sorted/subjectid`.

## 2. Prepare subjlist.txt
- copy subjlist.sample.txt as subjlist.txt.
    ```cp subjlist.sample.txt subjlist.txt```
- You need to describe three items; directory, subject_ID, and session.
    - directory: directory should include sujbect_ID. The simple one is directory name = subject_ID. In this case, what you write here is simply {subject}. You can include session info. In that case, what you write would be {subject}_{session}.
    - subject_ID: describe subject ID of your samples
    - session: If your subjects undergo MRI several times, session would be useful. If subjects undergo MRI only once, just put 01 on the session
- The script reads the 7th line and below, so please do not delete the first 6 lines.

## 3. Prepare heuristic.py
- We prepare two types of heuristic.py. One assumes you don't have filedmaps, and the other assumes you have filedmaps. If you have double echo fieldmaps, you need to be careful to handle magnitude file because that image has two TE within. If you just convert the image with dcm2niix, you will have two separate brain based on two different TEs. 


### 3.1. Case 1. You don't have fieldmaps
- Please use heuristic_template10_wo_filedmaps.py in "code" directory.
    ```
    cd code
    cp heuristic_template10_wo_filedmaps.py heuristic.py
    ```
- Please look at lines 19-56.
    - Here you list keys for the images you want to convert.
    - Based on the images you want to convert, please modify the lines.
    - Make sure you have all elements in the line 56.
- Then please look at lines 88-131.
    - Here you describe the condition to identify the specific sequence.
    - If you have sorted your DICOMs beforehand with dcm_sort_dir.py, your DICOM images are already sorted and the name of subdirectories include series description. So it would be easy to decide the series you want to convert.
    - Please replace 'dir_name_for_[sequence]' with the series description of your images.
        - Suppose your T1 images are stored in 'T1_MPR'. In this case, replace 'dir_name_for_T1' with 'T1_MPR'.

### 3.2 Case 2. You have double echo fieldmaps
- Please use heuristic_template2*.py in "code" directory.
    ```
    cd code
    cp heuristic_template21_wo_mag.py heuristic1.py
    cp heuristic_template22_mag.py heuristic2.py
    ```

- Please open heuristic1.py.
    - look at lines 19-56 of heuristic1.py.
    - Here you list keys for the images you want to convert.
    - Based on the images you want to convert, please modify the lines.
    - Make sure you have all elements in the line 56.
- Then please look at lines 88-131 of heuristic1.py.
    - Here you describe the condition to identify the specific sequence.
    - If you have sorted your DICOMs beforehand with dcm_sort_dir.py, your DICOM images are already sorted and the name of subdirectories include series description. So it would be easy to decide the series you want to convert.
    - Please replace 'dir_name_for_[sequence]' with the series description of your images.
        - Suppose your T1 images are stored in 'T1_MPR'. In this case, replace 'dir_name_for_T1' with 'T1_MPR'.

- After looking through heuristic1.py Please open heuristic2.py.
    - look at line 24 of heuristic2.py.
    - Please confirm the key is right (basically you don't have to anything).
- Then please look at lines 67-87.
    - replace 'dir_name_for_fieldmap_magnitude' with the series description of your images.

## 4.1. Case 1. You don't have fieldmaps
- Please run the batch_heudiconv1.sh.
    ```
    batch_heudiconv1.sh heuristic.py subjlist.txt
    ```
    - This will generate BIDS structure for you. Now you are ready to check your BIDS with [BIDS_validator](https://bids-standard.github.io/bids-validator/).

## 4.2. Case 2. You have double echo fieldmaps
- Please run the batch_heudiconv1.sh with heuristic1.py.
    ```
    batch_heudiconv1.sh heuristic1.py subjlist.txt
    ```
    - This will generate BIDS structure except for magnitude image.

- Then run the batch_heudiconv2.sh with heuristic2.py.
    ```
    batch_heudiconv2.sh heuristic2.py subjlist.txt
    ```
    - This will generate BIDS structure for magnitude image.

- Now you are ready to check your BIDS with [BIDS_validator](https://bids-standard.github.io/bids-validator/).
