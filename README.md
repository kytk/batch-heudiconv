# batch-heudiconv

A set of scripts to help convert DICOM files to BIDS format using heudiconv. Each study is managed as a self-contained workspace with organized directory structure.

## Key Features

✅ **Study-based organization**: Each research study gets its own workspace  
✅ **Automated heuristic generation**: Creates study-specific conversion rules  
✅ **Step-by-step workflow**: Clear progression from DICOM to BIDS  
✅ **Multi-vendor support**: Works with Siemens, GE, and Philips scanners  
✅ **Backup & safety**: Preserves original data throughout the process  

## Prerequisites

The following software packages are required:

- **dcm2niix**: Included in [MRIcroGL](https://github.com/rordenlab/MRIcroGL/releases)
- **pydicom**: Install via pip (`pip install pydicom`) or conda (`conda install pydicom`)
- **heudiconv**: Install via pip (`pip install heudiconv`)

## Installation

1. Clone this repository:
```bash
git clone https://github.com/kytk/batch-heudiconv.git
cd batch-heudiconv
```

2. Add the scripts to your PATH:
```bash
./bh00_addpath.sh
```

3. Restart your terminal for the PATH changes to take effect.

## Usage Workflow

The conversion process consists of five main steps. Each study is processed independently in its own directory.

### 1. 🏗️ Prepare Study Workspace

Create a complete workspace for your research study:

```bash
bh01_prep_dir.sh <study_name>
```

**Examples:**
```bash
bh01_prep_dir.sh resting_state_2024     # Creates organized workspace
bh01_prep_dir.sh pilot_dwi_study        # For diffusion study
bh01_prep_dir.sh longitudinal_cohort    # For multi-session study
```

This creates a structured workspace:
```
your_study_name/
├── DICOM/
│   ├── original/     # Place your DICOM files here
│   ├── sorted/       # For organized DICOM files
│   └── converted/    # Backup location
├── bids/
│   ├── rawdata/      # Final BIDS output
│   └── derivatives/  # For processed data
├── code/             # Study-specific heuristic files
└── tmp/              # Working files
```

### 2. 🗂️ Sort DICOM Files

After placing your DICOM directories under `DICOM/original/`, organize them by series:

```bash
bh02_sort_dicom.sh <study_name>
```

This script:
- Organizes DICOM files by series number and description
- Cleans up filenames (replaces spaces with underscores)
- Creates a structure ready for heudiconv processing

### 3. 📋 Create Subject List

Generate a subject list based on your directory naming pattern:

```bash
bh03_make_subjlist.sh <study_name> "<pattern>"
```

**Pattern Examples:**
```bash
# For directories like "sub001_ses01":
bh03_make_subjlist.sh my_study "{subject}_{session}"

# For directories like "sub001-ses01":
bh03_make_subjlist.sh my_study "{subject}-{session}"

# For single-session directories like "sub001":
bh03_make_subjlist.sh my_study "{subject}"
```

### 4. ⚙️ Generate Study-Specific Heuristic

Create a heuristic file tailored to your study's DICOM structure:

```bash
bh04_make_heuristic.sh <study_name>
```

This script:
- Analyzes your DICOM files automatically
- Identifies sequence types (T1w, fMRI, DWI, fieldmaps)
- Creates `code/heuristic_<study_name>.py`
- Provides sequence-specific conversion rules

**Review the generated heuristic file** and adjust if needed for your specific sequences.

### 5. 🎯 Convert to BIDS

#### Standard Conversion
For most datasets:

```bash
bh05_make_bids.sh <study_name>
```

#### Double-Echo Fieldmap Data
For datasets with double-echo fieldmaps whose two echoes must be merged by dcm2niix:

```bash
bh05_make_bids.sh <study_name> --merge
```

`--merge` creates `code/merge.json` (`{"merge_imgs": true}`). Once this file exists, it is passed to heudiconv (`--dcmconfig`) for all subjects, so later runs do not need `--merge`. Remove the file to disable it.

## Study Directory Structure

After running the scripts, each study will have this structure:

```
study_name/
├── code/
│   └── heuristic_study_name.py     # Study-specific conversion rules
├── DICOM/
│   ├── original/                   # Original DICOM files (archived)
│   ├── sorted/                     # Series-organized DICOM (archived)  
│   └── converted/                  # Backup of processed files
├── bids/
│   ├── rawdata/                    # 📂 Your BIDS dataset is here!
│   │   ├── sub-001/
│   │   ├── sub-002/
│   │   ├── dataset_description.json
│   │   └── ...
│   └── derivatives/                # For processed data
└── tmp/
    └── subjlist_study_name.tsv     # Subject list for this study
```


---

### 🔧 **Utility Scripts (run as needed)**

These scripts address specific post-processing needs and can be run independently:

**Reorganize GE fieldmaps:**
```bash
bh_reorganize_fieldmaps.py <study_name> [--keep-extra]
```

**Sort DICOM files directly:**
```bash
bh_dcm_sort_dir.py <dicom_directory>
```


### Managing Multiple Studies

You can work on multiple studies simultaneously:

```bash
# Set up different studies
bh01_prep_dir.sh autism_rsfmri_2024
bh01_prep_dir.sh depression_longitudinal  
bh01_prep_dir.sh pilot_connectivity

# Each study has its own workspace and settings
ls -la
# autism_rsfmri_2024/
# depression_longitudinal/
# pilot_connectivity/
```

## Heuristic Files

The heuristic file (`heuristic_<study_name>.py`) defines how your sequences should be converted to BIDS format. While `bh04_make_heuristic.sh` creates an initial version automatically, you may need to adjust it for:

- Complex sequence naming patterns
- Multiple phase encoding directions (PA/AP)
- Multi-echo sequences
- Custom acquisition parameters

Sample heuristic files are provided in the `code/` directory as templates.

## Troubleshooting

### Common Issues

1. **No sequences detected**: Check your DICOM directory structure in `DICOM/sorted/`
2. **Heuristic doesn't match**: Review and edit `code/heuristic_<study_name>.py`
3. **Subject list empty**: Verify your directory naming pattern
4. **Conversion errors**: Check heudiconv logs and DICOM file integrity

### Getting Help

- Check the generated log files in your study directory
- Review the BIDS validator output
- Examine the heuristic file matching rules
- Use the BIDS community forum for BIDS-specific questions

## Example Complete Workflow

```bash
# 1. Create study workspace
bh01_prep_dir.sh my_rsfmri_study

# 2. Copy DICOM files to my_rsfmri_study/DICOM/original/

# 3. Sort DICOM files
bh02_sort_dicom.sh my_rsfmri_study

# 4. Create subject list
bh03_make_subjlist.sh my_rsfmri_study "{subject}_{session}"

# 5. Generate heuristic (review and edit if needed)
bh04_make_heuristic.sh my_rsfmri_study

# 6. Convert to BIDS
bh05_make_bids.sh my_rsfmri_study

# 7. Validate your BIDS dataset
# Upload my_rsfmri_study/bids/rawdata/ to BIDS validator
```

---

# 日本語説明

## batch-heudiconv とは

DICOMファイルをBIDS形式に変換するためのスクリプト群です。各研究を独立したワークスペースで管理し、効率的にデータを変換します。

## 主な特徴

✅ **研究単位での管理**: 各研究が独自のワークスペースを持つ  
✅ **自動heuristic生成**: 研究固有の変換ルールを作成  
✅ **段階的ワークフロー**: DICOMからBIDSへの明確な進行  
✅ **マルチベンダー対応**: Siemens、GE、Philipsスキャナに対応  
✅ **バックアップ機能**: プロセス全体で元データを保護  

## 必要なソフトウェア

- **dcm2niix**: [MRIcroGL](https://github.com/rordenlab/MRIcroGL/releases)に含まれています
- **pydicom**: `pip install pydicom`もしくは`conda install pydicom`でインストール
- **heudiconv**: `pip install heudiconv`でインストール

## 使用方法の流れ

変換は5つのステップで構成され、各研究は独立して処理されます。

### 1. 🏗️ 研究ワークスペースの準備

```bash
bh01_prep_dir.sh <研究名>
```

**例:**
```bash
bh01_prep_dir.sh resting_state_2024     # 安静時fMRI研究
bh01_prep_dir.sh pilot_dwi_study        # 拡散強調画像研究
```

### 2. 🗂️ DICOMファイルの整理

```bash
bh02_sort_dicom.sh <研究名>
```

### 3. 📋 被験者リストの作成

```bash
bh03_make_subjlist.sh <研究名> "<パターン>"
```

### 4. ⚙️ 研究固有のHeuristicファイル生成

```bash
bh04_make_heuristic.sh <研究名>
```

### 5. 🎯 BIDS形式への変換

```bash
bh05_make_bids.sh <研究名>
```

2つのエコーを dcm2niix で結合する必要がある double-echo fieldmap の場合:

```bash
bh05_make_bids.sh <研究名> --merge
```

`--merge` は `code/merge.json`（`{"merge_imgs": true}`）を作成します。このファイルが存在すると全被験者に `--dcmconfig` として適用されるため、2回目以降は `--merge` は不要です。無効にするにはファイルを削除してください。

---

### 🔧 **ユーティリティスクリプト（必要に応じて実行）**

これらのスクリプトは特定の後処理に対応し、独立して実行できます：

**GE fieldmapの整理:**
```bash
bh_reorganize_fieldmaps.py <研究名> [--keep-extra]
```

**DICOMファイルの直接ソート:**
```bash
bh_dcm_sort_dir.py <DICOMディレクトリ>
```



## 複数研究の並行管理

```bash
# 異なる研究を同時に設定可能
bh01_prep_dir.sh 自閉症_安静時fMRI_2024
bh01_prep_dir.sh うつ病_縦断研究
bh01_prep_dir.sh パイロット_接続性解析

# 各研究は独自のワークスペースと設定を持つ
```

各研究のheuristicファイル（`heuristic_<研究名>.py`）は、必要に応じて調整してください。サンプルファイルが`code/`ディレクトリに用意されています。
