<!-- ConTeXt Packaging Scripts
     https://github.com/gucci-on-fleek/context-packaging
     SPDX-License-Identifier: CC0-1.0+
     SPDX-FileCopyrightText: 2025 Max Chernoff -->

Installing ConTeXt from the files on CTAN
=========================================

ConTeXt is a fairly complex package to install—if at all possible,
please use `tlmgr` (TeX Live) or `mpm` (MikTeX), since manually
unpacking and installing the files is error-prone and complicated. But
if you insist on installing manually, read on.


Binaries
--------

Unlike other TeX formats, each ConTeXt release depends on an exact
version of its engine, LuaMetaTeX. Because of this, upgrading LuaMetaTeX
or ConTeXt independently of each other is likely to lead to a
non-functional installation.

The archive `context.bin.zip` contains the binaries necessary to run
ConTeXt. To use this, unpack it, and then copy the subfolder appropriate
to your platform into your `$PATH`. Please ensure that the targets of
the symbolic links `context.lua` and `mtxrun.lua` exist—they should both
point to scripts inside `$TEXMFDIST/scripts/context/lua/`. These scripts
themselves are contained in the `context.tds.zip` archive, as discussed
below.

The archive `luametatex.src.zip` contains the source code and build
scripts corresponding to the packaged binaries, so if `context.bin.zip`
does not contain binaries appropriate for your system's platform, you
may compile them yourself. Please see the [ConTeXt Wiki page “Building
LuaMetaTeX for
TeX Live”](https://wiki.contextgarden.net/Building_LuaMetaTeX_for_TeX_Live)
for more information.


Runtime Files
-------------

The archive `context.tds.zip` (or just `context.zip` on CTAN) contains
the complete TEXMF tree for ConTeXt. To use this, simply unpack it into
your preexisting `$TEXMFDIST` tree.

The archive `context-nonfree.tds.zip` (or just `context-nonfree.zip` on
CTAN) contains optional ConTeXt files that may be redistributed
free-of-charge, but do not [qualify as free (libre) software as per the
TeX Live guidelines](https://tug.org/texlive/pkgcontrib.html). Once
again, to use this, simply unpack it into your preexisting `$TEXMFDIST`
tree.

The archive `context-legacy.tds.zip` (or just `context-legacy.zip` on
CTAN) contains the complete TEXMF tree for the now-obsolete MkII version
of ConTeXt. This version of ConTeXt requires the pdfTeX engine to
function; you'll need to install that on your own. As before, simply
unpack it into your preexisting `$TEXMFDIST` tree to use this


Dependencies
------------

ConTeXt has very few dependencies; please refer to
[`DEPENDS.txt`](DEPENDS.txt) for a full discussion.
