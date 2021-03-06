#!/bin/bash
#
# The content of this file are licensed under the MIT License (https://opensource.org/licenses/MIT)
# MIT License
#
# Copyright (c) 2018-2019 Paul Moss
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Script to check and see if a file or folder exist on a mega.nz account
# Created by Paul Moss
# Created: 2018-06-02
# File Name: mega_dir_file_exist.sh
# Github: https://github.com/Amourspirit/mega_scripts
# Help: https://amourspirit.github.io/mega_scripts/mega_dir_file_existsh.html
# 
# This script can be used to test if mega.nz can be connected to as well.
#    Eg: ./mega_dir_file_exist.sh; echo $?
#        this will output 1 if connection was successful and 0 otherwise
#    Eg: ./mega_dir_file_exist.sh "" ~/.megarc; echo $?
#        this will output 1 if connection was successful and 0 otherwise while allowing to pass in a config file.
#
# -p: Optional: -p pass in the folder or file to see if exist
# -i: Optional: -i pass in the configuration file that contains the account information for mega.nz. Defaults to ~/.megarc
# -v: Display the current version of this script
# -h: Display script help
#
# Exit Codes
# Code  Defination
#   0   Directory not found
#   1   Directory is found and is Root
#   2   Directory found
#   3   File Found
# 102   megals not found. Megtools requires installing
# 111   Optional argument two was passed in but the config can not be foud or we do not have read permissions

MS_VERSION='1.3.5.0'
MEGA_DEFAULT_ROOT="/Root"
MEGA_SERVER_PATH=''
CURRENT_CONFIG=''
MEGA_FILES=''
IN_ROOT=0
FINAL_STATUS=0
function trim () {
    local var=$1;
    var="${var#"${var%%[![:space:]]*}"}";   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}";   # remove trailing whitespace characters
    echo -n "$var";
}
# create an array that contains configuration values
# put values that need to be evaluated using eval in single quotes
typeset -A SCRIPT_CONF # init array
SCRIPT_CONF=( # set default values in config array
    [MT_MEGA_LS]='megals'
)
if [[ -f "${HOME}/.mega_scriptsrc" ]]; then
    # make tmp file to hold section of config.ini style section in
    TMP_CONFIG_COMMON_FILE=$(mktemp)
    # SECTION_NAME is a var to hold which section of config you want to read
    SECTION_NAME="MEGA_COMMON"
    # sed in this case takes the value of SECTION_NAME and reads the setion from ~/config.ini
    sed -n '0,/'"$SECTION_NAME"'/d;/\[/,$d;/^$/d;p' "$HOME/.mega_scriptsrc" > $TMP_CONFIG_COMMON_FILE

    # test tmp file to to see if it is greater then 0 in size
    test -s "${TMP_CONFIG_COMMON_FILE}"
    if [ $? -eq 0 ]; then
    # read the input of the tmp config file line by line
        while read line; do
            if [[ "$line" =~ ^[^#]*= ]]; then
                setting_name=$(trim "${line%%=*}");
                setting_value=$(trim "${line#*=}");
                SCRIPT_CONF[$setting_name]=$setting_value
            fi
        done < "$TMP_CONFIG_COMMON_FILE"
    fi

    # release the tmp file that is contains the current section values
    unlink $TMP_CONFIG_COMMON_FILE
fi
MT_MEGA_LS=${SCRIPT_CONF[MT_MEGA_LS]}
MT_MEGA_LS=$(eval echo ${MT_MEGA_LS})

# done with config array so lets free up the memory
unset SCRIPT_CONF

if ! [ -x "$(command -v ${MT_MEGA_LS})" ]; then
   exit 102
fi
usage() { echo "$(basename $0) usage:" && grep "[[:space:]].)\ #" $0 | sed 's/#//' | sed -r 's/([a-z])\)/-\1/'; exit 0; }
while getopts ":hvp:i:" arg; do
  case $arg in
    p) # Optional: Specify -p the path to test if it exist. Eg: /bin/bash /usr/local/bin/mega_dir_file_exist.sh -p '/MyPath/myfile'
        MEGA_SERVER_PATH="${OPTARG}"
        ;;
    i) # Optional: Specify -i the configuration file to use that contain the credentials for the Mega.nz account you want to access.
        CURRENT_CONFIG="${OPTARG}"
        ;;
    v) # -v Display version info
        echo "$(basename $0) version:${MS_VERSION}"
        exit 0
        ;;
    h) # -h Display help.
        echo 'For online help visit: https://amourspirit.github.io/mega_scripts/mega_dir_file_existsh.html'
        usage
        exit 0
        ;;
  esac
done
# the follow vars are eval in case they contain other expandable vars such as $HOME or ${USER}
CURRENT_CONFIG=$(eval echo ${CURRENT_CONFIG})

if [[ -z "${MEGA_SERVER_PATH}" ]]; then
    # No argument for user supplied mega server path
    MEGA_SERVER_PATH="${MEGA_DEFAULT_ROOT}"
    IN_ROOT=1
else
    MEGA_SERVER_PATH="${MEGA_DEFAULT_ROOT}${MEGA_SERVER_PATH}"
fi
if [[ -n "${CURRENT_CONFIG}" ]]; then
    # Argument is given for default configuration for that contains user account and password
    test -r "${CURRENT_CONFIG}"
    if [ $? -ne 0 ]; then
        exit 111
    fi
fi

if [[ -z "${CURRENT_CONFIG}" ]]; then
    # No argument is given for default configuration for that contains user account and password
    MEGA_FILES=$(${MT_MEGA_LS} -l "${MEGA_SERVER_PATH}")
else
    # Argument is given for default configuration that contains user account and password
    MEGA_FILES=$(${MT_MEGA_LS} --config "${CURRENT_CONFIG}" -l "${MEGA_SERVER_PATH}")
fi

if [[ -z "${MEGA_FILES}" ]]; then
    #nothing returned from mggals this indicates that does not exist
    exit $FINAL_STATUS
fi

# If we got this far then we have a result.
# Root folder itself only has 6 columns.
# All other entries including root files have at least 7.
# When using awk to parse results all files names with spaces will count as extra columns
# for this reason count columns from left to right using awk
if [[ IN_ROOT -eq 1 ]]; then
    FINAL_STATUS=1
else
    # create a tmp file to be used for exit code.
    # loops do not play well well with setting var values outside the loop so we use a file
    TMP_FILE_STATUS=$(mktemp)
    # write 0 to the file this way if loop finds nothing then default exit code will be 0
    echo 0 >> ${TMP_FILE_STATUS}

    echo "${MEGA_FILES}" | while read line
    do
        # use grep to get the complete file path form megals output
        FILE_PATH=$(echo "$line" | grep -o '/Root.*')

        if [[ "${FILE_PATH}" != "${MEGA_SERVER_PATH}" ]]; then
            # not a match of the file / folder we are looking for
            continue
        fi

        # If we have gotten this far in the loop then we have a match for file / folder
        # lets check and see if it is a file or a folder
        FILE_TYPE=$(echo "$line" | awk '{print $3}')
        # when FILE_TYPE = 0 it is a file
        # when FILE_TYPE = 1 it is a folder
        # when FILE_TYPE = 2 it is root

        if [[ $FILE_TYPE -eq 0 ]]; then
            # clear the tmp file
            truncate -s 0 "${TMP_FILE_STATUS}"
            # exit code for file will be 3
            echo 3 >> ${TMP_FILE_STATUS}
        fi
        if [[ $FILE_TYPE -eq 1 ]]; then
            # clear the tmp file
            truncate -s 0 "${TMP_FILE_STATUS}"
            # exit code for directory will be 2
            echo 2 >> ${TMP_FILE_STATUS}
        fi
        if [[ $FILE_TYPE -eq 2 ]]; then
            # clear the tmp file
            truncate -s 0 "${TMP_FILE_STATUS}"
            # exit code for root will be 1
            echo 1 >> ${TMP_FILE_STATUS}
        fi
        break
    done
    FINAL_STATUS=$(cat $TMP_FILE_STATUS)
    unlink $TMP_FILE_STATUS
fi
exit $FINAL_STATUS
