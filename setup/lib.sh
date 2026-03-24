#!/usr/bin/env bash
# Library loader — sources all setup modules in dependency order.

_SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"

source "$_SETUP_LIB_DIR/core.sh"
source "$_SETUP_LIB_DIR/profiles.sh"
source "$_SETUP_LIB_DIR/packages.sh"
source "$_SETUP_LIB_DIR/runtimes.sh"
source "$_SETUP_LIB_DIR/shell-setup.sh"
source "$_SETUP_LIB_DIR/stow.sh"
source "$_SETUP_LIB_DIR/verify.sh"
