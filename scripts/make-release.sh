#!/usr/bin/env bash
# ConTeXt Packaging Scripts
# https://github.com/gucci-on-fleek/context-packaging
# SPDX-License-Identifier: CC0-1.0+
# SPDX-FileCopyrightText: 2025 Max Chernoff
set -euxo pipefail


#################
### Variables ###
#################

# The version of ConTeXt that we're packaging, with no spaces or colons.
safe_version="$(git describe --exact-match --tags)"

# The version of ConTeXt that we're packaging, with spaces and colons.
pretty_version="$(\
    echo "$safe_version" | \
    sed -E 's/([[:digit:]]{4})-([[:digit:]]{2})-([[:digit:]]{2})-([[:digit:]]{2})-([[:digit:]]{2})/\1-\2-\3 \4:\5/'\
)"

# Set the date to use for all further operations
SOURCE_DATE_EPOCH="$(\
    date --date="TZ=\"Europe/Amsterdam\" $pretty_version" '+%s'\
)"
export SOURCE_DATE_EPOCH
export FORCE_SOURCE_DATE=1

# Force the locale to C.UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# The ConTeXt standalone distribution is updated daily on the server, and it is
# bind-mounted into this container at this path.
source="/opt/context/"

# A mapping from the ConTeXt platform names to TeX Live platform names.
declare -A context_platforms=(
    ["freebsd-amd64"]="amd64-freebsd"
    ["linux-64"]="x86_64-linux"
    ["linux"]="i386-linux"
    ["linuxmusl-64"]="x86_64-linuxmusl"
    ["openbsd-amd64"]="amd64-openbsd73" # Officially supported by ConTeXt, but
                                        # not by TeX Live. We'll include it
                                        # anyways for CTAN.
    ["osx-64"]="x86_64-darwinlegacy"
    ["osx-arm64"]="universal-darwin"
    ["win64"]="windows"
)

# These platforms aren't officially supported by the ConTeXt installer, but the
# ConTeXt Build Farm builds binaries for them, so we can manually add them here.
luametatex_platforms=(
    "aarch64-linux"
    "i386-freebsd"
)

# No binaries for these platforms unfortunately.
# shellcheck disable=SC2034
missing_platforms=(
    "amd64-netbsd"  # ConTeXt Build Farm builder is broken
    "armhf-linux"  # Build Farm gives 403 Forbidden
    "i386-netbsd"  # Not built by the Build Farm
    "i386-solaris"   # Build Farm gives 403 Forbidden
    "x86_64-cygwin"  # Not built by the Build Farm
    "x86_64-solaris"  # Not built by the Build Farm
)

# This is the root of the Woodpecker CI job.
root="$(pwd)"

# This is the source of any files that we want to include in the ConTeXt package
# but aren't part of the ConTeXt standalone distribution.
packaging="$root/files/"

# This is where we'll place all of the files that we'll ultimately zip up and
# upload to GitHub.
staging="$root/staging/"

# Any files placed in this folder will be uploaded to GitHub as part of the
# release.
output="$root/output/"


###############
### Folders ###
###############

# The ConTeXt runtime files
mkdir -p "$staging/context.tds/"

# The ConTeXt Documentation
mkdir -p "$staging/context.doc/"

# The LuaMetaTeX source code
mkdir -p "$staging/luametatex.src/"

# The non-free (but freely redistributable) ConTeXt files
mkdir -p "$staging/context-nonfree.tds/"

# Create folders for each platform in a separate binaries tree.
for tl_platform in "${context_platforms[@]}" "${luametatex_platforms[@]}"; do
    mkdir -p "$staging/context.bin/$tl_platform/"
done

# The output folder is where we'll place the final zip files.
mkdir -p "$output/"


################
### Binaries ###
################

# All other TeX engines are built as a part of TeX Live once per year; however,
# LuaMetaTeX needs to be built separately from the rest of the engines (since it
# uses cmake instead of autotools), and each new ConTeXt texmf release depends
# on the latest LuaMetaTeX release. So, we'll package the LuaMetaTeX binaries
# with the rest of the ConTeXt content.

# First, we handle the binaries for officially supported platforms.
for ctx_platform in "${!context_platforms[@]}"; do
    tl_platform="${context_platforms[$ctx_platform]}"

    # Copy the binaries themselves
    cp -a "$source/texmf-$ctx_platform/bin/"* \
        "$staging/context.bin/$tl_platform/"

    # Fix the symlinks to point inside the $TEXMFDIST tree
    ln -sf ../../texmf-dist/scripts/context/lua/context.lua \
        "$staging/context.bin/$tl_platform/context.lua"

    ln -sf ../../texmf-dist/scripts/context/lua/mtxrun.lua \
        "$staging/context.bin/$tl_platform/mtxrun.lua"

    # We don't want to overwrite TL's luatex
    rm -f "$staging/context.bin/$tl_platform/luatex"
done

# Now, let's handle the binaries for the unsupported platforms.
for tl_platform in "${luametatex_platforms[@]}"; do
    # Download the binaries from the ConTeXt Build Farm
    curl -sSL \
        "https://build.contextgarden.net/dl/luametatex/work/$tl_platform/luametatex" \
        -o "$staging/context.bin/$tl_platform/luametatex"

    # Symbolic links
    ln -s "$staging/context.bin/$tl_platform/luametatex" \
        "$staging/context.bin/$tl_platform/mtxrun"

    ln -s "$staging/context.bin/$tl_platform/luametatex" \
        "$staging/context.bin/$tl_platform/context"

    ln -sf ../../texmf-dist/scripts/context/lua/context.lua \
        "$staging/context.bin/$tl_platform/context.lua"

    ln -sf ../../texmf-dist/scripts/context/lua/mtxrun.lua \
        "$staging/context.bin/$tl_platform/mtxrun.lua"
done

# The ConTeXt Standalone Distribution uses separate x86_64 and arm64 binaries
# for macOS, but TeX Live uses a universal binary. We'll need to combine the
# two binaries into a single universal binary using llvm-lipo.
rm -r "$staging/context.bin/universal-darwin/luametatex"

llvm-lipo -create \
    -output "$staging/context.bin/universal-darwin/luametatex" \
    "$source/texmf-osx-64/bin/luametatex" \
    "$source/texmf-osx-arm64/bin/luametatex"

# The ConTeXt Standalone Distribution is missing the symlinks for Windows, so
# let's add them now.
ln -s "./luametatex.exe" "$staging/context.bin/windows/mtxrun.exe" || true
ln -s "./luametatex.exe" "$staging/context.bin/windows/context.exe" || true


#############
### Fonts ###
#############

# The ConTeXt Standalone Distribution places fonts in two separate trees: texmf/
# and texmf-context/.
#
# The fonts in texmf/ almost exclusively consist of fonts that are already in
# TeX Live via other packages; the only exceptions are the ConTeXt Math
# Companion fonts and CC Icons.
#
# The fonts in texmf-context/ consist of .tfm/.afm/.pfb files (unused by MkIV
# and MkXL), koeieletters (non-free), and lmtypewriter (the only font we'll copy
# over).

# texmf/
mkdir -p "$staging/context.tds/fonts/opentype/public/"
cp -a "$source/texmf/fonts/data/cms/companion/" \
    "$staging/context.tds/fonts/opentype/public/context/"

mkdir -p "$staging/context.tds/fonts/truetype/public/context/"
cp -a "$source/texmf/fonts/data/public/cc-icons/cc-icons.ttf" \
    "$staging/context.tds/fonts/truetype/public/context/"

mkdir -p "$staging/context.doc/doc/fonts/context/"
mv "$staging/context.tds/fonts/opentype/public/context/readme.txt" \
    "$staging/context.doc/doc/fonts/context/readme.txt"

# texmf-context/
mkdir -p "$staging/context.tds/fonts/truetype/public/context/"
cp -a \
    "$source/texmf-context/fonts/truetype/hoekwater/lm/lmtypewriter10-regular.ttf" \
    "$staging/context.tds/fonts/truetype/public/context/"

# Non-free
mkdir -p "$staging/context-nonfree.tds/fonts/truetype/public/context/"
cp -a \
    "$source/texmf-context/fonts/truetype/hoekwater/koeieletters/koeielettersot.ttf" \
    "$staging/context-nonfree.tds/fonts/truetype/public/context/"

mkdir -p "$staging/context-nonfree.tds/doc/fonts/context/"
cp -a \
    "$source/texmf-context/doc/fonts/hoekwater/koeieletters/koeieletters.rme" \
    "$staging/context-nonfree.tds/doc/fonts/context/koeielettersot.txt"


#####################
### Documentation ###
#####################

# The ConTeXt documentation is quite large, so we'll place it in a separate zip
# file from the runtime files. Ultimately, TeX Live will install the
# documentation into the same $TEXMFDIST tree as the runtime files (albeit via a
# different .tar.xz tlpkg file).

# PDF documentation
mkdir -p "$staging/context.doc/doc/"
cp -a "$source/texmf-context/doc/context/" "$staging/context.doc/doc/context/"

# ConTeXt READMEs
cp -a "$source/texmf-context/context-readme.txt" \
    "$staging/context.doc/doc/context/README-CONTEXT-DISTRIBUTION.txt"

cp -a "$packaging/README-PACKAGING.md" \
    "$staging/context.doc/doc/context/"

# Copy the ConTeXt man pages to the TeX Live MANPATH.
mkdir -p "$staging/context.doc/doc/man/man1/"

cp -a "$source/texmf-context/doc/context/scripts/mkiv/"*.man \
    "$staging/context.doc/doc/man/man1/"

prename 's/.man$/.1/' "$staging/context.doc/doc/man/man1/"*


###############
### Scripts ###
###############

# Unlike most other TeX formats, ConTeXt depends on a number of scripts to run.

# MkIV and MkXL only use the Lua scripts
mkdir -p "$staging/context.tds/scripts/context/"
cp -a "$source/texmf-context/scripts/context/lua/" \
    "$staging/context.tds/scripts/context/"

# The pdftrimwhite.pl script is still useful, so let's copy it over.
mkdir -p "$staging/context.tds/scripts/context/perl/"
cp -a "$source/texmf-context/scripts/context/perl/pdftrimwhite.pl" \
    "$staging/context.tds/scripts/context/perl/"

# The mtx-install and mtx-install-modules scripts are used to upgrade the
# ConTeXt distribution and to install modules from the ConTeXt Garden. Since
# tlmgr handles this itself, we'll remove these scripts so that users don't
# accidentally break their ConTeXt installation.
rm "$staging/context.tds/scripts/context/lua/mtx-install"{,-modules}.lua


###########
### TeX ###
###########

# The tex/context/ folder is already laid out correctly, so we can just copy it
# over.
mkdir -p "$staging/context.tds/tex/"
cp -a "$source/texmf-context/tex/context/" "$staging/context.tds/tex/"

# ConTeXt also distributes a Plain-like "luatex-plain" format which might be
# used by some users. We'll copy it over as well.
mkdir -p "$staging/context.tds/tex/luatex/"
cp -a "$source/texmf-context/tex/generic/context/luatex/" \
    "$staging/context.tds/tex/luatex/context/"

# These files belong in the doc/ folder instead.
mv "$staging/context.tds/tex/context/filenames.tex" \
    "$staging/context.doc/doc/context/"

mv "$staging/context.tds/tex/context/base/context.rme" \
    "$staging/context.doc/doc/context/README.txt"

mkdir -p "$staging/context.doc/doc/context/sample/"
mv "$staging/context.tds/tex/context/sample/third/readme.txt" \
    "$staging/context.doc/doc/context/sample/"

# # This folder belongs in the bibtex/bib/ folder, but Karl complained, so we'll
# # leave it as-is :).
# mkdir -p "$staging/context.tds/bibtex/bib/"
# mv "$staging/context.tds/tex/context/bib/common/" \
#     "$staging/context.tds/bibtex/bib/context/"
#
# rm -rf "$staging/context.tds/tex/context/bib/"

# Almost certainly obsolete, but I can bring it back if someone complains.
rm -rf "$staging/context.tds/tex/context/modules/common/"

# Unneeded with tlmgr.
rm -rf "$staging/context.tds/tex/context/modules/third/mtx-install-"*.lua

# Empty, useless files.
rm -rf "$staging/context.tds/tex/context/patterns/common/lang-"*.rme

# # Karl complained about these, but they're too commonly used to (re)move.
# rm -rf "$staging/context.tds/tex/context/sample/"

# TeX Live-specific files
mkdir -p "$staging/context.tds/tex/context/texlive/"
cp -a "$packaging/cont-sys.mkxl" \
    "$staging/context.tds/tex/context/texlive/cont-sys.mkxl"

cp -a "$packaging/cont-sys.mkxl" \
    "$staging/context.tds/tex/context/texlive/cont-sys.mkiv"


######################
### Engine Sources ###
######################

# ConTeXt stores the engine sources in TEXMF/source/, but TeX Live uses
# TEXMF/source/ for TeX sources and stores the engine sources in the SVN
# repository. So we'll move the engine sources to a separate zip file so that
# they can be properly imported into the TeX Live SVN repository.
cp -a "$source/texmf-context/source/luametatex/"* "$staging/luametatex.src/"


###############################
### Other top-level folders ###
###############################

# colors/ is ConTeXt-specific, so we'll move it to tex/context/.
mkdir -p "$staging/context.tds/tex/context/colors/"
cp -a "$source/texmf-context/colors/icc/"* \
    "$staging/context.tds/tex/context/colors/"

mkdir -p "$staging/context.doc/doc/context/colors/profiles/"
mv "$staging/context.tds/tex/context/colors/profiles/colo-imp-icc.rme" \
    "$staging/context.doc/doc/context/colors/profiles/README.txt"

# metapost/ is already laid out correctly, so we can just copy it over.
cp -a "$source/texmf-context/metapost/" \
    "$staging/context.tds/metapost/"

# Install our customized texmfcnf.lua file. ConTeXt uses this file to set some
# runtime parameters (much like the standard texmf.cnf file).
mkdir -p "$staging/context.tds/web2c/"
cp -a "$packaging/texmfcnf.lua" \
    "$staging/context.tds/web2c/texmfcnf.lua"


######################
### Non-free files ###
######################

# The ConTeXt Standalone Distribution contains a number of non-free files that
# cannot be distributed with TeX Live. However, these files are still freely
# redistributable, so they are included in the tlcontrib repository.

# These two colour profiles have unclear licenses
mkdir -p "$staging/context-nonfree.tds/tex/context/colors/profiles/"
mv \
    "$staging/context.tds/tex/context/colors/profiles/colo-imp-"{srgb,isocoated_v2_eci}.icc \
    "$staging/context-nonfree.tds/tex/context/colors/profiles/"

# These Lua Font Goodie files are themselves free, but they exist only to
# support non-free fonts, so we'll move them to the non-free folder.
mkdir -p "$staging/context-nonfree.tds/tex/context/fonts/mkiv/"
mv \
    "$staging/context.tds/tex/context/fonts/mkiv/"*{cambria,koeiel,lucida,mathtimes,minion}*.lfg \
    "$staging/context-nonfree.tds/tex/context/fonts/mkiv/"


###############
### Cleanup ###
###############

# Some files have \r\n line endings, so let's fix them up.
find "$staging/" -type f -print0 | xargs -0 dos2unix --safe

# Remove any empty folders that were created by the packaging script.
find "$staging/" -type d -empty -delete


#################
### Packaging ###
#################

# First, we'll zip up every tree individually.
cd "$staging/"
for folder in ./*; do
    folder_name="$(basename "$folder")"
    cd "$staging/$folder_name/"
    zip --no-dir-entries --strip-extra --symlinks --recurse-paths \
        "$output/$folder_name.zip" ./*
done
cd "$root/"

# Make the zip files deterministic
add-determinism "$output/"*.zip

# Now, we can prepare the CTAN archive. First, let's add the individual zip
# files, the README.md file, and the VERSION file.
mkdir -p "$staging/context.ctan/"
cp -a "$output/"*.zip \
    "$staging/context.ctan/"

cp -a "$root/README.md" \
    "$staging/context.ctan/README.md"

echo "$pretty_version" > "$staging/context.ctan/VERSION"

# Next, we'll add the flattened tex/ tree.
mkdir -p "$staging/context.ctan/tex/mkiv/"
find "$staging/context.tds/tex/" "$staging/context-nonfree.tds/tex/" \
    -type f -path '*/mkiv/*' -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/tex/mkiv/"

mkdir -p "$staging/context.ctan/tex/mkxl/"
find "$staging/context.tds/tex/" "$staging/context-nonfree.tds/tex/" \
    -type f -path '*/mkxl/*' -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/tex/mkxl/"

mkdir -p "$staging/context.ctan/tex/misc/"
find "$staging/context.tds/tex/" "$staging/context-nonfree.tds/tex/" \
    \( -not -path '*/mkiv/*' \) -a \( -not -path '*/mkxl/*' \) \
    -type f  -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/tex/misc/"

# And the flattened doc/ tree.
mkdir -p "$staging/context.ctan/doc/"
find "$staging/context.doc/doc/" "$staging/context-nonfree.tds/doc/" \
    -type f \( -iname '*.pdf' -o -iname '*.html' \) -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/doc/"

# And the flattened scripts/ tree.
mkdir -p "$staging/context.ctan/scripts/"
find "$staging/context.tds/scripts/" \
    -type f -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/scripts/"

# And the flattened fonts/ tree.
mkdir -p "$staging/context.ctan/fonts/"
find "$staging/context.tds/fonts/" "$staging/context-nonfree.tds/fonts/" \
    -type f -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/fonts/"

# And the flattened metapost/ tree.
mkdir -p "$staging/context.ctan/metapost/"
find "$staging/context.tds/metapost/" \
    -type f -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/metapost/"

# Copy over the support files for the binaries (but not the binaries, yet).
mkdir -p "$staging/context.ctan/bin/"

cp -a "$staging/context.bin/windows/"* "$staging/context.ctan/bin/"
rm -f "$staging/context.ctan/bin/luametatex.exe"

cp -af "$staging/context.bin/x86_64-linux/"* "$staging/context.ctan/bin/"
rm -f "$staging/context.ctan/bin/luametatex"

# And the binaries themselves.
for tl_platform in "${context_platforms[@]}" "${luametatex_platforms[@]}"; do
    # Trailing asterisk to get the ".exe" for Windows.
    cp -a "$staging/context.bin/$tl_platform/luametatex"* \
        "$staging/context.ctan/bin/luametatex-$tl_platform"
done

# We needed the "--backup=numbered" flag to avoid the "cp: will not overwrite
# just-created" error, so now we'll remove all of the numbered backup files.
find "$staging/context.ctan/" -type f -name '*.~*~' -delete

# Finally, we can zip up the CTAN archive.
cd "$staging/context.ctan/"
zip --no-dir-entries --strip-extra --symlinks --recurse-paths \
    "$output/context.ctan.zip" ./*
cd "$root/"

# Make the CTAN zip file deterministic
add-determinism "$output/context.ctan.zip"

# Clean up by removing the staging folder.
rm -rf "${staging:?}/"

###############
### Testing ###
###############

# Now, let's validate that we generated a functioning ConTeXt package.

# (TODO!)
