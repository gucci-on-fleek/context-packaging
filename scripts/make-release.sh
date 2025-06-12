#!/usr/bin/env bash
# ConTeXt Packaging Scripts
# https://github.com/gucci-on-fleek/context-packaging
# SPDX-License-Identifier: CC0-1.0+
# SPDX-FileCopyrightText: 2025 Max Chernoff
set -euxo pipefail


#################
### Variables ###
#################

# Force the locale to C.UTF-8
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# The ConTeXt standalone distribution is updated daily on the server, and it is
# bind-mounted into this container at this path.
source="/opt/context/"

# This is where we will unpack the .zip file that also includes the .mkii files.
legacy_source="/tmp/context-legacy/"

# An installation of TeX Live is bind-mounted into this container at this path.
texlive="/opt/texlive/"

# A mapping from the ConTeXt platform names to TeX Live platform names.
declare -A context_platforms=(
    ["freebsd-amd64"]="amd64-freebsd"
    ["linux-64"]="x86_64-linux"
    ["linux-aarch64"]="aarch64-linux"
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
# shellcheck disable=SC2034
luametatex_platforms=(
    "armhf-linux"
    "i386-freebsd"
    "i386-solaris"
    "sparc-solaris"  # Built by the Build Farm, but not supported by TeX Live.
    "x86_64-solaris"
)

# No binaries for these platforms unfortunately.
# shellcheck disable=SC2034
missing_platforms=(
    "amd64-netbsd"  # ConTeXt Build Farm builder is broken
    "i386-netbsd"  # Not built by the Build Farm
    "x86_64-cygwin"  # Not built by the Build Farm
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

# Where we will place the files used for testing.
testing="$root/testing/"

# Where the build scripts are located.
scripts="$root/scripts/"


##################
### Versioning ###
##################

# The version of ConTeXt that we're packaging, with no spaces or colons.
safe_version="$(git describe --exact-match --tags)"

# The version of ConTeXt that we're packaging, with spaces and colons.
pretty_version="$(\
    echo "$safe_version" | \
    sed -E 's/([[:digit:]]{4})-([[:digit:]]{2})-([[:digit:]]{2})-([[:digit:]]{2})-([[:digit:]]{2})-([[:upper:]]{1})/\1-\2-\3 \4:\5 \6/'\
)"

# The version of ConTeXt itself, without the suffix for my interim releases.
only_version="$(echo "$pretty_version" | sed -E 's/ [[:upper:]]$//')"

# Make sure that we're running against the correct version of ConTeXt.
_context_version="$( \
    grep -oP '(?<=def\\contextversion\{)(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2})' \
    $source/texmf-context/tex/context/base/mkxl/context.mkxl | \
    tr '.' '-'
)"

if test "$_context_version" != "$only_version"; then
    echo "The ConTeXt version in the source code ($_context_version) does not match the version in the Git tag ($safe_version)."
    exit 1
fi

# Get the version of LuaMetaTeX from the source code.
luametatex_version="$(\
    grep -P '#\s*define\s*luametatex_development_id' \
    "$source/texmf-context/source/luametatex/source/luametatex.h" | \
    grep -oP '\d+' \
)"

# Set the date to use for all further operations
SOURCE_DATE_EPOCH="$(\
    date --date="TZ=\"Europe/Amsterdam\" $pretty_version" '+%s'\
)"
export SOURCE_DATE_EPOCH
export FORCE_SOURCE_DATE=1


###############
### Folders ###
###############

# The ConTeXt runtime files.
mkdir -p "$staging/context.tds/"

# The ConTeXt legacy runtime files.
mkdir -p "$staging/context-legacy.tds/"

# The LuaMetaTeX source code.
mkdir -p "$staging/luametatex.src/"

# The non-free (but freely redistributable) ConTeXt files.
mkdir -p "$staging/context-nonfree.tds/"

# The "mptopdf" package is derived from the ConTeXt MkII source, yet distributed
# by TL as a separate package.
mkdir -p "$staging/mptopdf.tds/"

# Create folders for each platform in a separate binaries tree.
for tl_platform in "${context_platforms[@]}"; do
    mkdir -p "$staging/context.bin/$tl_platform/"
done

# The output folder is where we'll place the final zip files.
mkdir -p "$output/"

# The testing folder is where we'll place the files used for testing.
mkdir -p "$testing/"

# The legacy source folder is where we'll find the original MkII files.
mkdir -p "$legacy_source/"


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

    # We don't want to overwrite TL's luatex. With a trailing asterisk to get
    # the ".exe" for Windows.
    rm -f "$staging/context.bin/$tl_platform/luatex"*
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

mkdir -p "$staging/context.tds/doc/fonts/context/"
mv "$staging/context.tds/fonts/opentype/public/context/readme.txt" \
    "$staging/context.tds/doc/fonts/context/readme.txt"

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
    "$staging/context-nonfree.tds/doc/fonts/context/koeieletters.txt"


#####################
### Documentation ###
#####################

# The ConTeXt documentation is quite large, so we'll place it in a separate zip
# file from the runtime files. Ultimately, TeX Live will install the
# documentation into the same $TEXMFDIST tree as the runtime files (albeit via a
# different .tar.xz tlpkg file).

# PDF documentation
mkdir -p "$staging/context.tds/doc/"
cp -a "$source/texmf-context/doc/context/" "$staging/context.tds/doc/context/"

# These PDF files only contain ASCII characters, so we'll append a null byte to
# them so that dos2unix doesn't mangle them.
for pdf_file in "$staging/context.tds/doc/context/sources/general/manuals/start/graphics/fig-page-"*.pdf; do
    # Append a null byte to the end of the file.
    printf '%%\0\n' >> "$pdf_file"
done

# ConTeXt READMEs
cp -a "$source/texmf-context/context-readme.txt" \
    "$staging/context.tds/doc/context/README-CONTEXT-DISTRIBUTION.txt"

cp -a "$packaging/README-PACKAGING.md" \
    "$staging/context.tds/doc/context/"

# ConTeXt VERSION and DEPENDS files
echo "$pretty_version" > "$staging/context.tds/doc/context/VERSION"
cp -a "$packaging/DEPENDS.txt" \
    "$staging/context.tds/doc/context/"

# LuaMetaTeX READMEs
mkdir -p "$staging/context.tds/doc/luametatex/base/"
cp -a "$source/texmf-context/source/luametatex/source/readme.txt" \
    "$staging/context.tds/doc/luametatex/base/README"

cp -a "$source/texmf-context/source/luametatex/source/readme.txt" \
    "$staging/context.tds/doc/luametatex/base/LICENSE"

# Move the LuaMetaTeX documents from the ConTeXt folder to the LuaMetaTeX
# folder.
find "$staging/context.tds/doc/context/" \
    \( -not -path '*/presentations/*' \) -iname '*luametatex*' \
    -type f -print0 | \
    xargs -0 mv \
    --target-directory="$staging/context.tds/doc/luametatex/base/"

# The LuaTeX manual is already included in TeX Live, so we don't need to copy it
# over.
rm -f "$staging/context.tds/doc/context/documents/general/manuals/luatex.pdf"

# Rename the "mtx-..." manpages to "mtxrun-..." to match the typical Unix
# conventions.
prename 's/mtx-/mtxrun-/' \
    "$staging/context.tds/doc/context/scripts/mkiv/"*

# Remove the "mtxrun-install*" man pages, since we're not installing the
# corresponding scripts.
rm -f \
    "$staging/context.tds/doc/context/scripts/mkiv/mtxrun-install"*

# Copy the ConTeXt man pages to the TeX Live MANPATH.
mkdir -p "$staging/context.tds/doc/man/man1/"

cp -a "$staging/context.tds/doc/context/scripts/mkiv/"*.man \
    "$staging/context.tds/doc/man/man1/"

prename 's/.man$/.1/' "$staging/context.tds/doc/man/man1/"*


###############
### Scripts ###
###############

# Unlike most other TeX formats, ConTeXt depends on a number of scripts to run.

# MkIV and MkXL only use the Lua scripts
mkdir -p "$staging/context.tds/scripts/context/"
cp -a "$source/texmf-context/scripts/context/lua/" \
    "$staging/context.tds/scripts/context/"

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
    "$staging/context.tds/doc/context/"

mv "$staging/context.tds/tex/context/base/context.rme" \
    "$staging/context.tds/doc/context/README.txt"

mkdir -p "$staging/context.tds/doc/context/sample/"
mv "$staging/context.tds/tex/context/sample/third/readme.txt" \
    "$staging/context.tds/doc/context/sample/"

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

mkdir -p "$staging/context.tds/doc/context/colors/profiles/"
mv "$staging/context.tds/tex/context/colors/profiles/colo-imp-icc.rme" \
    "$staging/context.tds/doc/context/colors/profiles/README.txt"

# metapost/ is already laid out correctly, so we can just copy it over.
cp -a "$source/texmf-context/metapost/" \
    "$staging/context.tds/metapost/"

# Install our customized texmfcnf.lua file. ConTeXt uses this file to set some
# runtime parameters (much like the standard texmf.cnf file).
mkdir -p "$staging/context.tds/web2c/"
cp -a "$packaging/texmfcnf.lua" \
    "$staging/context.tds/web2c/texmfcnf.lua"

# The lexers used by the SciTE editor are also used by ConTeXt itself.
mkdir -p "$staging/context.tds/tex/context/"
cp -a "$source/texmf-context/context/data/scite/context/lexers/" \
    "$staging/context.tds/tex/context/lexers/"


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

# The following files are acceptable to include in TeX Live, but Hans
# specifically requested (2025-05-29) that we not include any files that depend
# upon missing .lfg files, so that users never accidentally typeset documents
# with the goodie files missing and get poor output quality as a result.
mv \
    "$staging/context.tds/tex/context/fonts/mkiv/type-imp-"{cambria,koeielettersot,lucida,lucida-typeone,mathtimes,minion,mscore}.mkiv \
    "$staging/context-nonfree.tds/tex/context/fonts/mkiv/"

# Documentation
mkdir -p "$staging/context-nonfree.tds/doc/context/"
cp -a "$packaging/README-NONFREE.md" \
    "$staging/context-nonfree.tds/doc/context/"


#####################
### Legacy (MkII) ###
#####################

# First, we need to download and unpack the legacy ConTeXt distribution.
curl -sSL \
    "https://www.pragma-ade.nl/context/latest/cont-tmf.zip" \
    -o "$legacy_source/cont-tmf.zip"

unzip -q -d "$legacy_source/" \
    "$legacy_source/cont-tmf.zip"

rm -f "$legacy_source/cont-tmf.zip"

# Remove any files already installed by the other ConTeXt packages.
cd "$legacy_source/"
find "$legacy_source/" -type f -printf '%P\n' | \
    grep --file <( \
        comm -12 \
        <(find "$staging/" -type f -printf '%f\n' | sort | uniq) \
        <(find "$legacy_source/" -type f -printf '%f\n' | sort | uniq) | \
        sed -e 's/\./\\./g' -e 's/$/$/'
    ) | xargs rm

cd "$root/"

# Remove the "mtx-" man pages, since they're already included in the other
# ConTeXt packages.
find "$legacy_source/doc/context/scripts/" -iname 'mtx-*' -delete

# Remove the LuaTeX manual, since it is already included in TeX Live.
rm -f "$legacy_source/doc/context/documents/general/manuals/luatex.pdf"

# Remove any files that only work with the ConTeXt distribution, not TeX Live.
rm -rf \
    "$legacy_source/doc/context/scripts/mkiv/mtx-install"* \
    "$legacy_source/scripts/context/lua/mtx-install"*.lua \
    "$legacy_source/scripts/context/stubs/" \
    "$legacy_source/tex/context/base/context.rme" \
    "$legacy_source/tex/context/modules/third/mtx-install"*.lua \
    "$legacy_source/tex/context/patterns/common/"*.rme

# Ok, now we'll go over the top-level folders one-by-one.

# doc/
mkdir -p "$staging/context-legacy.tds/doc/context/"
cp -a "$legacy_source/doc/context/"* \
    "$staging/context-legacy.tds/doc/context/"

# Man pages
mkdir -p "$staging/context-legacy.tds/doc/man/man1/"

cp -a "$legacy_source/doc/context/scripts/mkii/"{texmfstart,texexec}.man \
    "$staging/context-legacy.tds/doc/man/man1/"

prename 's/.man$/.1/' "$staging/context-legacy.tds/doc/man/man1/"*

# tex/
mkdir -p "$staging/context-legacy.tds/tex/"
cp -a "$legacy_source/tex/context/" \
    "$staging/context-legacy.tds/tex/"

mkdir -p "$staging/context-legacy.tds/tex/generic/"
cp -a "$legacy_source/tex/generic/context/" \
    "$staging/context-legacy.tds/tex/generic/"

mv "$staging/context-legacy.tds/tex/context/user/mkii/cont-sys.rme" \
    "$staging/context-legacy.tds/tex/context/user/mkii/cont-sys.mkii"

rm "$staging/context-legacy.tds/tex/context/base/mkii/cont-sys.ori"

# bibtex/
mkdir -p "$staging/context-legacy.tds/bibtex/bst/context/"
cp -a "$legacy_source/bibtex/bst/context/mkii/" \
    "$staging/context-legacy.tds/bibtex/bst/context/"

# colors/
# (already in context.tds/)

# context/
cp -a "$legacy_source/context/data/texfont/"* \
    "$staging/context-legacy.tds/tex/context/fonts/mkii/"

# fonts/
mkdir -p "$staging/context-legacy.tds/fonts/enc/dvips/"
cp -a "$legacy_source/fonts/enc/dvips/context/" \
    "$staging/context-legacy.tds/fonts/enc/dvips/"

mkdir -p "$staging/context-legacy.tds/fonts/enc/pdftex/"
cp -a "$legacy_source/fonts/enc/pdftex/context/" \
    "$staging/context-legacy.tds/fonts/enc/pdftex/"

mkdir -p "$staging/context-legacy.tds/fonts/map/dvips/"
cp -a "$legacy_source/fonts/map/dvips/context/" \
    "$staging/context-legacy.tds/fonts/map/dvips/"

mkdir -p "$staging/context-legacy.tds/fonts/map/pdftex/"
cp -a "$legacy_source/fonts/map/pdftex/context/" \
    "$staging/context-legacy.tds/fonts/map/pdftex/"

mkdir -p "$staging/context-legacy.tds/fonts/afm/public/"
cp -a "$legacy_source/fonts/afm/hoekwater/context/" \
    "$staging/context-legacy.tds/fonts/afm/public/"

mkdir -p "$staging/context-legacy.tds/fonts/cid/context/"
cp -a "$legacy_source/fonts/cid/fontforge/"* \
    "$staging/context-legacy.tds/fonts/cid/context/"

mkdir -p "$staging/context-legacy.tds/fonts/misc/xetex/fontmapping/"
cp -a "$legacy_source/fonts/misc/xetex/fontmapping/context/" \
    "$staging/context-legacy.tds/fonts/misc/xetex/fontmapping/"

mkdir -p "$staging/context-legacy.tds/fonts/tfm/public/"
cp -a "$legacy_source/fonts/tfm/hoekwater/context/" \
    "$staging/context-legacy.tds/fonts/tfm/public/"

mkdir -p "$staging/context-legacy.tds/fonts/type1/public/"
cp -a "$legacy_source/fonts/type1/hoekwater/context/" \
    "$staging/context-legacy.tds/fonts/type1/public/"

# metapost/
mkdir -p "$staging/context-legacy.tds/metapost/"
cp -a "$legacy_source/metapost/context/" \
    "$staging/context-legacy.tds/metapost/"

# scripts/
mkdir -p "$staging/context-legacy.tds/scripts/"
cp -a "$legacy_source/scripts/context/" \
    "$staging/context-legacy.tds/scripts/"

mkdir -p "$staging/context-legacy.tds/scripts/context/stubs/"{unix,win64}/
cp -a "$packaging/"{texexec,texmfstart} \
    "$staging/context-legacy.tds/scripts/context/stubs/unix/"

cp -a "$packaging/"{texexec,texmfstart}.cmd \
    "$staging/context-legacy.tds/scripts/context/stubs/win64/"

# source/
# (already in luametatex.src/)

# web2c/
# (handled by TeX Live itself)

# Non-free
mkdir -p "$staging/context-nonfree.tds/fonts/enc/pdftex/context/"
mv \
    "$staging/context-legacy.tds/fonts/enc/pdftex/context/koe"* \
    "$staging/context-nonfree.tds/fonts/enc/pdftex/context/"

mkdir -p "$staging/context-nonfree.tds/fonts/map/pdftex/context/"
mv \
    "$staging/context-legacy.tds/fonts/map/pdftex/context/koe"* \
    "$staging/context-nonfree.tds/fonts/map/pdftex/context/"

mkdir -p "$staging/context-nonfree.tds/fonts/enc/dvips/context/"
mv \
    "$staging/context-legacy.tds/fonts/enc/dvips/context/teff-trinite.enc" \
    "$staging/context-nonfree.tds/fonts/enc/dvips/context/"

mkdir -p "$staging/context-nonfree.tds/fonts/afm/public/context/"
cp -a \
    "$legacy_source/fonts/afm/hoekwater/koeieletters/"* \
    "$staging/context-nonfree.tds/fonts/afm/public/context/"

mkdir -p "$staging/context-nonfree.tds/fonts/tfm/public/context/"
cp -a \
    "$legacy_source/fonts/tfm/hoekwater/koeieletters/"* \
    "$staging/context-nonfree.tds/fonts/tfm/public/context/"

mkdir -p "$staging/context-nonfree.tds/fonts/type1/public/context/"
cp -a \
    "$legacy_source/fonts/type1/hoekwater/koeieletters/"* \
    "$staging/context-nonfree.tds/fonts/type1/public/context/"
mv \
    "$staging/context-legacy.tds/fonts/type1/public/context/koeieletters.pfm" \
    "$staging/context-nonfree.tds/fonts/type1/public/context/koeieletters.pfm"

mkdir -p "$staging/context-nonfree.tds/fonts/vf/public/context/"
cp -a \
    "$legacy_source/fonts/vf/hoekwater/koeieletters/"* \
    "$staging/context-nonfree.tds/fonts/vf/public/context/"


###############
### mptopdf ###
###############

# tex/generic/
mkdir -p "$staging/mptopdf.tds/tex/generic/context/"

mv "$staging/context-legacy.tds/tex/generic/context/mptopdf/" \
    "$staging/mptopdf.tds/tex/generic/context/"

# tex/context/
mkdir -p "$staging/mptopdf.tds/tex/context/base/mkii/"

mv "$staging/context-legacy.tds/tex/context/base/mkii/supp-"{mis,mpe,pdf}.mkii \
    "$staging/context-legacy.tds/tex/context/base/mkii/syst-tex.mkii" \
    "$staging/mptopdf.tds/tex/context/base/mkii/"

# scripts/
mkdir -p "$staging/mptopdf.tds/scripts/context/perl/"

mv "$staging/context-legacy.tds/scripts/context/perl/mptopdf.pl" \
    "$staging/mptopdf.tds/scripts/context/perl/"

# doc/
mkdir -p "$staging/mptopdf.tds/doc/context/scripts/mkii/"
mv "$staging/context-legacy.tds/doc/context/scripts/mkii/mptopdf"* \
    "$staging/mptopdf.tds/doc/context/scripts/mkii/"

mkdir -p "$staging/mptopdf.tds/doc/man/man1/"
cp "$staging/mptopdf.tds/doc/context/scripts/mkii/mptopdf.man" \
    "$staging/mptopdf.tds/doc/man/man1/mptopdf.1"


###############
### Cleanup ###
###############

# Some files have \r\n line endings, so let's fix them up.
find "$staging/" -type f -print0 | xargs -0 dos2unix --safe > /dev/null 2>&1

# Remove any empty folders that were created by the packaging script.
find "$staging/" -type d -empty -delete


#################
### Packaging ###
#################

# Let's normalize all the permissions.
chown -R root:root "$staging/"
chmod -R a=rX,u+w "$staging/"

# Re-add the executable bit to all of the scripts and binaries.
find "$staging/context.bin/" \
    \( -name 'luametatex' -o -name 'luametatex.exe' \) \
    -type f -print0 | \
    xargs -0 chmod a+x

grep --recursive --files-with-matches --null '^#!/' "$staging/" | \
    xargs -0 chmod a+x

find "$staging/" -type f \( -iname '*.cmd' -o -iname '*.bat' \) -print0 | \
    xargs -0 chmod a+x

# Reset the date on all the files in context.bin/ since we can't use
# add-determinism there.
find "$staging/context.bin/" -print0 | \
    xargs -0 touch --no-dereference --date="@$SOURCE_DATE_EPOCH"

# Manually zip up the LuaMetaTeX source code first so that we can add it to the
# TDS archive.
cd "$staging/luametatex.src/"

zip --quiet --no-dir-entries --strip-extra --symlinks --recurse-paths \
    "$output/luametatex.src.zip" ./*

add-determinism "$output/luametatex.src.zip"

cd "$root/"

# Now we can copy the zipped LuaMetaTeX source code to the TDS archive.
mkdir -p "$staging/context.tds/source/context/base/"
cp -a "$output/luametatex.src.zip" \
    "$staging/context.tds/source/context/base/luametatex-$luametatex_version.src.zip"

# Next, we'll zip up every tree individually.
cd "$staging/"
for folder in ./*; do
    folder_name="$(basename "$folder")"

    # Skip if the zip file already exists.
    if test -f "$output/$folder_name.zip"; then
        echo "Skipping $folder_name, zip file already exists."
        continue
    fi

    cd "$staging/$folder_name/"
    zip --quiet --no-dir-entries --strip-extra --symlinks --recurse-paths \
        "$output/$folder_name.zip" ./*

    # Make the zip files deterministic
    if test "$folder_name" != "context.bin"; then
        # add-determinism breaks the symlinks, so only run it on the zips that
        # don't contain any symlinks.
        add-determinism "$output/$folder_name.zip"
    fi
done
cd "$root/"

# Now, we can prepare the CTAN archive. First, let's add the individual zip
# files.
mkdir -p "$staging/context.ctan/context/archives/"
cp -a "$output/"*.zip \
    "$staging/context.ctan/context/archives/"

# Remove the .tds suffix from the zip files so that the CTAN scripts don't get
# confused.
prename 's/\.tds\.zip$/.zip/' \
    "$staging/context.ctan/context/archives/"*.zip

# Rename the LuaMetaTeX source zip to include the version number.
mv "$staging/context.ctan/context/archives/luametatex.src.zip" \
    "$staging/context.ctan/context/archives/luametatex-$luametatex_version.src.zip"

# Add the INSTALLING.md file to explain the archives.
cp -a "$packaging/INSTALLING.md" \
    "$staging/context.ctan/context/archives/INSTALLING.md"

# Now, we'll add the README.md and the VERSION files.
cp -a "$root/README.md" \
    "$staging/context.ctan/context/README.md"

echo "$pretty_version" > "$staging/context.ctan/context/VERSION"

# Now, we'll handle the DEPENDS file by copying it to the CTAN folder, and then
# appending the list of packages included with the ConTeXt standalone
# distribution.
cp -a "$packaging/DEPENDS.txt" \
    "$staging/context.ctan/context/"

tlmgr search --file \
    "texmf-dist/(tex|scripts|fonts|metapost)/.*/($(\
        find "$source/texmf/fonts/" \
        "$source/texmf-modules/"{tex,scripts,fonts,metapost}/ \
        -regextype egrep -type f \
        -iregex '.*\.(mkxl|mklx|mkiv|mkvi|mkii|tex|lmt|lua|otf|ttf)' \
        -printf '%f\n' | \
        sort | uniq | \
        tr '\n' '|' | head --bytes=-1 \
    ))\$" | \
    grep -oP '^[\w_-]+' | \
    sort | uniq | \
    sed 's/^/hard /' \
    >> "$staging/context.ctan/context/DEPENDS.txt"

# Next, we'll add the flattened tex/ tree.
mkdir -p "$staging/context.ctan/context/tex/mkiv/"
find "$staging/context.tds/tex/" \
    "$staging/context-nonfree.tds/tex/" \
    "$staging/context-legacy.tds/tex/" \
    "$staging/mptopdf.tds/tex/" \
    -type f \( -path '*/mkiv/*' -o -name 'luatex-*' \) -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/context/tex/mkiv/"

mkdir -p "$staging/context.ctan/context/tex/mkxl/"
find "$staging/context.tds/tex/" \
    "$staging/context-nonfree.tds/tex/" \
    "$staging/context-legacy.tds/tex/" \
    "$staging/mptopdf.tds/tex/" \
    -type f -path '*/mkxl/*' -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/context/tex/mkxl/"

mkdir -p "$staging/context.ctan/context/tex/mkii/"
find "$staging/context.tds/tex/" \
    "$staging/context-nonfree.tds/tex/" \
    "$staging/context-legacy.tds/tex/" \
    "$staging/mptopdf.tds/tex/" \
    -type f -path '*/mkii/*' -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/context/tex/mkii/"

mkdir -p "$staging/context.ctan/context/tex/misc/"
find "$staging/context.tds/tex/" \
    "$staging/context-nonfree.tds/tex/" \
    "$staging/context-legacy.tds/tex/" \
    "$staging/mptopdf.tds/tex/" \
    \( -not -path '*/mkiv/*' \) \
    -a \( -not -path '*/mkxl/*' \) \
    -a \( -not -path '*/mkii/*' \)  \
    -a \( -not -name 'luatex-*' \)  \
    -type f  -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/context/tex/misc/"

# And the flattened doc/ tree.
mkdir -p "$staging/context.ctan/context/doc/"
find "$staging/context.tds/doc/" \
    "$staging/context-nonfree.tds/doc/" \
    "$staging/context-legacy.tds/doc/" \
    \( -iname '*.pdf' -o -iname '*.html' -o -iname '*.txt' -o -iname '*.md' \) \
    -type f  -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/context/doc/"

# And the flattened scripts/ tree.
mkdir -p "$staging/context.ctan/context/scripts/"
find "$staging/context.tds/scripts/" \
    "$staging/context-legacy.tds/scripts/" \
    "$staging/mptopdf.tds/tex/" \
    -type f -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/context/scripts/"

cp "$staging/context.tds/web2c/texmfcnf.lua" \
    "$staging/context.ctan/context/scripts/"

# And the flattened fonts/ tree.
mkdir -p "$staging/context.ctan/context/fonts/"
find "$staging/context.tds/fonts/" \
    "$staging/context-nonfree.tds/fonts/" \
    "$staging/context-legacy.tds/fonts/" \
    -type f -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/context/fonts/"

# And the flattened metapost/ tree.
mkdir -p "$staging/context.ctan/context/metapost/"
find "$staging/context.tds/metapost/" \
    "$staging/context-legacy.tds/metapost/" \
    -type f -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/context/metapost/"

# And the flattened LuaMetaTeX source.
mkdir -p "$staging/context.ctan/context/source/"
find "$staging/luametatex.src/" \
    -type f \( -iname '*.c' -o -iname '*.h' \) -print0 | \
    xargs -0 cp --backup=numbered \
    --target-directory="$staging/context.ctan/context/source/"

# And the binaries.
mkdir -p "$staging/context.ctan/context/bin/"
for tl_platform in "${context_platforms[@]}"; do
    # Trailing asterisk to get the ".exe" for Windows.
    cp -a "$staging/context.bin/$tl_platform/luametatex"* \
        "$staging/context.ctan/context/bin/luametatex-$tl_platform"
done

# Add some documentation for the binaries.
cp -a "$packaging/README-BINARIES.md" \
    "$staging/context.ctan/context/bin/README.md"

# Ok, now let's fix the Markdown links in the CTAN files.
sed -i '/BEGIN github/,/END github/d; /LINKS ctan/d' \
    "$staging/context.ctan/context/archives/INSTALLING.md" \
    "$staging/context.ctan/context/bin/README.md" \
    "$staging/context.ctan/context/doc/README-NONFREE.md" \
    "$staging/context.ctan/context/doc/README-PACKAGING.md" \
    "$staging/context.ctan/context/README.md"

# We needed the "--backup=numbered" flag to avoid the "cp: will not overwrite
# just-created" error, so now we'll remove all of the numbered backup files.
find "$staging/context.ctan/" -type f -name '*.~*~' -delete

# Finally, we can zip up the CTAN archive.
cd "$staging/context.ctan/"
zip --quiet --no-dir-entries --strip-extra --symlinks --recurse-paths \
    "$output/context.ctan.zip" ./*
cd "$root/"

# Make the CTAN zip file deterministic as well.
add-determinism "$output/context.ctan.zip"

# Clean up by removing the staging folder.
cp "$staging/context.ctan/context/VERSION" "$output/version.txt"
rm -rf "${staging:?}/"

# Remove the extra line breaks from the GitHub release notes.
sed -Ezi 's/\n  ([^ ])/ \1/g' "$root/files/release-notes.md"


###############
### Testing ###
###############

# Now, let's validate that we generated a functioning ConTeXt package.

# First, we'll unzip the binaries.
mkdir -p "$testing/bin/"
cd "$testing/bin/"

cp -a "$output/context.bin.zip" ./
unzip -q context.bin.zip

rm -f context.bin.zip
cd "$root/"

# Now, we'll unzip the TEXMF tree.
mkdir -p "$testing/texmf-dist/"
cd "$testing/texmf-dist/"

cp -a "$output/context.tds.zip" ./
unzip -q context.tds.zip

rm -f context.tds.zip
cd "$root/"

# And copy over some fonts for testing.
mkdir -p "$testing/texmf-dist/fonts/opentype/public/"
cp -a "$texlive/texmf-dist/fonts/opentype/public/"{lm,lm-math,tex-gyre,tex-gyre-math,libertinus-fonts,stix2-otf}/ \
    "$testing/texmf-dist/fonts/opentype/public/"

mkdir -p "$testing/texmf-dist/fonts/opentype/ibm/"
cp -a "$texlive/texmf-dist/fonts/opentype/ibm/plex/" \
    "$testing/texmf-dist/fonts/opentype/ibm/"

mkdir -p "$testing/texmf-dist/fonts/truetype/public/"
cp -a "$texlive/texmf-dist/fonts/truetype/public/dejavu/" \
    "$testing/texmf-dist/fonts/truetype/public/"

# Next, we'll build the formats.
mkdir -p "$testing/tests/"
cd "$testing/tests/"

export PATH="$testing/bin/x86_64-linux/:/usr/bin/"
mtxrun --generate > /dev/null
context --make > /dev/null

# Finally, we'll run ConTeXt on a test file.
cp -a "/root/make-font-cache/context-cache.tex" \
    "$testing/tests/context-cache.tex"

context context-cache.tex > /dev/null || \
    (cat context-cache.log && exit 1)

# And compare the output to the expected output.
pdftotext -layout -enc UTF-8 context-cache.pdf - \
    | sed -zE 's/([[:space:]]){2,}/\1/g' | tr '\f' '\n' \
    > "$testing/tests/context-cache.txt"

git diff --no-index --ignore-all-space --exit-code \
    "$packaging/context-cache.txt" \
    "$testing/tests/context-cache.txt" \
    || (echo "The test failed!" && exit 1)

# We're done, so let's clean up.
cd "$root/"
rm -rf "${testing:?}/"


#################
### Uploading ###
#################

# Only upload if we're running inside of Max's Woodpecker (since otherwise this
# is probably just Max testing things, or maybe someone is testing this from a
# fork).
if test "$CI_REPO_URL" != "https://github.com/gucci-on-fleek/context-packaging"; then
    echo "Skipping CTAN upload."
    exit 0
fi

# Woodpecker will handle uploading the files to GitHub, but we need to manually
# upload the files to CTAN here.
curl --no-progress-meter --fail --verbose \
    --config "$scripts/ctan-upload.ini" || \
    (echo "CTAN upload failed: $?" && exit 1)
