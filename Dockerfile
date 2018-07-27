# === DOCKER-SPECIFIC HACKERY ===

# Configure the container's basic properties
FROM debian:stretch
LABEL Description="Environment for the 'CPU Race' GSoC project" Version="0.4"
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

# Install basic software prerequisites
RUN apt-get install --yes cmake git g++ gcc binutils ninja-build               \
                          libopenblas-dev liblapack-dev  libeigen3-dev r-base  \
                          r-cran-ggplot2 time


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
RUN git clone --branch=v1.4.1 --depth=1 https://github.com/google/benchmark.git

# Build google benchmark
RUN cd benchmark && mkdir build && cd build                                    \
    && cmake -GNinja .. && ninja

# Run the tests
RUN cd benchmark/build && ctest -j8

# Install google benchmark
RUN cd benchmark/build && ninja install

# Delete the google benchmark build directory
RUN rm -rf benchmark


# === INSTALL NLOHMANN-JSON ===

# NOTE: As of xtl 0.4.9, xtl does not support the installation location used by
#       the nlohmann-json-dev package from Debian Jessie, nor does it build with
#       that version even if the header path problem is symlinked away. So a
#       custom build seems necessary there.

# Download nlohmann-json
RUN git clone --branch=v3.1.2 https://github.com/nlohmann/json.git nlohmann-json

# Build and run the tests
RUN cd nlohmann-json && mkdir build && cd build                                \
    && cmake -GNinja .. && ninja && ctest -j8 -VV --output-on-failure

# Install nlohmann-json
RUN cd nlohmann-json/build && ninja install

# Delete the nlohmann-json build directory
RUN rm -rf nlohmann-json


# === INSTALL XSIMD ===

# Download xsimd
RUN git clone --branch=6.1.4 https://github.com/QuantStack/xsimd.git

# Build and run the tests
RUN cd xsimd && mkdir build && cd build                                        \
    && cmake -GNinja -DENABLE_FALLBACK=ON ..                                   \
    && ninja xtest

# Build and run the benchmarks
RUN cd xsimd/build  && ninja xbenchmark

# Install xsimd
RUN cd xsimd/build && ninja install


# === INSTALL XTL ===

# Download xtl
RUN git clone --branch=0.4.12 https://github.com/QuantStack/xtl.git

# Build and run the tests
RUN cd xtl && mkdir build && cd build                                          \
    && cmake -DBUILD_TESTS=ON -GNinja .. && ninja && ninja xtest

# Install xtl
RUN cd xtl/build && ninja install


# === INSTALL XTENSOR ===

# Download xtensor
RUN git clone --branch=master https://github.com/QuantStack/xtensor.git

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
RUN git clone --branch=0.11.1 https://github.com/QuantStack/xtensor-blas.git

# Build and run the tests
RUN cd xtensor-blas && mkdir build && cd build                                 \
    && cmake -DBUILD_BENCHMARKS=ON -DBUILD_TESTS=ON -GNinja ..                 \
    && ninja && ninja xtest

# Build and run the benchmarks (currently disabled due to breakage)
# RUN cd xtensor-blas/build && ninja xbenchmark

# Install xtensor-blas
RUN cd xtensor-blas/build && ninja install


# === SETUP THE FAST5X5 SMALL MATRIX LIBRARY ===

# Download the Fast5x5 linear algebra primitives
RUN git clone https://gitlab.in2p3.fr/CodeursIntensifs/Fast5x5.git

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
