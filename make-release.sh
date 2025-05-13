#!/usr/bin/env bash
# ConTeXt Packaging Scripts
# https://github.com/gucci-on-fleek/context-packaging
# SPDX-License-Identifier: CC0-1.0+
# SPDX-FileCopyrightText: 2025 Max Chernoff
set -euxo pipefail

# Variables
source="/opt/context/"
declare -A platforms=(
    ["freebsd-amd64"]="amd64-freebsd"
    ["linux"]="i386-linux"
    ["linux-64"]="x86_64-linux"
    ["linuxmusl-64"]="x86_64-linuxmusl"
    ["osx-64"]="x86_64-darwinlegacy"
    ["osx-arm64"]="universal-darwin"
    ["win64"]="windows"
)

# Output folders
root="$(pwd)"
output="$root/output/"

mkdir -p "$output/context/texmf-dist/"
mkdir -p "$output/context.doc/texmf-dist/"
mkdir -p "$output/luametatex.src/"
mkdir -p "$output/context-nonfree/texmf-dist/"
for tl_platform in "${platforms[@]}"; do
    mkdir -p "$output/context.$tl_platform/bin/$tl_platform/"
done

# Binaries
for ctx_platform in "${!platforms[@]}"; do
    tl_platform="${platforms[$ctx_platform]}"

    cp -a "$source/texmf-$ctx_platform/bin/"* "$output/context.$tl_platform/bin/$tl_platform/"
    ln -sf ../../texmf-dist/scripts/context/lua/context.lua "$output/context.$tl_platform/bin/$tl_platform/context.lua"
    ln -sf ../../texmf-dist/scripts/context/lua/mtxrun.lua "$output/context.$tl_platform/bin/$tl_platform/mtxrun.lua"
done

# texmf-dist/fonts/
rm -rf "$output/context/texmf-dist/fonts/"
mkdir -p "$output/context/texmf-dist/fonts/opentype/public/"
cp -a "$source/texmf/fonts/data/cms/companion/" "$output/context/texmf-dist/fonts/opentype/public/context-companion-fonts/"

# texmf-dist/context/
cp -a "$source/texmf-context/context/" "$output/context/texmf-dist/"

# texmf-dist/metapost/
cp -a "$source/texmf-context/metapost/" "$output/context/texmf-dist/"

# source
cp -a "$source/texmf-context/source/luametatex/"* "$output/luametatex.src/"

# texmf-dist/doc/
cp -a "$source/texmf-context/doc/" "$output/context.doc/texmf-dist/"
mkdir -p "$output/context.doc/texmf-dist/doc/man/man1/"
cp -a "$source/texmf-context/doc/context/scripts/mkiv/"*.man "$output/context.doc/texmf-dist/doc/man/man1/"
prename 's/.man$/.1/' "$output/context.doc/texmf-dist/doc/man/man1/"*
cp -a "$source/texmf-context/context-readme.txt" "$output/context.doc/texmf-dist/doc/context/"

# texmf-dist/scripts/
cp -a "$source/texmf-context/scripts/" "$output/context/texmf-dist/"
rm "$output/context/texmf-dist/scripts/context/lua/mtx-"{install,install-modules}.lua
rm "$output/context/texmf-dist/scripts/context/perl/mptopdf.pl"

# texmf-dist/tex/
cp -a "$source/texmf-context/tex/" "$output/context/texmf-dist/"
mkdir -p "$output/context/texmf-dist/bibtex/bib/"
mv "$output/context/texmf-dist/tex/context/bib/common/" "$output/context/texmf-dist/bibtex/bib/context/"
cp -a "$source/texmf-context/colors/icc/context/" "$output/context/texmf-dist/tex/context/colors/"

# Non-free
mkdir -p "$output/context-nonfree/texmf-dist/tex/context/fonts/mkiv/"
mv "$output/context/texmf-dist/tex/context/fonts/mkiv/"*{cambria,lucida,mathtimes,minion,adobe,cleartype,koeiel,osx,mscore}* "$output/context-nonfree/texmf-dist/tex/context/fonts/mkiv/"
mkdir -p "$output/context-nonfree/texmf-dist/tex/context/colors/"
cp -a "$source/texmf-context/colors/icc/profiles/" "$output/context-nonfree/texmf-dist/tex/context/colors/"

# And now we'll zip it all up
cd "$output/"
for folder in ./*; do
    folder_name="$(basename "$folder")"
    cd "$output/$folder_name/"
    zip -r -y "../$folder_name.zip" *
done

cd "$output/"
zip ../context-"$(git describe --exact-match --tags)".zip ./*.zip
