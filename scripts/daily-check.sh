#!/usr/bin/env bash
# ConTeXt Packaging Scripts
# https://github.com/gucci-on-fleek/context-packaging
# SPDX-License-Identifier: CC0-1.0+
# SPDX-FileCopyrightText: 2025 Max Chernoff
set -euxo pipefail

# Variables
context="/opt/context/texmf-context/"

# Set the Git credentials
# (From https://git-scm.com/docs/gitfaq#http-credentials-environment)
git config credential.helper \
    '!f() { echo username=$GITHUB_USER; echo "password=$GITHUB_TOKEN"; };f'

# The suffix that we'll use for updates to the TeX Live package that use the
# same version of ConTeXt
suffix="A"

# Get the current version
version="$( \
    grep -oP '(?<=def\\contextversion\{)(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2})' \
    $context/tex/context/base/mkxl/context.mkxl \
)"
version="$(echo "$version" | tr '.: ' '-')-$suffix"

# Tag the current version, and exit if it already exists
git tag --no-sign "$version" || exit 0

# Push the tag, and then trigger the next workflow
git push origin "$version"
