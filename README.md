# Docker container build recipe for the "CPU race" GSoC project

## Using the pre-built container

To quickly get started in this GSoC project, we have built a Docker container
which features all software which you are expected to need. This container is
available in a pre-built form on the Docker Hub at `TODO`.

Given a working install of Docker on your computer, getting into the container
should be as simple as running the following command:

    docker run --rm -it `TODO`

You can also mount host directories into the container using the -v command line
switch, and with a bit more work, you can also set up X11 forwarding in order to
use graphical applications from inside the container. For more information on
these topics, please refer to the Docker documentation.


## Setting up the development environment on your machine

If you are more experienced with Linux, you will probably want to avoid the
intricacies of Docker and set up a development environment on your own machine.
If so, fear not! For the Dockerfile recipe that we use to build the Docker
container may also, with some adaptations, be used to set up a development
environment on your own machine.

Should you decide to go down this path, here are a couple of compiler
compatibility issues which you should know about early on:

- The software that we are building is known to build on GCC 6.3, but to **fail
  to build** on GCC 7.3. Earlier GCC releases are a question mark, later
  releases of GCC are unfortunately unlikely to work without code adaptations.
- The projects which have known compiler compatibility issues are:
  * **xtl**, which is the base of the xtensor stack. This build failure is due
    to a GCC bug, and should be fixed in an upcoming GCC 7.x release or in
    GCC 8. Which only leaves...
  * **Boost.SIMD**, which is used by the Fast5x5 project. Here, the problem is
    that we are using a forked version of an abandoned software project, which
    contains illegal C++ that only compiled on GCC 6 by chance. So this issue
    will not resolve itself, and the long-term fix is to rewrite the Fast5x5
    code using a different SIMD abstraction layer. Or to obsolete it with an
    xtensor-based solution ;)

TL;DR: If your Linux distribution is based on GCC 6, you can safely proceed. If
it uses GCC 7 or newer, expect some breakage. You will be able to work on the
faulty projects using the Docker image, while doing the rest of the development
on your host system.

Now, how to adapt the Dockerfile recipe to your own system?

- For the most part, a Dockerfile works like a shell script where each RUN
  command is started in a new shell (resetting the environment and working
  directory) and each ENV command sets up a persistent environment variable. You
  can safely ignore the other commands, which are only about containers.
- Docker commands are run in a non-interactive root shell. Therefore, you will
  probably want to adapt some of the recipe to run in user mode. For example,
  environment setup commands should go to your .bash_profile (instead of using
  my rather dreadful SETUP_ENV hack), and commands which modify the host system
  will need to be run as root (using "sudo" or a root shell)
- The system setup section will vary from one Linux distribution to another, and
  even across multiple versions of a given Linux distribution. The package names
  that are provided here are valid for Debian Stretch, and should mostly work on
  later Debian or Ubuntu releases, for other distributions you will need to
  find the proper package names for your system (and possibly install some
  extra packages)
- Some of the builds in this recipe (in particular acts-core) are quite
  RAM-hungry and will merilly eat a little more than 2 GB of RAM per process. If
  your machine has less RAM than that, you may need to tune down the build job
  concurrency, which you can do by passing a -jN flag to ninja.