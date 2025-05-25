#!/bin/bash
# build-docker.sh - Simplified Docker build script for batch-heudiconv
# K.Nemoto 2025

set -e

show_usage() {
    echo "Build batch-heudiconv Docker image with different methods"
    echo ""
    echo "Usage: $0 [METHOD] [OPTIONS]"
    echo ""
    echo "Methods:"
    echo "  copy        Build from local files (default, stable)"
    echo "  git         Build from GitHub repository (latest)"
    echo "  git-dev     Build from development branch"
    echo ""
    echo "Options:"
    echo "  -t, --tag TAG    Specify custom image tag"
    echo "  -b, --branch     Specify Git branch (for git method)"
    echo "  -r, --repo       Specify Git repository URL"
    echo "  -h, --help       Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                           # Build stable version from local files"
    echo "  $0 copy                      # Same as above"
    echo "  $0 git                       # Build latest from GitHub main branch"
    echo "  $0 git-dev                   # Build from development branch"
    echo "  $0 git -t my-batch-heudiconv # Custom tag"
    echo "  $0 git -b feature-branch     # Specific branch"
    echo ""
}

# Default values
METHOD="copy"
TAG="batch-heudiconv:latest"
GIT_BRANCH="main"
GIT_REPO="https://github.com/kytk/batch-heudiconv.git"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        copy|git|git-dev)
            METHOD="$1"
            shift
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -b|--branch)
            GIT_BRANCH="$2"
            shift 2
            ;;
        -r|--repo)
            GIT_REPO="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Adjust settings based on method
case $METHOD in
    "copy")
        BUILD_METHOD="copy"
        echo "Building batch-heudiconv from local files..."
        echo "   Tag: $TAG"
        ;;
    "git")
        BUILD_METHOD="git"
        echo "Building batch-heudiconv from Git repository..."
        echo "   Repository: $GIT_REPO"
        echo "   Branch: $GIT_BRANCH"
        echo "   Tag: $TAG"
        ;;
    "git-dev")
        BUILD_METHOD="git"
        GIT_BRANCH="develop"
        TAG="batch-heudiconv:dev"
        echo "Building batch-heudiconv development version..."
        echo "   Repository: $GIT_REPO"
        echo "   Branch: $GIT_BRANCH"
        echo "   Tag: $TAG"
        ;;
esac

echo ""

# Build Docker image
if [[ $BUILD_METHOD == "git" ]]; then
    docker build \
        --build-arg BUILD_METHOD=git \
        --build-arg GIT_REPO="$GIT_REPO" \
        --build-arg GIT_BRANCH="$GIT_BRANCH" \
        -t "$TAG" \
        .
else
    docker build \
        --build-arg BUILD_METHOD=copy \
        -t "$TAG" \
        .
fi

# Check build success
if [[ $? -eq 0 ]]; then
    echo ""
    echo "Successfully built: $TAG"
    echo ""
    echo "Test the image:"
    echo "  docker run --rm $TAG bh01_prep_dir.sh --help"
    echo ""
    echo "Start interactive session:"
    echo "  docker run -it --rm -v \$(pwd):/data $TAG"
else
    echo ""
    echo "Build failed!"
    exit 1
fi
