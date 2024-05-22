# Use the NVIDIA PyTorch container for Jetson as the base image
FROM nvcr.io/nvidia/pytorch:23.04-py3

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    lsb-release \
    gnupg2 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set the timezone environment variable to a European timezone, e.g., Europe/Athens
ENV TZ=Europe/Athens

# Install tzdata
RUN apt-get update && \
    apt-get install -y tzdata && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Ensure the container can utilize the GPU
LABEL com.nvidia.volumes.needed="nvidia_driver"
LABEL com.nvidia.cuda.version="${CUDA_VERSION}"
LABEL com.nvidia.cudnn.version="${CUDNN_VERSION}"

ENV INSTALLATION_PATH="/workspace"

# OpenCV Setup
ARG SELECT_OPENCV_VERSION=4.9.0
ARG SELECT_CUDA_ARCH_BIN=8.7
ARG SELECT_CUDNN_VERSION=8.9
# Depentacies
RUN apt-get update && apt-get install -y \ 
    build-essential \
    cmake \
    unzip \
    pkg-config \
    libxmu-dev \
    libxi-dev \
    libglu1-mesa \
    libglu1-mesa-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libv4l-dev \
    libxvidcore-dev \
    libx264-dev \
    libopenblas-dev \
    libatlas-base-dev \
    liblapack-dev \
    gfortran \
    libhdf5-serial-dev \
    python3-dev \
    python3-tk \
    libgtk-3-dev

# Build OpenCV
WORKDIR ${INSTALLATION_PATH}
RUN wget https://github.com/opencv/opencv/archive/${SELECT_OPENCV_VERSION}.zip && \
    unzip ${SELECT_OPENCV_VERSION}.zip && rm ${SELECT_OPENCV_VERSION}.zip && \
    mv opencv-${SELECT_OPENCV_VERSION} OpenCV && \
    wget https://github.com/opencv/opencv_contrib/archive/${SELECT_OPENCV_VERSION}.zip && \
    unzip ${SELECT_OPENCV_VERSION}.zip && rm ${SELECT_OPENCV_VERSION}.zip && \
    mv opencv_contrib-${SELECT_OPENCV_VERSION} OpenCV/opencv_contrib

# If you have issues with GStreamer, set -DWITH_GSTREAMER=OFF and -DWITH_FFMPEG=ON
WORKDIR ${INSTALLATION_PATH}/OpenCV/build
RUN cmake \
    -D OPENCV_EXTRA_MODULES_PATH=${INSTALLATION_PATH}/OpenCV/opencv_contrib/modules \
    -D INSTALL_PYTHON_EXAMPLES=ON \
    -D WITH_CUDA=ON \
    -D CUDA_ARCH_BIN=${SELECT_CUDA_ARCH_BIN} \
    -D WITH_CUDNN=ON \
    -D CUDA_ARCH_PTX="" \
    -D CUDNN_VERSION=${SELECT_CUDNN_VERSION} \
    -D OPENCV_DNN_CUDA=ON \
    -D BUILD_EXAMPLES=OFF \ 
    -D CMAKE_BUILD_TYPE=RELEASE \
    -D CUDA_FAST_MATH=ON \
    -D WITH_CUBLAS=ON \
    -D INSTALL_C_EXAMPLES=OFF \
    -D BUILD_opencv_python2=OFF \
    -D BUILD_TESTS=OFF \
    -D BUILD_PERF_TESTS=OFF \
    -D ENABLE_FAST_MATH=ON \    
    -D WITH_OPENGL=ON \
    -D WITH_TBB=ON \
    -D WITH_V4l=YES \
    -D WITH_GSTREAMER=ON\
    -D WITH_LIBV4L=ON \
    -D WITH_GSTREAMER_0_10=OFF \
    -D WITH_FFMPEG=ON \
    # Install path will be /usr/local/lib (lib is implicit)
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D PYTHON3_PACKAGES_PATH=/usr/lib/python3/dist-packages \
    ..

# Make with max CPU cores
RUN make -j$(nproc)

# Install to /usr/local/lib
RUN make install && \
    ldconfig

RUN rm -rf ${INSTALLATION_PATH}/OpenCV && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get autoremove

