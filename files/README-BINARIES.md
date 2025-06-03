<!-- ConTeXt Packaging Scripts
     https://github.com/gucci-on-fleek/context-packaging
     SPDX-License-Identifier: CC0-1.0+
     SPDX-FileCopyrightText: 2025 Max Chernoff -->

ConTeXt Binaries on CTAN
========================

Successfully installing these binaries for use with ConTeXt requires
many steps; users are strongly urged to use their TeX distribution's
package manager instead of using these files directly. See
[`INSTALLING.md`][INSTALLING.md] for further discussion.


Binary Structure
----------------

For a working ConTeXt installation, **all** of the following
requirements must be met.

1. The binary appropriate for your platform must be named `luametatex`,
   and must be in your `$PATH`.

2. Files named `context` and `mtxrun` must be present in the same
   directory as the `luametatex` binary discussed above. These files may
   be either symbolic links pointing to `luametatex` (recommended), or
   bitwise-identical copies.

3. Files named `context.lua` and `mtxrun.lua` must be present in the
   same directory as the `context` and `mtxrun` binaries. These files
   may be either symbolic links pointing to the correct scripts located
   in `$TEXMFDIST/scripts/context/lua/` (recommended), or may be
   bitwise-identical copies of these files.

Step 3 is the most important step, and cannot be circumvented—there is
no way to run ConTeXt without the (non-executable) scripts being present
directly beside the corresponding binaries.


<!-- BEGIN github -->
   [INSTALLING.md]: INSTALLING.md
<!-- END github -->

<!-- LINKS ctan
   [INSTALLING.md]: ../archives/INSTALLING.md
     LINKS ctan -->
