#!/bin/bash

###############################################################################
# Execution                                                                   #
###############################################################################

# This file executes all the configuration files.

# Full path of the current script
THIS=`readlink -f "${BASH_SOURCE[0]}" 2>/dev/null||echo $0`

# The directory where current script resides
DIR=`dirname "${THIS}"`

# 'Dot' means 'source', i.e. 'include':

echo "Running the bash configuration script..."

. "$DIR/.bash_profile"

echo "Running the alias configuration script..."

. "$DIR/.alias"

echo "Running the macOS configuration script..."

. "$DIR/.macos"

echo "Running the configuration script..."

. "$DIR/config.sh"

echo "Running the script to configure Homebrew..."

. "$DIR/brew.sh"