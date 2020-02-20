#!/usr/bin/env bash

# global definitions
KO=1
OK=0
TRUE=0
FALSE=1
DEBUG=${FALSE}

function help {
    echo "$0 OPTIONS <playbook> [ <playbook> ... ]"
    echo
    echo "OPTIONS:"
    echo "   --vault-id   <vault>  # vault-id for key/rekey"
    echo "  [--vault-dir] <dir>    # vault password file location"
    echo "  [--generate]           # generate new vault password"
    echo "  [--verify]             # restrict rekey to matching vault-ids"
    echo "  [--debug]"
}

function debug {
    if [ "${DEBUG}" -eq "${TRUE}" ]; then
        echo "$@"
    fi
}

function check_requirement {
    cmd=$1
    command -v "${cmd}" >/dev/null 2>&1 || {
        echo "${cmd} not found, aborting"
        exit "${ERROR}"
    }
}

check_requirement ansible-vault

# parse options (https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash)
POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        --directory)
            DECRYPT_DIR="$2"
            shift # past argument
            shift # past value
            ;;
        --vault-dir)
            VAULT_PASS_DIR="$2"
            shift # past argument
            shift # past value
            ;;
        --help)
            help
            exit ${SUCCESS}
            ;;
        --debug)
            DEBUG=${TRUE}
            AWXCLI_VERBOSE="--verbose"
            shift # past argument
            ;;
        *)  # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
            ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# validate options
if [ -z "${DECRYPT_DIR}" ]; then
    echo "--directory <path> option is required"
    exit ${KO}
fi
if [ -z "${VAULT_PASS_DIR}" ]; then
    VAULT_PASS_DIR="${HOME}/.ansible_vault"
fi
if [ ${#POSITIONAL[@]} -gt 0 ]; then
    echo "Unknown positional arguments ${POSITIONAL[@]}"
    exit ${KO}
fi

# set derived files
DECRYPT_FILES=$(find "${DECRYPT_DIR}" -name "*.yml" -type f)

debug "Listing vault files from [${VAULT_PASS_DIR}]"
TMPROOT=temp
TMPVAULTS=$(mktemp -d --tmpdir=${TMPROOT} --suffix=.decrypt)

debug "Creating working copy of vault file dir [${VAULT_PASS_DIR}]"
VAULT_NAMES=$(find "${VAULT_PASS_DIR}/" -type f | xargs -L 1 basename)
for vault_name in ${VAULT_NAMES}; do
    cp -a "${VAULT_PASS_DIR}/${vault_name}" "${TMPVAULTS}/${vault_name}"
done

debug Inspecting files [${DECRYPT_FILES}]
for file_name in $DECRYPT_FILES; do

    DECRYPT_VARS=$(egrep "^[^ ].*:\s+\!vault" "${file_name}" -h | cut -d ':' -f 1)

    if [ "${DECRYPT_VARS}" != "" ]; then

        for var_name in ${DECRYPT_VARS}; do

            debug "Processing ${file_name}:${var_name}"
            encrypted=$(yq r "${file_name}" "${var_name}")
            if [ $? -ne 0 ]; then
                echo "error retrieving secret ${var_name} from file ${file_name}"
                exit "${KO}"
            fi

            decrypt_success=${KO}
            debug Processing vaults [${VAULT_NAMES}]
            for vault in ${VAULT_NAMES}; do

                debug "Processing ${file_name}:${var_name} with vault ${vault}"
                decrypted=$(echo "${encrypted}" | ansible-vault decrypt --vault-id "${vault}@${TMPVAULTS}/${vault}" 2>/dev/null)
                if [ $? -ne 0 ]; then
                    continue;
                else
                    decrypt_success=${OK}
                    break;
                fi

            done
            if [ $decrypt_success -ne ${OK} ]; then
                echo "error decrypting secret ${var_name} from ${file_name}"
                exit "${KO}"
            else
                echo "${file_name}:${var_name}:${decrypted}"
            fi

        done

    fi

done

rm -rf ${TMPVAULTS}