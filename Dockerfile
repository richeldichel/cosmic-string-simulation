# Use Ubuntu 22 as the base image
FROM ubuntu:22.04

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    wget

# Install libffi and libgslc and pkg-config and nano and gnuplot and ffmpeg
RUN apt-get install -y libffi-dev libgsl-dev pkg-config nano sudo gnuplot ffmpeg git

# Download and install SBCL

RUN wget https://downloads.sourceforge.net/project/sbcl/sbcl/2.1.11/sbcl-2.1.11-x86-64-linux-binary.tar.bz2 \
    && tar -xvf sbcl-2.1.11-x86-64-linux-binary.tar.bz2 \
    && cd sbcl-2.1.11-x86-64-linux \
    && sh install.sh
# Install quicklisp
RUN wget https://beta.quicklisp.org/quicklisp.lisp \
    && sbcl --load quicklisp.lisp --eval '(quicklisp-quickstart:install)' --eval '(quit)'

# Set the working directory
WORKDIR /home

RUN git clone https://github.com/richeldichel/cosmic-string-simulation.git
# Go into cosmic-string-simulation directory
WORKDIR /home/cosmic-string-simulation


# Start sbcl and compile
# RUN sbcl --load "load.lisp" --eval "(quit)"
# CMD ["sbcl", "(load 'load')"]
# ```







