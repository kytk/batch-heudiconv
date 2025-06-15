FROM ubuntu:22.04 as base

# Metadata
LABEL maintainer="batch-heudiconv"
LABEL description="Docker container for batch-heudiconv: DICOM to BIDS conversion tools"
LABEL version="2.1"

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
    # User management
    sudo \
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

# ==============================================
# Stage 1: Copy local files (default method)
# ==============================================
FROM base as copy-stage

# Copy batch-heudiconv scripts from local directory
COPY . /opt/batch-heudiconv/

# ==============================================
# Stage 2: Clone from Git repository
# ==============================================
FROM base as git-stage

# Build arguments for Git method
ARG GIT_REPO=https://github.com/kytk/batch-heudiconv.git
ARG GIT_BRANCH=main

# Clone the repository
RUN git clone --depth 1 --branch ${GIT_BRANCH} ${GIT_REPO} /opt/batch-heudiconv

# ==============================================
# Final stage: Choose method based on build arg
# ==============================================
FROM base as final

# Build argument to choose the method
ARG BUILD_METHOD=copy

# Copy files from the appropriate stage
COPY --from=copy-stage /opt/batch-heudiconv /tmp/copy-method/
COPY --from=git-stage /opt/batch-heudiconv /tmp/git-method/

# Select the appropriate source based on BUILD_METHOD
RUN if [ "$BUILD_METHOD" = "git" ]; then \
        cp -r /tmp/git-method/* /opt/batch-heudiconv/ && \
        echo "Using Git method (latest from repository)"; \
    else \
        cp -r /tmp/copy-method/* /opt/batch-heudiconv/ && \
        echo "Using Copy method (local files)"; \
    fi && \
    rm -rf /tmp/copy-method /tmp/git-method

# Set executable permissions for scripts
RUN chmod +x /opt/batch-heudiconv/bh*.sh \
    && chmod +x /opt/batch-heudiconv/bh*.py 

# Add to PATH
ENV PATH="/opt/batch-heudiconv:${PATH}"

# ==============================================
# User Management Setup
# ==============================================

# Build arguments for user configuration
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USERNAME=batchuser

# Create group and user
RUN groupadd -g ${GROUP_ID} ${USERNAME} && \
    useradd -u ${USER_ID} -g ${GROUP_ID} -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up PATH for batchuser
RUN echo 'export PATH="/opt/batch-heudiconv:$PATH"' >> /home/${USERNAME}/.bashrc && \
    chown ${USERNAME}:${USERNAME} /home/${USERNAME}/.bashrc

# Create data directory and set ownership
RUN mkdir -p /data && \
    chown -R ${USERNAME}:${USERNAME} /data && \
    chown -R ${USERNAME}:${USERNAME} /opt/batch-heudiconv

# Copy the entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set working directory to /data
WORKDIR /data

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 --version && dcm2niix -h > /dev/null || exit 1

# Switch to non-root user (simplest approach)
USER ${USERNAME}

# Use simple entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command
CMD ["/bin/bash"]

# Add usage instructions as labels
LABEL usage.basic="docker run -it --rm -v \$(pwd):/data batch-heudiconv:latest"
LABEL usage.with-user="docker run -it --rm -v \$(pwd):/data -e HOST_UID=\$(id -u) -e HOST_GID=\$(id -g) batch-heudiconv:latest"
LABEL usage.build="docker build -t batch-heudiconv ."
LABEL usage.build-custom-user="docker build --build-arg USER_ID=\$(id -u) --build-arg GROUP_ID=\$(id -g) -t batch-heudiconv ."
