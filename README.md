# batch-heudiconv

A set of scripts to help convert DICOM files to BIDS format using heudiconv.

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
./00_addpath.sh
```

3. Restart your terminal for the PATH changes to take effect.

## Usage

The conversion process consists of five main steps:

### 1. Prepare Directory Structure

Create the necessary directory structure for your dataset:

```bash
01_prep_dir.sh <setname>
```

This creates:
- `DICOM/original/`: Place your original DICOM files here
- `DICOM/sorted/`: For sorted DICOM files
- `DICOM/converted/`: Backup of processed files
- `bids/`: BIDS-formatted output
- `code/`: For heuristic files
- `tmp/`: Temporary files

### 2. Sort DICOM Files

After placing your DICOM directories under `DICOM/original/`, sort them:

```bash
02_sort_dicom.sh <setname>
```

This organizes DICOM files into series-based directories.

### 3. Create Subject List

Generate a subject list based on your directory naming pattern:

```bash
03_make_subjlist.sh <setname> "<pattern>"
```

Pattern examples:
- `{subject}_{session}` for directories like "sub-001_01"
- `{subject}-{session}` for directories like "sub-001-01"
- `{subject}` for directories like "sub-001"

### 4. Generate Heuristic File

Create a heuristic file based on your DICOM structure:

```bash
04_make_heuristic.sh <setname>
```

This analyzes your DICOM files and creates a customized heuristic file (`code/heuristic_<setname>.py`). Review and adjust the file if needed.

### 5. Convert to BIDS

#### Standard Conversion
For standard datasets:

```bash
05_make_bids.sh <setname>
```

#### Double-Echo Fieldmap Data
For datasets with double-echo fieldmaps:

```bash
05_make_bids_double_echo_fieldmap.sh <setname> [fieldmap_threshold]
```

The `fieldmap_threshold` parameter is optional (default: 78).

## Directory Structure

After running the scripts, your directory structure will look like this:

```
setname/
├── code/
│   └── heuristic_setname.py
├── DICOM/
│   ├── original/     # Original DICOM files
│   ├── sorted/       # Sorted DICOM files
│   └── converted/    # Backup of processed files
├── bids/            # BIDS-formatted output
│   ├── sub-{subject}/
│   └── derivatives/
└── tmp/             # Temporary files
```

## Heuristic File

The heuristic file (`heuristic_setname.py`) defines how your sequences should be converted to BIDS format. While `04_make_heuristic.sh` creates an initial version automatically, you may need to adjust it for your specific needs. Sample heuristic files are provided in the `code` directory.

---

# 日本語説明

## batch-heudiconv とは

DICOMファイルをBIDS形式に変換するためのスクリプト群です。heudiconvを使用して、効率的にデータを変換します。

## 必要なソフトウェア

- **dcm2niix**: [MRIcroGL](https://github.com/rordenlab/MRIcroGL/releases)に含まれています
- **pydicom**: `pip install pydicom`もしくは`conda install pydicom`でインストール
- **heudiconv**: `pip install heudiconv`でインストール

## インストール方法

1. リポジトリのクローン:
```bash
git clone https://github.com/kytk/batch-heudiconv.git
cd batch-heudiconv
```

2. PATHの設定:
```bash
./00_addpath.sh
```

3. 設定を反映させるため、ターミナルを再起動してください。

## 使用方法

変換は5つの主要なステップで構成されています：

### 1. ディレクトリ構造の準備

```bash
01_prep_dir.sh <setname>
```

以下のディレクトリが作成されます：
- `DICOM/original/`: 元のDICOMファイルを配置
- `DICOM/sorted/`: ソートされたDICOMファイル用
- `DICOM/converted/`: 処理済みファイルのバックアップ
- `bids/`: BIDS形式の出力
- `code/`: heuristicファイル用
- `tmp/`: 一時ファイル用

### 2. DICOMファイルのソート

DICOMファイルを`DICOM/original/`に配置した後、以下を実行：

```bash
02_sort_dicom.sh <setname>
```

### 3. 被験者リストの作成

ディレクトリ命名パターンに基づいて被験者リストを生成：

```bash
03_make_subjlist.sh <setname> "<pattern>"
```

パターン例：
- `{subject}_{session}`: "sub-001_01"形式
- `{subject}-{session}`: "sub-001-01"形式
- `{subject}`: "sub-001"形式

### 4. Heuristicファイルの生成

DICOMデータの構造に基づいてheuristicファイルを作成：

```bash
04_make_heuristic.sh <setname>
```

このスクリプトはDICOMファイルを分析し、カスタマイズされたheuristicファイル（`code/heuristic_<setname>.py`）を作成します。必要に応じて内容を確認・調整してください。

### 5. BIDS形式への変換

#### 標準的な変換
通常のデータセット用：

```bash
05_make_bids.sh <setname>
```

#### Double-Echo Fieldmapデータの変換
Double-echo fieldmapを含むデータセット用：

```bash
05_make_bids_double_echo_fieldmap.sh <setname> [fieldmap_threshold]
```

`fieldmap_threshold`はオプションで、デフォルトは78です。

## Heuristicファイル

heuristicファイル（`heuristic_setname.py`）は、各シーケンスをどのようにBIDS形式に変換するかを定義します。`04_make_heuristic.sh`で自動生成された初期バージョンを、必要に応じて調整してください。サンプルファイルが`code`ディレクトリに用意されています。

