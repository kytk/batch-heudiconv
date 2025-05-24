FROM ubuntu:22.04

# Metadata
LABEL maintainer="batch-heudiconv"
LABEL description="Docker container for batch-heudiconv: DICOM to BIDS conversion tools"
LABEL version="1.0"

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install basic packages and Python environment
RUN apt-get update && apt-get install -y \
    # Basic tools
    wget \
    curl \
    git \
    unzip \
    build-essential \
    # Python related
    python3 \
    python3-pip \
    python3-dev \
    # DICOM processing packages
    dcmtk \
    # Other utilities
    tree \
    vim \
    less \
    && rm -rf /var/lib/apt/lists/*

# Install dcm2niix (latest version)
RUN wget -O /tmp/dcm2niix.zip \
    "https://github.com/rordenlab/dcm2niix/releases/latest/download/dcm2niix_lnx.zip" \
    && unzip /tmp/dcm2niix.zip -d /tmp/ \
    && mv /tmp/dcm2niix /usr/local/bin/ \
    && chmod +x /usr/local/bin/dcm2niix \
    && rm /tmp/dcm2niix.zip

# Install Python packages
RUN pip3 install --no-cache-dir \
    # Essential packages
    pydicom \
    numpy \
    pandas \
    # GDCM (DICOM library)
    gdcm \
    # heudiconv
    heudiconv \
    # Other useful packages
    matplotlib \
    nibabel \
    # JSON processing
    jsonschema

# Create working directory
WORKDIR /opt/batch-heudiconv

# Copy batch-heudiconv scripts
COPY . /opt/batch-heudiconv/

# Set executable permissions for scripts
RUN chmod +x /opt/batch-heudiconv/bh*.sh \
    && chmod +x /opt/batch-heudiconv/bh*.py 

# Add to PATH
ENV PATH="/opt/batch-heudiconv:${PATH}"

# Create data directory
RUN mkdir -p /data

# Set working directory to /data
WORKDIR /data

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 --version && dcm2niix -h > /dev/null || exit 1

# Default command
CMD ["/bin/bash"]

# Add usage instructions as labels
LABEL usage="docker run -it --rm -v \$(pwd):/data kytk/batch-heudiconv:latest"
LABEL examples="docker run -it --rm -v \$(pwd):/data kytk/batch-heudiconv:latest bh01_prep_dir.sh MR001"
