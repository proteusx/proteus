#!/bin/bash

#--------------------------------------------------------
#  Test the Tex installation
#--------------------------------------------------------
test_tex="test.tex"

#  Only run as user
#  Abort if root
if [ $EUID -eq 0 ]; then
  echo "This script must not run as root!"
  echo "Aborted!!!"
  exit
fi
#-------------------------------------------------------------


# Pass test file through xetex
# and sent pdf to books subdir

# xelatex -interaction=batchmode $test_tex &> /dev/null
latexmk -xelatex -interaction=batchmode $test_tex &> /dev/null



# Display test pdf if exists else signal error
# xdg-open opens default pdf viewer

if [ -e  test.pdf ]; then
  xdg-open test.pdf
  rm -f test.{aux,fdb_latexmk,fls,log,xdv}
else
  echo "**** Error!"
  echo "test.pdf was not produced!"
  echo "Something is wrong with your TeX installation."
  echo "For more information see the file: test.log' "
  echo "Fix TeX and try again"
fi



