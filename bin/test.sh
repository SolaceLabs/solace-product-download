#!/bin/bash

# The following script is run on a docker build and tests a variety of functionality
# with regards to the download script, check script and in scripts. The check and in
# scripts can be found in the assets directory. When the Dockerfile is run, this test
# script is moved to the same directory (/opt/resource/) as the assets scripts.

export SHA256SUM_CMD=$( which sha256sum || which gsha256sum )
export MD5SUM_CMD=$( which md5sum || which gmd5sum )
export DOWNLOAD_SCRIPT="./downloadLicenseSolaceProduct.sh"

if [ ! -f $IN_SCRIPT ] || [ ! -f $OUT_SCRIPT ]; then
  export SHOULD_CLEANUP=1
  if [ -d ../assets ]; then
    cp "../assets/in" ./
    cp "../assets/check" ./
  else
    echo "Could not find assets folder! No in or out scripts, quitting..."
    exit 1
  fi
fi

function testDownloadWithMissingLicense() {
  echo "Testing download with missing license"
  failed_dl=$(./downloadLicensedSolaceProduct.sh -u someaccount -p somepassword -d /products/2.2GA/PCF/Current/2.2.1/documentation.html | grep "Accepting the Solace License Agreement is required" | wc -l)
  if [ "$failed_dl" -eq 0 ]; then
    echo "Download license solace product did not fail when missing license agreement acceptance"
    exit 1
  fi
}

function testDownloadWithMissingPassword() {
  echo "Testing download with missing password" 
  failed_dl=$(./downloadLicensedSolaceProduct.sh -u someaccount -d /products/2.2GA/PCF/Current/2.2.1/documentation.html -a | grep "Missing password" | wc -l)
  if [ "$failed_dl" -eq 0 ]; then
    echo "Download license solace product did not fail when missing password"
    exit 1
  fi
}

function testDownloadWithMissingUsername() {
  echo "Testing download with missing username"
  failed_dl=$(./downloadLicensedSolaceProduct.sh -p somepassword -d /products/2.2GA/PCF/Current/2.2.1/documentation.html -a | grep "Missing username" | wc -l)
  if [ "$failed_dl" -eq 0 ]; then
    echo "Download license solace product did not fail when missing username"
    exit 1
  fi
}

function testDownloadWithMissingPath() {
  echo "Testing download with missing path"
  failed_dl=$(./downloadLicensedSolaceProduct.sh -u someaccount -p somepassword -a | grep "Missing download" | wc -l)
  if [ "$failed_dl" -eq 0 ]; then
    echo "Download license solace product did not fail when missing download"
    exit 1
  fi
}
##
function testDownloadWithBadUsernameAndPassword() {
  echo "Testing download with bad username and password"
  failed_dl=$(./downloadLicensedSolaceProduct.sh -u someaccount -p somepassword -d /products/2.2GA/PCF/Current/2.2.1/documentation.html -a | grep FAILED | wc -l)
  if [ "$failed_dl" -eq 0 ]; then
    echo "Download license solace product did not fail when given incorrect username and password"
    exit 1
  fi
  # Softwawre license agreement is downloaded before the password fails
  if [ -f "./Solace-Systems-Software-License-Agreement.pdf" ]; then
    rm "./Solace-Systems-Software-License-Agreement.pdf"
  fi
}

function testCheckScriptChecksum() {
  echo "Testing config checksum in version of source"
  input="{\"source\":{\"user\":\"testuser\"},\"version\":null}"
  tmpfile=$(mktemp)
  echo $input > $tmpfile
  output=$(./check 2> /dev/null < $tmpfile)
  expected_checksum=$( $SHA256SUM_CMD $tmpfile | awk '{ print $1 }')
  actual_checksum=$(echo "$output" | jq -r '.[0].config_checksum // ""')
  if [ ! "$expected_checksum" == "$actual_checksum" ]; then
    echo "Checksum did not match expected! Expected $expected_checksum got $actual_checksum"
    exit 1
  fi
}

function testInScriptMissingUsername() {
  echo "Testing in script without username"
  testInScript "{\"source\":{\"password\":\"aPassword\",\"filepath\":\"aFilepath\",\"accept_terms\":\"true\"}}" "username must be specified"
}


function testInScriptMissingPassword() {
  echo "Testing in script without password"
  testInScript "{\"source\":{\"username\":\"aUser\",\"filepath\":\"aFilepath\",\"accept_terms\":\"true\"}}" "password must be specified"
}

function testInScriptMissingTerms() {
  echo "Testing in script without accept terms flag"
  testInScript "{\"source\":{\"password\":\"aPassword\",\"filepath\":\"aFilepath\",\"username\":\"someuser\"}}" "Accepting the Solace License Agreement is required"
}

function testInScript() {
  input=$1
  expect_output=$2
  expect_result=${3:-"{}"}
  input_file=$(mktemp)
  output_file=$(mktemp)
  echo $input > $input_file
  result=$(./in /tmp 2>$output_file < $input_file) 
  if [ $(cat $output_file | grep "$expected_output" | wc -l) -eq "0" ]; then
    echo "In script did not give correct output"
    echo "Output:"
    cat $outfile_file
    echo "Expected output to contain '$expected_output'"
    exit 1
  fi
  if [ ! -z $expected_result ] && [ "$result" != "$expected_result" ]; then
    echo "In script did not give correct result"
    echo "Expected output to be '$expected_result', was '$result'"
    exit 1
  fi
}

echo
echo "======================="
echo "Testing download script"
echo "======================="
echo

testDownloadWithMissingLicense
testDownloadWithMissingPassword
testDownloadWithMissingUsername
testDownloadWithMissingPath

testDownloadWithBadUsernameAndPassword

echo
echo "===================="
echo "Testing check script"
echo "===================="
echo

testCheckScriptChecksum

echo
echo "================="
echo "Testing in script"
echo "================="
echo

testInScriptMissingUsername
testInScriptMissingPassword
testInScriptMissingTerms

echo
echo "================"
echo "All tests passed"
echo "================"
echo
