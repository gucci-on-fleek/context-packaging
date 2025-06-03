<!-- ConTeXt Packaging Scripts
     https://github.com/gucci-on-fleek/context-packaging
     SPDX-License-Identifier: CC0-1.0+
     SPDX-FileCopyrightText: 2025 Max Chernoff -->

ConTeXt Packaging Scripts
=========================

This repository hosts the scripts used to package the contents of the
[ConTeXt Standalone
Distribution](https://wiki.contextgarden.net/Introduction/Installation)
into [TeX Live](https://tug.org/texlive/pkgcontrib.html) and
[CTAN](https://www.ctan.org/pkg/context).

Note that this project only packages the newer MkIV (LuaTeX) and MkXL
(LuaMetaTeX) formats; the legacy MkII (pdfTeX and XeTeX) formats are
packaged by the TeX Live maintainers directly.


Architecture
------------

1. [Every
   day](https://github.com/gucci-on-fleek/maxchernoff.ca/blob/master/tex/.config/systemd/user/update-texlive.timer),
   my server [updates its standalone ConTeXt
   installation](https://github.com/gucci-on-fleek/maxchernoff.ca/blob/master/usrlocal/bin/update-context.sh).

2. Afterwards, [the `daily-check` workflow in this
   repository][daily-check.yaml] runs. [It extracts the
   version number of the current ConTeXt installation, and then attempts
   to make a corresponding Git tag.][daily-check.sh] If it fails
   (because the tag already exists), it gracefully exits; if it
   succeeds, it [pushes the tag to this
   repository](https://github.com/gucci-on-fleek/context-packaging/tags).

3. Whenever a tag is pushed, [the `make-release` workflow in this
   repository][make-release.yaml] runs. [It reorganizes and
   zips the contents of the ConTeXt standalone distribution into the
   format expected by TeX Live.][make-release.sh] Afterwards,
   [it uploads the `.zip` files into a new GitHub
   release](https://github.com/gucci-on-fleek/context-packaging/releases).

4. Whenever a new release is created, GitHub emails me. Then, I will
   manually [download the `.zip` files from the
   release](https://github.com/gucci-on-fleek/context-packaging/releases/latest)
   and [upload them to CTAN](https://www.ctan.org/upload).

Note that steps 2 and 3 (where all the important stuff happens) are
executed on [Woodpecker CI, so the full build logs are publicly
available](https://woodpecker.maxchernoff.ca/repos/4).


Files
-----

A few TeX Live-specific files for ConTeXt are contained in the
[`files/`][files] directory. Check the comments in each file for more
details.


Support and Contributing
------------------------

If you have a problem with ConTeXt itself, it is best to report it to
the official
[`ntg-context@ntg.nl`](https://mailman.ntg.nl/archives/list/ntg-context@ntg.nl/latest)
mailing list.

If you notice that ConTeXt is mispackaged in TeX Live, then please [open
a new issue on
GitHub](https://github.com/gucci-on-fleek/context-packaging/issues/new),
email the public
[`ntg-context@ntg.nl`](https://mailman.ntg.nl/archives/list/ntg-context@ntg.nl/latest)
or [`tex-live@tug.org`](https://tug.org/mailman/listinfo/tex-live)
mailing lists, or email me privately at `tex@maxchernoff.ca`. [Pull
requests](https://github.com/gucci-on-fleek/context-packaging/compare)
are also gladly accepted.


Installing
----------

ConTeXt is a fairly complex package to install—if at all possible,
please use `tlmgr` (TeX Live) or `mpm` (MikTeX), since manually
unpacking and installing the files is error-prone and complicated. But
if you insist on installing manually, please refer to
[`INSTALLING.md`][INSTALLING.md].


Licence
-------

The vast majority of files in the zip files originate from ConTeXt
itself; please see
[`doc/context/documents/general/manuals/mreadme.pdf`][mreadme.pdf]
for details on their licensing. The files directly contained in this
repository are placed in the public domain.


<!-- BEGIN github -->
   [daily-check.yaml]:  .woodpecker/daily-check.yaml
   [daily-check.sh]:    scripts/daily-check.sh
   [make-release.yaml]: .woodpecker/make-release.yaml
   [make-release.sh]:   scripts/make-release.sh
   [files]:             files/
   [INSTALLING.md]:     files/INSTALLING.md
   [mreadme.pdf]:       https://texdoc.org/serve/mreadme/0
<!-- END github -->

<!-- LINKS ctan
   [daily-check.yaml]:  https://github.com/gucci-on-fleek/context-packaging/tree/master/.woodpecker/daily-check.yaml
   [daily-check.sh]:    https://github.com/gucci-on-fleek/context-packaging/tree/master/scripts/daily-check.sh
   [make-release.yaml]: https://github.com/gucci-on-fleek/context-packaging/tree/master/.woodpecker/make-release.yaml
   [make-release.sh]:   https://github.com/gucci-on-fleek/context-packaging/tree/master/scripts/make-release.sh
   [files]:             https://github.com/gucci-on-fleek/context-packaging/tree/master/files/
   [INSTALLING.md]:     https://github.com/gucci-on-fleek/context-packaging/tree/master/files/INSTALLING.md
   [mreadme.pdf]:       doc/mreadme.pdf
     LINKS ctan -->


