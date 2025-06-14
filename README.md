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
[CTAN](https://www.ctan.org/).

Specifically, this is the source of the [CTAN package
`context`](https://www.ctan.org/pkg/context), which contains the [TeX
Live](https://tug.org/texlive/) packages `context` (ConTeXt MkXL/LMTX
runtime TeX files), `context.ARCH` (LuaMetaTeX binaries),
`context-legacy` (ConTeXt MkII runtime TeX files), and `mptopdf`
(`mptopdf` command-line script), and the
[TLContrib](https://contrib.texlive.info/) package `context-nonfree`
(ConTeXt runtime files that are not free software).


Goals
-----

The primary goal of this project is to make an installation of TeX Live
with `scheme-context` (plus `context-nonfree` from
[TLContrib](https://contrib.texlive.info/)) behave identically to the
[ConTeXt Standalone Distribution](https://www.pragma-ade.nl/install.htm)
with [all modules
installed](https://wiki.contextgarden.net/Input_and_compilation/Modules#Installation_by_script_.28LMTX.29).
Note that `scheme-full` (<abbr>AKA</abbr> the default “Full” TeX Live
installation) is a superset of `scheme-context`, which means that most
users will have a complete ConTeXt installation by default.

### Known Deviations

1. The ConTeXt Standalone Distribution always sets the default paper
   size to [A4](https://en.wikipedia.org/wiki/A4_paper); TeX Live allows
   users to configure this to either A4 or
   [Letter](https://en.wikipedia.org/wiki/Letter_(paper_size)).
   Regardless, users may (and should) configure this for each individual
   document with
   [`\setuppapersize`](https://wiki.contextgarden.net/Command/setuppapersize).

2. The ConTeXt Standalone Distribution frequently updates its LuaTeX
   binaries to the latest release; TeX Live only updates its LuaTeX
   binaries once per year. LuaTeX is
   [mostly](https://tug.org/TUGboat/tb41-3/tb129scarso-luatex.pdf)
   [frozen](https://www.luatex.org/roadmap.html#:~:text=In%202023,not%20be%20extended%2E),
   so this should generally make no difference. Regardless, the distinct
   LuaMetaTeX engine will be updated multiple times per year in
   TeX Live, just like the ConTeXt Standalone Distribution.

3. The ConTeXt Standalone Distribution permits documents to run
   arbitrary executables while compiling; TeX Live attempts to restrict
   this to a handful of known-safe programs. Note that this is provided
   as a convenience feature only, and is **NOT** a security feature.
   Users must not compile untrusted ConTeXt documents without using
   external sandboxing mechanisms (Docker, Bubblewrap, systemd-run,
   etc.).

4. The ConTeXt Standalone Distribution distributes lexers/themes/plugins
   for various editors; TeX Live omits these files since editor support
   is outside its purview.

Any other differences from the ConTeXt Standalone Distribution are
considered bugs, so if you find any deviations in this package, please
let me know, and I will fix it for the next release.


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

The vast majority of files in the zip archives originate from ConTeXt
itself; please see
[`doc/context/documents/general/manuals/mreadme.pdf`][mreadme.pdf] for
details on their licensing. The files directly contained in this
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


