#!/usr/bin/env bash
# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# This script sets up a docker container to serve as a test runner for boundary
# e2e tests

set -eux -o pipefail

docker run \
    --rm \
    --name test-runner \
    -e "TEST_PACKAGE=$TEST_PACKAGE" \
    -e "TEST_TIMEOUT=$TEST_TIMEOUT" \
    -e "E2E_TESTS=$E2E_TESTS" \
    -e "BOUNDARY_ADDR=$BOUNDARY_ADDR" \
    -e "E2E_PASSWORD_AUTH_METHOD_ID=$E2E_PASSWORD_AUTH_METHOD_ID" \
    -e "E2E_PASSWORD_ADMIN_LOGIN_NAME=$E2E_PASSWORD_ADMIN_LOGIN_NAME" \
    -e "E2E_PASSWORD_ADMIN_PASSWORD=$E2E_PASSWORD_ADMIN_PASSWORD" \
    -e "E2E_TARGET_IP=$E2E_TARGET_IP" \
    -e "E2E_SSH_USER=$E2E_SSH_USER" \
    -e "E2E_SSH_PORT=$E2E_SSH_PORT" \
    -e "E2E_SSH_CA_KEY=$E2E_SSH_CA_KEY" \
    -e "E2E_SSH_KEY_PATH=/keys/target.pem" \
    -e "VAULT_ADDR=$VAULT_ADDR_INTERNAL" \
    -e "VAULT_TOKEN=$VAULT_TOKEN" \
    -e "E2E_VAULT_ADDR=$E2E_VAULT_ADDR" \
    -e "E2E_AWS_ACCESS_KEY_ID=$E2E_AWS_ACCESS_KEY_ID" \
    -e "E2E_AWS_SECRET_ACCESS_KEY=$E2E_AWS_SECRET_ACCESS_KEY" \
    -e "E2E_AWS_HOST_SET_FILTER=$E2E_AWS_HOST_SET_FILTER" \
    -e "E2E_AWS_HOST_SET_IPS=$E2E_AWS_HOST_SET_IPS" \
    -e "E2E_AWS_HOST_SET_FILTER2=$E2E_AWS_HOST_SET_FILTER2" \
    -e "E2E_AWS_HOST_SET_IPS2=$E2E_AWS_HOST_SET_IPS2" \
    -e "E2E_AWS_REGION=$E2E_AWS_REGION" \
    -e "E2E_AWS_BUCKET_NAME=$E2E_AWS_BUCKET_NAME" \
    -e "E2E_WORKER_TAG=$E2E_WORKER_TAG" \
    --mount type=bind,src=$BOUNDARY_DIR,dst=/src/boundary/ \
    --mount type=bind,src=$MODULE_DIR/../..,dst=/testlogs \
    --mount type=bind,src=$(go env GOCACHE),dst=/root/.cache/go-build \
    --mount type=bind,src=$(go env GOMODCACHE),dst=/go/pkg/mod \
    -v "$MODULE_DIR/test.sh:/scripts/test.sh" \
    -v "$E2E_SSH_KEY_PATH:/keys/target.pem" \
    -v "$BOUNDARY_CLI_DIR:/boundary.zip" \
    --network $TEST_NETWORK_NAME \
    --cap-add=CAP_IPC_LOCK \
    $TEST_RUNNER_IMAGE \
    /bin/sh -c /scripts/test.sh
