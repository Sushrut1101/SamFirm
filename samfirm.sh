#!/bin/bash

# Help / Usage
usage(){
	echo "$0 [device_model] [region]"
	echo "OR"
	echo "Place a config.json file"
}

if [ "$1" = "--help" ]; then
	usage
	exit 0
elif [ -z "$1" ]; then
	if [ -f "config.json" ]; then
		USE_CONFIG_JSON=true
	else
		echo "ERROR: Neither an Argument Specified, nor I found a config.json file"
		echo "Run \"$0 --help\""
		exit 1
	fi
fi

# Set Variables
if [ "$USE_CONFIG_JSON" = true ]; then
	echo "config.json found"
	MODEL=$(cat config.json | jq -r ."model")
	REGION=$(cat config.json | jq -r ."region")
else
	MODEL="$1"
	REGION="$2"
fi

[ -z "$OUTDIR" ] && OUTDIR=$(pwd)/out
rm -rf ${OUTDIR}
mkdir -p ${OUTDIR}

# Install Samloader if not already installed
if [ -z $(command -v samloader) ]; then
	echo "Installing Samloader..."
	sudo pip install git+https://github.com/samloader/samloader.git || exit 1
	sleep 1
fi

# Download Firmware
samloader -m ${MODEL} -r ${REGION} checkupdate || exit 1
FW_VERSION=$(samloader -m ${MODEL} -r ${REGION} checkupdate)
echo "Downloading Firmware to ${OUTDIR}"
sleep 1
samloader -m ${MODEL} -r ${REGION} download -v ${FW_VERSION} -O ${OUTDIR}

# Decrypt Firmware
FILE=$("ls" ${OUTDIR}/)
OUTFILE=$("ls" ${OUTDIR}/ | sed "s/.enc4//g")
echo "Decrypting Firmware..."
sleep 1
samloader -m "${MODEL}" -r "${REGION}" decrypt -v "${FW_VERSION}" -i "${OUTDIR}/${FILE}" -o "${OUTDIR}/${OUTFILE}" || exit 1
echo "Firmware Decrypted Successfully"
rm -rf "${FILE}"
sleep 1

# Uploading Firmware
echo "Uploading Firmware..."
SF_UPLOAD_DIR="${MODEL}"/"${REGION}"
sshpass -p ${SF_PASS} rsync -r -ae "ssh -o StrictHostKeyChecking=no" "${OUTDIR}"/"${OUTFILE}" ${SF_USERNAME}@frs.sourceforge.net:/home/frs/project/${SF_PROJECT}/${SF_UPLOAD_DIR}/
printf "\n"
LINK=https://sourceforge.net/projects/"${SF_PROJECT}"/files/"${SF_UPLOAD_DIR}"/"${OUTFILE}"/download

# Print the Download Link
echo -e "----------------------"
echo -e "Download Link: ${LINK}"
echo -e "----------------------"
