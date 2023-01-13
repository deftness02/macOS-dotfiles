#!/usr/bin/env bash

###############################################################################
# Homebrew Configuration Script                                               #
###############################################################################
#
# This file is based largely upon the efforts of:
# ~/.macos — https://mths.be/macos
#
# See my repo readme for more credits:
# https://github.com/leftygamer02/macOS-dotfiles
#
# The purpose of this script is to install helpful command-line (CLI)
# tools through the use of our favorite package manager, Homebrew.

###############################################################################
# Initial Setup                                                               #
###############################################################################

echo "Starting setup"
xcode-select --install

# Check for Homebrew to be present, install if it's missing.
if test ! $(which brew); then
    echo "Installing homebrew..."
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Now let's make sure the latest version is in use.
brew update

# In case of any already-installed formulae, force an upgrade.
brew upgrade

# For the convenience of this script's purposes, we'll now retain
# Homebrew’s installation location.
brewPrefix=$(brew --prefix)

###############################################################################
# Installing Packages                                                         #
###############################################################################

# Because the core utilities included with macOS are often outdated, we'll
# now install things associated with GNU and such.
brew install coreutils
ln -s "${brewPrefix}/bin/gsha256sum" "${brewPrefix}/bin/sha256sum"
# Once this script is complete, make sure that you add the following to your
# `$PATH`: `$(brew --prefix coreutils)/libexec/gnubin`

# Time to install some more useful utilities. Explanations included for each.
# This nets you `sponge`, a utility that soaks up standard input and writes
# it to a file.
brew install moreutils

# This nets you `find`, `locate`, `updatedb`, and `xargs`
# `find`- Locates files based on a directory hierarchy.
# `locate` - Lists files from databases with matching patterns.
# `updatedb` -  Updates database file names.
# `xargs` - Builds and executes CLIs from standard inputs.
brew install findutils

# Overwrite the current built-in `sed` with GNU's `sed`.
# `gnu-sed` - Provides a non-interactive command-line text editor.
brew install gnu-sed --with-default-names

# Now let's use a more modern version of bash.
brew install bash
brew install bash-completion2

# This switches the system to now use Homebrew's version of bash 
# instead of the existing version on macOS.
if ! grep -F -q "${brewPrefix}/bin/bash" /etc/shells; then
  echo "${brewPrefix}/bin/bash" | sudo tee -a /etc/shells;
  chsh -s "${brewPrefix}/bin/bash";
fi;

# This installs `wget`, but includes internationalized URI (IRI) support.
brew install wget --with-iri

# If you currently use or wish to utilize GPG-signing commits, uncomment
# the line below. I keep to tokens or SSH certs.
# brew install gnupg

###############################################################################
# Updating macOS Tools                                                        #
###############################################################################

# Install more recent versions of some macOS tools.
macTools=(
     vim --with-override-system-vi
     grep
     openssh
)
echo "Installing more current macOS tools..."
brew install "${macTools[@]}"

###############################################################################
# Install Other Packages                                                      #
###############################################################################
# TODO: Add descriptions of packages for context.
# TODO: Sort through existing list and find other worthwhile packages.

# Now we'll install some other useful packages].
# Comments soon to follow describing each package's purpose.
otherPackages=(
     ack
     bat
     fzf
     git
     p7zip
     mysql # Enables database management capabilities.
     pv
     readline
     rename
     rlwrap]
     tree
)
echo "Installing some other packages..."
brew install "${otherPackages[@]}"

###############################################################################
# Install Casks                                                               #
###############################################################################
# TODO: Add more casks.
# TODO: Add descriptions of cask apps for context.

# Rather than downloading apps and manually moving them to the Applications
# folder, instead use Homebrew's casks to automate things.
# More casks will be added as I figure out what's preferable in their list of 3,000 apps.
grabCasks=(
    bitwarden
    cakebrew
    crossover
    datagrip
    firefox
    lulu
    protonmail-bridge
    protonvpn
    pycharm-edu
    rider
    slack
    spotify
)
echo "Installing cask apps..."
brew install --cask "${grabCasks[@]}"

###############################################################################
# Wrap Up                                                                     #
###############################################################################

# Remove outdated versions from the cellar.
echo "Cleaning up old files..."
brew cleanup

echo "Homebrew setup completed!"