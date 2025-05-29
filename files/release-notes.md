<!-- ConTeXt Packaging Scripts
     https://github.com/gucci-on-fleek/context-packaging
     SPDX-License-Identifier: CC0-1.0+
     SPDX-FileCopyrightText: 2025 Max Chernoff -->

- `context.ctan.zip` is the archive that will be uploaded to CTAN. It
  contains all the other zip files, as well as all the files in a
  “flattened” format that is easier to browse on CTAN.

- `context.tds.zip` is the TDS-compliant archive that contains all the
  runtime files used by ConTeXt. You can install this by simply
  unpacking it into a TEXMF tree, although it is better to use your TeX
  distribution's package manager.

- `context.bin.zip` contains the binaries necessary to run ConTeXt. To
  use this, unpack it, and then copy the subfolder appropriate to your
  platform into your `$PATH`.

- `context-nonfree.tds.zip` contains the non-free files that can
  optionally be used with ConTeXt. This is not included in the standard
  TeX Live distribution, but can be installed by unpacking it into a
  TEXMF tree.

- `context-legacy.tds.zip` is the TDS-compliant archive that contains
  all the runtime files used by the now-obsolete MkII version of
  ConTeXt.
