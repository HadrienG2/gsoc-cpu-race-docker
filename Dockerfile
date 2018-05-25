# === DOCKER-SPECIFIC HACKERY ===

# Configure the container's basic properties
FROM debian:stretch
LABEL Description="Environment for the 'CPU Race' GSoC project" Version="0.2"
CMD bash
SHELL ["/bin/bash", "-c"]

# Build an environment setup script that works during docker build
#
# NOTE: This trickery is necessary because docker build commands are run in a
#       shell which is neither a login shell nor an interactive shell, and
#       cannot be easily turned into either. Which means that there is no clean
#       entry point for running environment setup scripts in docker build.
#
RUN touch /root/setup_env.sh                                                   \
    && echo "unset BASH_ENV" > /root/bash_env.sh                               \
    && echo "source /root/setup_env.sh" >> /root/bash_env.sh                   \
    && echo "source /root/setup_env.sh" >> /root/.bashrc
ENV BASH_ENV="/root/bash_env.sh"                                               \
    SETUP_ENV="/root/setup_env.sh"

# By default, Docker runs commands in the root directory (/). It is cleaner and
# more idiomatic to run them in our home directory (which is /root) instead.
WORKDIR /root


# === SYSTEM SETUP ===

# Update the host system
RUN apt-get update && apt-get upgrade --yes

# Install ROOT's build prerequisites (as remarkably ridiculous as they may be)
RUN apt-get install --yes cmake git dpkg-dev g++ gcc binutils libx11-dev       \
                          libxpm-dev libxft-dev libxext-dev gfortran           \
                          libssl-dev libpcre3-dev libglu1-mesa-dev libglew-dev \
                          libftgl-dev default-libmysqlclient-dev libfftw3-dev  \
                          libcfitsio-dev graphviz-dev                          \
                          libavahi-compat-libdnssd-dev libldap2-dev python-dev \
                          libxml2-dev libkrb5-dev libgsl-dev libqt4-dev        \
                          libgl2ps-dev liblz4-dev liblz4-tool libblas-dev      \
                          python-numpy liblzma-dev libsqlite3-dev libjpeg-dev

# Install other software prerequisites
RUN apt-get install --yes ninja-build libopenblas-dev liblapack-dev            \
                          libboost-all-dev doxygen graphviz libeigen3-dev      \
                          r-base r-cran-ggplot2 time


# === INSTALL INTEL TBB ===

# NOTE: We need a custom build of TBB because the package from Debian Stretch is
#       a bit too old for ROOT's taste.

# Clone TBB v2018u3
RUN git clone --branch=2018_U3 --depth=1 https://github.com/01org/tbb.git

# Build TBB
RUN cd tbb && make -j8

# "Install" TBB (Yes, TBB has nothing like "make install". Ask Intel.)
RUN cd tbb                                                                     \
    && make info | tail -n 1 > tbb_prefix.env                                  \
    && source tbb_prefix.env                                                   \
    && ln -s build/${tbb_build_prefix}_release lib                             \
    && echo "source `pwd`/lib/tbbvars.sh" >> "$SETUP_ENV"


# === INSTALL ROOT ===

# Clone the desired ROOT version
RUN git clone --branch=v6-12-06 --depth=1                                      \
    https://github.com/root-project/root.git ROOT

# Configure a reasonably minimal build of ROOT
RUN cd ROOT && mkdir build-dir && cd build-dir                                 \
    && cmake -Dbuiltin_ftgl=OFF -Dbuiltin_glew=OFF -Dbuiltin_lz4=OFF           \
             -Dcastor=OFF -Dcxx14=ON -Ddavix=OFF -Dfail-on-missing=ON          \
             -Dgfal=OFF -Dgnuinstall=ON -Dhttp=OFF -Dmysql=OFF -Doracle=OFF    \
             -Dpgsql=OFF -Dpythia6=OFF -Dpythia8=OFF -Droot7=ON -Dssl=ON       \
             -Dxrootd=OFF -GNinja ..

# Build and install ROOT
RUN cd ROOT/build-dir && ninja && ninja install

# Prepare the environment for running ROOT
RUN echo "source /usr/local/bin/thisroot.sh" >> "$SETUP_ENV"

# Check that the ROOT install works
RUN root -b -q -e "(6*7)-(6*7)"

# Get rid of the ROOT build directory to save up space
RUN rm -rf ROOT


# === INSTALL GOOGLE TEST ===

# NOTE: For some reason, the QuantStack build scripts cannot detect the google
#       test development packages from Debian Stretch. This should be
#       investigated further, for now I'll just build gtest myself

# Download google test
RUN git clone --branch=release-1.8.0 --depth=1                                 \
              https://github.com/google/googletest.git

# Build google test
RUN cd googletest && mkdir build && cd build                                   \
    && cmake -DBUILD_GTEST=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo                \
             -DBUILD_SHARED_LIBS=ON -Dgmock_build_tests=ON -GNinja ..          \
    && ninja

# Check that our google test build works properly
RUN cd googletest/build && ctest -j8

# Install google test
RUN cd googletest/build && ninja install

# Delete the google test build directory
RUN rm -rf googletest


# === INSTALL GOOGLE BENCHMARK ===

# Download google benchmark
RUN git clone --branch=v1.4.0 --depth=1 https://github.com/google/benchmark.git

# Build google benchmark
RUN cd benchmark && mkdir build && cd build                                    \
    && cmake -GNinja .. && ninja

# Run the tests
RUN cd benchmark/build && ctest -j8

# Install google benchmark
RUN cd benchmark/build && ninja install

# Delete the google benchmark build directory
RUN rm -rf benchmark


# === INSTALL XSIMD ===

# Download xsimd
#
# TODO: Switch back to an official release once necessary changes are merged
#
RUN git clone --branch=master https://github.com/QuantStack/xsimd.git

# Build and run the tests
RUN cd xsimd && mkdir build && cd build                                        \
    && cmake -GNinja -DENABLE_FALLBACK=ON .. && ninja xtest

# Build and run the benchmarks
RUN cd xsimd/build  && ninja xbenchmark

# Install xsimd
RUN cd xsimd/build && ninja install


# === INSTALL XTL ===

# Download xtl
RUN git clone --branch=0.4.7 https://github.com/QuantStack/xtl.git

# Build and run the tests
RUN cd xtl && mkdir build && cd build                                          \
    && cmake -DBUILD_TESTS=ON -GNinja .. && ninja && ninja xtest

# Install xtl
RUN cd xtl/build && ninja install


# === INSTALL XTENSOR ===

# Download xtensor
RUN git clone --branch=0.15.9 https://github.com/QuantStack/xtensor.git

# Build and run the tests
RUN cd xtensor && mkdir build && cd build                                      \
    && cmake -DBUILD_BENCHMARK=ON -DBUILD_TESTS=ON -DDOWNLOAD_GBENCHMARK=OFF   \
             -DXTENSOR_USE_XSIMD=ON -GNinja ..                                 \
    && ninja && ninja xtest

# Build and run the benchmarks (currently disabled due to breakage)
# RUN cd xtensor/build && ninja xbenchmark

# Install xtensor
RUN cd xtensor/build && ninja install


# === INSTALL XTENSOR-BLAS ===

# Download xtensor-blas
RUN git clone --branch=0.10.1 https://github.com/QuantStack/xtensor-blas.git

# Build and run the tests
RUN cd xtensor-blas && mkdir build && cd build                                 \
    && cmake -DBUILD_BENCHMARKS=ON -DBUILD_TESTS=ON -GNinja ..                 \
    && ninja && ninja xtest

# Build and run the benchmarks (currently disabled due to breakage)
# RUN cd xtensor-blas/build && ninja xbenchmark

# Install xtensor-blas
RUN cd xtensor-blas/build && ninja install


# === INSTALL ACTS-CORE ===

# Clone the current version of ACTS' core library
RUN git clone https://gitlab.cern.ch/acts/acts-core.git

# Configure a (mostly) full-featured build of core ACTS
RUN cd acts-core && mkdir build && cd build                                    \
    && cmake -GNinja -DEIGEN_PREFER_EXPORTED_EIGEN_CMAKE_CONFIGURATION=FALSE   \
             -DACTS_BUILD_EXAMPLES=ON -DACTS_BUILD_INTEGRATION_TESTS=ON        \
             -DACTS_BUILD_MATERIAL_PLUGIN=ON -DACTS_BUILD_TGEO_PLUGIN=ON       \
             -DCMAKE_BUILD_TYPE=RelWithDebInfo ..

# Build the core ACTS library
RUN cd acts-core/build && ninja

# Run the unit tests to check if everything is alright
RUN cd acts-core/build && ctest -j8

# Install the core ACTS library
RUN cd acts-core/build && ninja install


# === INSTALL ACTS-FRAMEWORK ===

# TODO: Most ACTS integration tests live in the acts-framework repository, which
#       provides a Gaudi-like test environment. However, this repository is
#       momentarily unavailable to people without CERN credentials, as it
#       depends on another private repo. Therefore, we are not yet able to
#       provide a Docker-friendly build recipe for this package.


# === SETUP THE FAST5X5 SMALL MATRIX LIBRARY ===

# Download the Fast5x5 linear algebra primitives
#
# TODO: Switch to an official release once all changes are merged
#
RUN git clone --branch=xsimd https://gitlab.in2p3.fr/grasland/Fast5x5

# Build the linear algebra primitives
RUN cd Fast5x5 && mkdir build && cd build                                      \
    && cmake .. && make -j8

# Run the tests
RUN cd Fast5x5/build && ./test/unit_tests

# Run the benchmarks
RUN cd Fast5x5 && bash measure_perf.sh                                         \
    && cd benchmark && bash benchmark.sh

# Analyze the benchmark's results
RUN cd Fast5x5 && Rscript analysis.R


# === FINAL CLEAN UP ===

# Clean up the APT cache
RUN apt-get clean
