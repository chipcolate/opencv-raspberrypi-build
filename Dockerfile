ARG OPENCV_VERSION="4.2.0"
ARG PYTHON_VERSION="3.8.1"
## buildstep base image
FROM balenalib/raspberrypi3-debian-python:${PYTHON_VERSION}-build as buildstep
ARG OPENCV_VERSION
ARG PYTHON_VERSION

## install required packages
RUN apt-get update && apt-get install -yq --no-install-recommends \
  file \
  cmake \
  git \
  wget \
  unzip \
  yasm \
  libtbb2 \
  libtbb-dev \
  libjpeg-dev \
  libpng-dev \
  libtiff-dev \
  libpq-dev \
  libsdl-image1.2-dev \
  libsdl-mixer1.2-dev \
  libsdl-ttf2.0-dev \
  libsdl1.2-dev \
  libsmpeg-dev \
  subversion \
  libportmidi-dev \
  ffmpeg \
  libswscale-dev \
  libavformat-dev \
  libavcodec-dev \
  libfreetype6-dev \
  libzbar-dev \
  libopencv-dev \
  wiringpi

WORKDIR /usr/src/app

COPY ./requirements.txt ./
RUN pip3 install --user -r requirements.txt

# Install OPENCV
RUN wget -O opencv.zip https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip \
&& unzip opencv.zip \
&& wget -O opencv_contrib.zip \
  https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip \
&& unzip opencv_contrib.zip && cd opencv-${OPENCV_VERSION} && mkdir build \
&& cd build && cmake \
    -D CMAKE_BUILD_TYPE=RELEASE \
    -D OPENCV_GENERATE_PKGCONFIG=ON \
    -D PYTHON_EXECUTABLE=$(which python${PYTHON_VERSION}) \
    -D PYTHON_INCLUDE_DIR=$(python${PYTHON_VERSION} -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
    -D PYTHON_PACKAGES_PATH=$(python${PYTHON_VERSION} -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
		-D INSTALL_C_EXAMPLES=OFF \
		-D BUILD_PYTHON_SUPPORT=ON \
		-D BUILD_NEW_PYTHON_SUPPORT=ON \
		-D INSTALL_PYTHON_EXAMPLES=OFF \
    -D BUILD_TESTS=OFF \
    -D BUILD_PERF_TESTS=OFF \
    -D CPACK_BINARY_DEB=ON \
    -D CMAKE_SHARED_LINKER_FLAGS=-latomic \
    -D OPENCV_ENABLE_NONFREE=ON \
    -D BUILD_TESTS=OFF \
    -D ENABLE_NEON=ON \
    -D ENABLE_VFPV3=ON \
    -D WITH_CUDA=OFF \
		-D OPENCV_EXTRA_MODULES_PATH=/usr/src/app/opencv_contrib-${OPENCV_VERSION}/modules \
		-D BUILD_EXAMPLES=OFF .. \
&& make -j 16 && make install && make package

## commodity image for exposing the opencv artifacts with a webserver
FROM balenalib/raspberrypi3-node:12-run
ARG OPENCV_VERSION
ARG PYTHON_VERSION

RUN JOBS=MAX npm install --unsafe-perm --production -g http-server

WORKDIR /usr/src/app

# Gather opencv artifacts
COPY --from=buildstep /usr/src/app/opencv-${OPENCV_VERSION}/build/ /usr/src/app/opencv/
COPY ./start.sh ./

CMD ["bash", "/usr/src/app/start.sh"]
