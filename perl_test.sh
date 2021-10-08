#!/bin/bash
#-------------------------------------------------------
# This script tests the perl installation
# for the required modules
# If not found or if not up to date
# will install them
#
# NOTE that installint the Tk module this way
# may not enable XFT and the fonts will not look right
# In this case download the latest version of the Tk module
# from CPAN (www.cpan.org), unzip,
# compile and install it manually, like so:
#      cd <Tk_source_directory>
#      perl Makefile.PL XFT=1
#      make
#      sudo make install
#---------------------------------------------------------


#  Abort if not root
if [ $EUID -ne 0 ]; then
  echo "This script must run as root!"
  echo "Aborted!!!"
  exit
fi
cpan Tk File::Slurp Storable


