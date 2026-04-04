#!/bin/bash
. ./setenv.sh

aws sso login --profile "${PROFILE}"
