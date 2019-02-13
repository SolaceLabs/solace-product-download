#!/bin/bash
#
### 
#
#
# Basic scripting to download licensed Solace products:
#
# - Authentication
# - Accepting of Solace License Agreement
# - Downloading of Solace License Agreement
# - Downloading of a product
# - Optional: Validate checksum of a downloaded file ( md5 or sha256 )
#
# All required and optional parameters can be command line arguments or environment variables.
#
#
###

## Exit on errors.
set -e

## Required tools list for a basic check.
REQUIRED_TOOLS=${REQUIRED_TOOLS:-"curl awk basename dirname pwd grep printf which mktemp"}


export SCRIPT="$( basename "${BASH_SOURCE[0]}" )"
export SCRIPTPATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


export SOLACE_PRODUCTS_FORM_URL="https://products.solace.com/#"
export SOLACE_PRODUCTS_DOWNLOAD_URL="https://products.solace.com"
export SOLACE_PRODUCTS_PDF_LICENSE_URL="/Solace-Systems-Software-License-Agreement.pdf"
export SOLACE_PRODUCTS_HTML_LICENSE_URL="http://www.solace.com/license-software"
export COOKIES_FILE=${COOKIES_FILE:-"cookies.txt"}

export SHA256SUM_CMD=$( which sha256sum || which gsha256sum )
export MD5SUM_CMD=$( which md5sum || which gmd5sum )

## Default checksum using md5
export CHECKSUM_CMD=${CHECKSUM_CMD:-$MD5SUM_CMD}

##
# A chance to clean up when done
##
function downloadCleanup {
  if [ -f $COOKIES_FILE ]; then
    rm -f $COOKIES_FILE
  fi
}
trap downloadCleanup EXIT INT TERM HUP


function checkRequiredTools() {
 for REQUIRED_TOOL in $@; do
  which $REQUIRED_TOOL > /dev/null || {
        echo "ERROR: '$REQUIRED_TOOL' was not found. Please install it."
        exit 1
  }
 done
}


function checkRequiredVariables() {
 local found_missing=0
 local missing_list
 for V in $@; do
    if [ -z "${!V}" ]; then
        found_missing=1
        missing_list="$missing_list $V"
    fi
 done
 if [ "$found_missing" -eq "1" ]; then
    echo "Required variable(s) where missing [ $missing_list ]"
    exit 1
 fi
}

function authenticateAndAcceptSolaceLicenseAgreement() {
 printf "Authenticating as user\t\t\t%s\n" $SOLACE_USER
 export AUTH_RESPONSE=$( curl -s -w '%{http_code}' -X POST -F 'login-submit=1' -F "username=$1" -F "password=$2" -c $COOKIES_FILE $SOLACE_PRODUCTS_FORM_URL )
 printf "Accepting License Agreement\t\t%s\n" $SOLACE_PRODUCTS_PDF_LICENSE_URL
 printf "License Agreement as HTML\t\t%s\n" $SOLACE_PRODUCTS_HTML_LICENSE_URL
 export LICENSE_RESPONSE=$( curl -s -w '%{http_code}' -X POST -b $COOKIES_FILE -F 'license-submit=1' -F 'acceptcheckbox=1' $SOLACE_PRODUCTS_FORM_URL )
}


function downloadProduct() {
  PRODUCT_PATH=$1
  PRODUCT_FILE=$( basename $PRODUCT_PATH )
  printf "Downloading\t\t\t\t%s\n" "$PRODUCT_PATH"
  export DOWNLOAD_RESPONSE=$( curl -s -w '%{http_code}' -X GET  -b cookies.txt $SOLACE_PRODUCTS_DOWNLOAD_URL/$PRODUCT_PATH -o $PRODUCT_FILE )
  ## check for a login redirect, hence a failed login, the downloaded file will be the login form..
  REDIRECTED_COUNT=$( grep "location" $PRODUCT_FILE | grep "$PRODUCT_FILE" | wc -l )
  if [ "$REDIRECTED_COUNT" -eq "0" ]; then
    if [ "$(cat $PRODUCT_FILE | grep 'Cannot access' | wc -l)" -gt "0" ]; then
      printf "Download %s\t\t\t\t%s\n" "FAILED" "Detected missing file $SOLACE_PRODUCTS_DOWNLOAD_URL/$PRODUCT_PATH... please check the file exists."
      rm -f $PRODUCT_FILE
      exit 1
    fi
    printf "Download %s\t\t\t\t%s\n" "OK" "$PRODUCT_FILE"
  else
    printf "Download %s\t\t\t\t%s\n" "FAILED" "Detected a redirect to login... please check the username and password."
    rm -f $PRODUCT_FILE
    exit 1
  fi
  
} 

function validateChecksum() {

  PRODUCT_PATH=$1
  PRODUCT_FILE=$( basename $PRODUCT_PATH )
  PRODUCT_CHECKSUM=$2

  if [ -f $PRODUCT_FILE ] && [ -f $PRODUCT_CHECKSUM ] && [ -x $CHECKSUM_CMD ]; then
     printf "Checksum command\t\t\t%s\n" "$CHECKSUM_CMD -c $PRODUCT_CHECKSUM"
     printf "Checksum result:\n"
     $CHECKSUM_CMD -c $PRODUCT_CHECKSUM
  else
     printf "Checksum\t\t\t\t%s\n" "Not validated"
  fi

}

function showUsage() {
    echo
    echo "Usage: $SCRIPT [OPTIONS]"
    echo
    echo "OPTIONS"
    echo "  -h                        Show Command options "
    echo "  -u <username>             Required user name for downloads. or provide \$SOLACE_USER"
    echo "  -p <password>             Required password for downloads. or provide \$SOLACE_USER_PASSWORD"
    echo "  -d <download_file_path>   The download file path. or provide \$DOWNLOAD_FILE_PATH"
    echo "  -a                        Accept the Solace License Agreement upon download. or provide \$ACCEPT_LICENSE=1"
    echo "  -c <checksum_file>        A checksum file produced by md5sum or sha256sum. or provide \$CHECKSUM_FILE"
    echo
}

function showUsageAndExit() {
  showUsage
  echo
  printf "%s\n" "$1"
  echo
  exit 1
}

checkRequiredTools $REQUIRED_TOOLS

while getopts "u:p:d:c:ah" arg; do
    case "${arg}" in
        u)
            export SOLACE_USER=$OPTARG
            ;;
        p)
            export SOLACE_USER_PASSWORD=$OPTARG
            ;;
        d)
            export DOWNLOAD_FILE_PATH=$OPTARG
            ;;
        c)
            export CHECKSUM_FILE=$OPTARG
            ;;
        a)
            export ACCEPT_LICENSE=1
            ;;
        h)
            showUsage
            exit 0
            ;;
       \?)
       >&2 echo
       >&2 echo "Invalid option: -$OPTARG" >&2
       >&2 echo
       showUsage
       exit 1
       ;;
    esac
done

if [ -z $SOLACE_USER ]; then
  showUsageAndExit "Missing username, please use -u or \$SOLACE_USER"
fi

if [ -z $SOLACE_USER_PASSWORD ]; then
  showUsageAndExit "Missing password, please use -p or \$SOLACE_USER_PASSWORD"
fi

if [ -z $DOWNLOAD_FILE_PATH ]; then
  showUsageAndExit "Missing download file path, please use -d or \$DOWNLOAD_FILE_PATH"
fi

if [ -z $ACCEPT_LICENSE ]; then
  showUsageAndExit "Accepting the Solace License Agreement is required to download products from Solace. Please use -a or \$ACCEPT_LICENSE=1"
fi

if [ ! -z $CHECKSUM_FILE ] && [ -f $CHECKSUM_FILE ]; then
   SAMPLE_CHECKSUM=$( cat $CHECKSUM_FILE  | awk '{ print $1 }' )
   SAMPLE_CHECKSUM_LEN=${#SAMPLE_CHECKSUM}

   # Determine checksum
   ## MD5SUM
   if [ "$SAMPLE_CHECKSUM_LEN" -eq "32" ]; then
     export CHECKSUM_CMD=$MD5SUM_CMD
   fi
   ## SHA256SUM
   if [ "$SAMPLE_CHECKSUM_LEN" -eq "64" ]; then
     export CHECKSUM_CMD=$SHA256SUM_CMD
   fi
fi

## A final check for all required variables.
checkRequiredVariables "SOLACE_USER SOLACE_USER_PASSWORD DOWNLOAD_FILE_PATH ACCEPT_LICENSE"

authenticateAndAcceptSolaceLicenseAgreement $SOLACE_USER $SOLACE_USER_PASSWORD
downloadProduct $SOLACE_PRODUCTS_PDF_LICENSE_URL
downloadProduct $DOWNLOAD_FILE_PATH

if [ ! -z $CHECKSUM_FILE ]; then
 validateChecksum $DOWNLOAD_FILE_PATH $CHECKSUM_FILE
fi

