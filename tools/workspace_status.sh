#!/usr/bin/env bash

# Use VERSION_INPUT from environment or fallback
version=${VERSION_INPUT:-1.0}
# Use BUILD_NUMBER_INPUT if present, else GITHUB_RUN_NUMBER, else 1
build_number=${BUILD_NUMBER_INPUT:-${GITHUB_RUN_NUMBER:-1}}

echo "STABLE_VERSION ${version}"
echo "STABLE_BUILD_NUMBER ${build_number}"
