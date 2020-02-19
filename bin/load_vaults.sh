#!/usr/bin/env bash

ANSIBLE_VAULT_IDENTITY_DIR=".ansible_vault"
ANSIBLE_VAULT_IDENTITY_LIST=""
for vault_file in $(ls ~/${ANSIBLE_VAULT_IDENTITY_DIR}); do
    vault_name="$(basename $vault_file)"
    if [ -z ${ANSIBLE_VAULT_IDENTITY_LIST} ]; then
        ANSIBLE_VAULT_IDENTITY_LIST="${vault_name}@~/${ANSIBLE_VAULT_IDENTITY_DIR}/${vault_name}"
    else
        ANSIBLE_VAULT_IDENTITY_LIST="${ANSIBLE_VAULT_IDENTITY_LIST},${vault_name}@~/${ANSIBLE_VAULT_IDENTITY_DIR}/${vault_name}"
    fi
done
export ANSIBLE_VAULT_IDENTITY_LIST
