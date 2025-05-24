# batch-heudiconv Docker Environment

This Docker container provides a complete environment for running batch-heudiconv, a set of tools for converting DICOM files to BIDS format using heudiconv.

## Prerequisites

- Docker Engine 20.10 or higher

## Quick Start

### 1. Pull the Docker Image

```bash
docker pull kytk/batch-heudiconv:latest
```

### 2. Run the Container

```bash
# Navigate to your working directory
cd /path/to/your/working/directory

# Start the container with interactive shell
docker run -it --rm -v $(pwd):/data kytk/batch-heudiconv:latest
```

### 3. Basic Workflow

Inside the container, follow the standard batch-heudiconv workflow:

```bash
# Prepare directory structure
bh01_prep_dir.sh MR001

# Place your DICOM files in MR001/DICOM/original/
# Then sort DICOM files
bh02_sort_dicom.sh MR001

# Create subject list
bh03_make_subjlist.sh MR001 {subject}

# Generate and customize heuristic file
bh04_make_heuristic.sh MR001
# Edit the heuristic file as needed: MR001/code/heuristic_MR001.py

# Convert to BIDS format
bh05_make_bids.sh MR001
```

## Advanced Usage

### Running Single Commands

You can execute individual commands without entering the interactive shell:

```bash
# Prepare directory structure
docker run --rm -v $(pwd):/data kytk/batch-heudiconv:latest bh01_prep_dir.sh MR001

# Sort DICOM files
docker run --rm -v $(pwd):/data kytk/batch-heudiconv:latest bh02_sort_dicom.sh MR001
```

### Running Multiple Commands

```bash
docker run --rm -v $(pwd):/data kytk/batch-heudiconv:latest bash -c "
  bh01_prep_dir.sh MR001 && \
  bh02_sort_dicom.sh MR001 && \
  bh03_make_subjlist.sh MR001 {subject} && \
  bh05_05_make_bids.sh MR01
"
```

### Preserving File Ownership

To ensure files created inside the container have the same ownership as your host user:

```bash
docker run -it --rm -v $(pwd):/data --user $(id -u):$(id -g) kytk/batch-heudiconv:latest
```

### Memory and Resource Management

For processing large DICOM datasets:

```bash
docker run -it --rm -v $(pwd):/data --memory=8g --cpus=4 kytk/batch-heudiconv:latest
```

## Directory Structure

The container expects your working directory to contain:

```
your-working-directory/
├── MR001/                    # Your dataset (created by bh01_prep_dir.sh)
│   ├── DICOM/
│   │   ├── original/         # Place your DICOM files here
│   │   ├── sorted/           # Sorted DICOM files (created automatically)
│   │   └── converted/        # Backup of processed files
│   ├── bids/                 # BIDS output
│   ├── code/                 # Heuristic files
│   └── tmp/                  # Temporary files
└── other-datasets/           # Additional datasets if needed
```

## Installed Software

- Ubuntu 22.04
- Python 3.10
- dcm2niix (latest version)
- Essential Python packages:
  - pydicom
  - numpy
  - pandas
  - gdcm
  - heudiconv
  - nibabel
  - matplotlib
  - jsonschema

## Troubleshooting

### Permission Issues

If you encounter permission issues with created files:

```bash
# Use --user flag to match host user
docker run -it --rm -v $(pwd):/data --user $(id -u):$(id -g) kytk/batch-heudiconv:latest

# Or fix permissions after processing
sudo chown -R $(id -u):$(id -g) your-dataset-directory
```

### Memory Issues

For large datasets, increase memory allocation:

```bash
docker run -it --rm -v $(pwd):/data --memory=16g kytk/batch-heudiconv:latest
```

### Debug Mode

To troubleshoot issues, run scripts in debug mode:

```bash
docker run --rm -v $(pwd):/data kytk/batch-heudiconv:latest bash -x bh05_make_bids.sh MR001
```

### Volume Mount Issues

Ensure your working directory path is absolute:

```bash
# Good
docker run -it --rm -v $(pwd):/data kytk/batch-heudiconv:latest

# Also good
docker run -it --rm -v /full/path/to/directory:/data kytk/batch-heudiconv:latest
```

## Building the Image Locally

If you need to build the image yourself:

```bash
git clone https://github.com/kytk/batch-heudiconv.git
cd batch-heudiconv
docker build -t batch-heudiconv .
```

## Important Notes

1. **Data Privacy**: DICOM files may contain personal information. Ensure appropriate security measures are in place.
2. **Storage Requirements**: Ensure sufficient disk space for both original DICOM files and converted BIDS data.
3. **Heuristic Customization**: The heuristic file (`code/heuristic_<setname>.py`) typically requires customization for each dataset.
4. **BIDS Validation**: Always validate your output using the BIDS Validator after conversion.

## Examples

### Complete Workflow Example

```bash
# Create and navigate to working directory
mkdir ~/dicom-conversion && cd ~/dicom-conversion

# Start container
docker run -it --rm -v $(pwd):/data kytk/batch-heudiconv:latest

# Inside container:
bh01_prep_dir.sh MyStudy
# Copy DICOM files to MyStudy/DICOM/original/
bh02_sort_dicom.sh MyStudy
bh03_make_subjlist.sh MyStudy "{subject}_{session}"
# Edit MyStudy/code/heuristic_MyStudy.py as needed
bh05_make_bids.sh MyStudy
```

### Batch Processing Multiple Datasets

```bash
for dataset in Dataset1 Dataset2 Dataset3; do
  docker run --rm -v $(pwd):/data kytk/batch-heudiconv:latest bash -c "
    bh02_sort_dicom.sh $dataset && \
    bh03_make_subjlist.sh $dataset '{subject}_{session}' && \
    bh05_make_bids.sh $dataset
  "
done
```

## Support

For issues related to:
- **batch-heudiconv**: Check the [main repository](https://github.com/kytk/batch-heudiconv)
- **heudiconv**: Visit the [heudiconv documentation](https://heudiconv.readthedocs.io/)
- **BIDS**: Refer to the [BIDS specification](https://bids-specification.readthedocs.io/)

---

# batch-heudiconv Docker環境

このDockerコンテナは、heudiconvを使用してDICOMファイルをBIDS形式に変換するためのツール群「batch-heudiconv」の完全な実行環境を提供します。

## 前提条件

- Docker Engine 20.10以上

## クイックスタート

### 1. Dockerイメージの取得

```bash
docker pull kytk/batch-heudiconv:latest
```

### 2. コンテナの実行

```bash
# 作業ディレクトリに移動
cd /path/to/your/working/directory

# インタラクティブシェルでコンテナを起動
docker run -it --rm -v $(pwd):/data kytk/batch-heudiconv:latest
```

### 3. 基本的なワークフロー

コンテナ内で、標準的なbatch-heudiconvワークフローを実行：

```bash
# ディレクトリ構造の準備
bh01_prep_dir.sh MR001

# DICOMファイルをMR001/DICOM/original/に配置してから
# DICOMファイルのソート
bh02_sort_dicom.sh MR001

# 被験者リストの作成
bh03_make_subjlist.sh MR001 {subject}

# heuristicファイルの生成とカスタマイズ
bh04_make_heuristic.sh MR001
# 必要に応じてheuristicファイルを編集: MR001/code/heuristic_MR001.py

# BIDS形式への変換
bh05_make_bids.sh MR001
```

## 高度な使用方法

### 単一コマンドの実行

インタラクティブシェルに入らずに個別のコマンドを実行：

```bash
# ディレクトリ構造の準備
docker run --rm -v $(pwd):/data kytk/batch-heudiconv:latest bh01_prep_dir.sh MR001

# DICOMファイルのソート
docker run --rm -v $(pwd):/data kytk/batch-heudiconv:latest bh02_sort_dicom.sh MR001
```

### 複数コマンドの実行

```bash
docker run --rm -v $(pwd):/data kytk/batch-heudiconv:latest bash -c "
  bh01_prep_dir.sh MR001 && \
  bh02_sort_dicom.sh MR001 && \
  bh03_make_subjlist.sh MR001 {subject} && \
  bh05_make_bids.sh MR001
"
```

### ファイル所有権の保持

コンテナ内で作成されるファイルがホストユーザーと同じ所有権を持つようにする：

```bash
docker run -it --rm -v $(pwd):/data --user $(id -u):$(id -g) kytk/batch-heudiconv:latest
```

### メモリとリソース管理

大きなDICOMデータセットを処理する場合：

```bash
docker run -it --rm -v $(pwd):/data --memory=8g --cpus=4 kytk/batch-heudiconv:latest
```

## ディレクトリ構造

コンテナは作業ディレクトリに以下の構造を想定：

```
your-working-directory/
├── MR001/                    # データセット（bh01_prep_dir.shで作成）
│   ├── DICOM/
│   │   ├── original/         # DICOMファイルをここに配置
│   │   ├── sorted/           # ソート済みDICOMファイル（自動作成）
│   │   └── converted/        # 処理済みファイルのバックアップ
│   ├── bids/                 # BIDS出力
│   ├── code/                 # heuristicファイル
│   └── tmp/                  # 一時ファイル
└── other-datasets/           # 必要に応じて追加のデータセット
```

## インストール済みソフトウェア

- Ubuntu 22.04
- Python 3.10
- dcm2niix（最新版）
- 必須Pythonパッケージ：
  - pydicom
  - numpy
  - pandas
  - gdcm
  - heudiconv
  - nibabel
  - matplotlib
  - jsonschema

## トラブルシューティング

### 権限の問題

作成されたファイルの権限に問題がある場合：

```bash
# ホストユーザーと一致させるために--userフラグを使用
docker run -it --rm -v $(pwd):/data --user $(id -u):$(id -g) kytk/batch-heudiconv:latest

# または処理後に権限を修正
sudo chown -R $(id -u):$(id -g) your-dataset-directory
```

### メモリの問題

大きなデータセットの場合、メモリ割り当てを増やす：

```bash
docker run -it --rm -v $(pwd):/data --memory=16g kytk/batch-heudiconv:latest
```

### デバッグモード

問題のトラブルシューティングのため、スクリプトをデバッグモードで実行：

```bash
docker run --rm -v $(pwd):/data kytk/batch-heudiconv:latest bash -x bh05_make_bids.sh MR001
```

### ボリュームマウントの問題

作業ディレクトリのパスが絶対パスであることを確認：

```bash
# 良い例
docker run -it --rm -v $(pwd):/data kytk/batch-heudiconv:latest

# これも良い例
docker run -it --rm -v /full/path/to/directory:/data kytk/batch-heudiconv:latest
```

## ローカルでのイメージビルド

自分でイメージをビルドする必要がある場合：

```bash
git clone https://github.com/kytk/batch-heudiconv.git
cd batch-heudiconv
docker build -t batch-heudiconv .
```

## 重要な注意事項

1. **データプライバシー**: DICOMファイルには個人情報が含まれている可能性があります。適切なセキュリティ対策を講じてください。
2. **ストレージ要件**: 元のDICOMファイルと変換されたBIDSデータの両方に十分なディスク容量を確保してください。
3. **heuristicのカスタマイズ**: heuristicファイル（`code/heuristic_<setname>.py`）は通常、各データセットに応じてカスタマイズが必要です。
4. **BIDS検証**: 変換後は必ずBIDS Validatorを使用して出力を検証してください。

## 使用例

### 完全なワークフロー例

```bash
# 作業ディレクトリを作成して移動
mkdir ~/dicom-conversion && cd ~/dicom-conversion

# コンテナを起動
docker run -it --rm -v $(pwd):/data kytk/batch-heudiconv:latest

# コンテナ内で：
bh01_prep_dir.sh MyStudy
# DICOMファイルをMyStudy/DICOM/original/にコピー
bh02_sort_dicom.sh MyStudy
bh03_make_subjlist.sh MyStudy "{subject}_{session}"
# 必要に応じてMyStudy/code/heuristic_MyStudy.pyを編集
bh05_make_bids.sh MyStudy
```

### 複数データセットのバッチ処理

```bash
for dataset in Dataset1 Dataset2 Dataset3; do
  docker run --rm -v $(pwd):/data kytk/batch-heudiconv:latest bash -c "
    bh02_sort_dicom.sh $dataset && \
    bh03_make_subjlist.sh $dataset '{subject}_{session}' && \
    bh05_make_bids.sh $dataset
  "
done
```

## サポート

以下に関する問題について：
- **batch-heudiconv**: [メインリポジトリ](https://github.com/kytk/batch-heudiconv)を確認
- **heudiconv**: [heudiconvドキュメント](https://heudiconv.readthedocs.io/)を参照
- **BIDS**: [BIDS仕様](https://bids-specification.readthedocs.io/)を参照
