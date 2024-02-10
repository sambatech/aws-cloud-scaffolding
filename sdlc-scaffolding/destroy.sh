#!/usr/bin/env bash
#
# -e (errexit): Abort the script at the first error, when a command exits with 
#               non-zero status (except in until or while loops, if-tests, and 
#               list constructs)
# -o pipefail: Causes a pipeline to return the exit status of the last command 
#              in the pipe that returned a non-zero return value.

set -e
set -o pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

exec ${SCRIPT_DIR}/4-kubernetes-extras/destroy.sh

exec ${SCRIPT_DIR}/3-kubernetes/destroy.sh

exec ${SCRIPT_DIR}/2-registry/destroy.sh

exec ${SCRIPT_DIR}/1-network/destroy.sh