-- ConTeXt Packaging Scripts
-- https://github.com/gucci-on-fleek/context-packaging
-- SPDX-License-Identifier: GPL-2.0-or-later
-- SPDX-FileCopyrightText: 2024 Hans Hagen
-- SPDX-FileCopyrightText: 2026 Max Chernoff

-- Note that this file will be overwritten on upgrades, so users should place
-- any modifications in another location!

-- It is recommended that downstream distributors only modify the variables in
-- the following section (although you can modify any other section if you know
-- what you are doing).

--- BEGIN RECOMMENDED MODIFICATIONS SECTION ---

-- Information about who provided this installation of ConTeXt. If you modify
-- this file (or any of the other ConTeXt files) and redistribute these changes,
-- you should also change this value to something appropriate for your
-- distribution.
local distribution_name = "TeX Live"

-- A URL where users can find more information about this distribution of
-- ConTeXt, and especially where they can report bugs. Again, if you modify this
-- file, you should also modify this field.
local distribution_url = "https://github.com/gucci-on-fleek/context-packaging"

-- The version of the distribution itself; unrelated to the version of ConTeXt.
local distribution_version = "2026"

-- Sometimes TeX Live needs to release more than one update for a single
-- upstream ConTeXt release, so TeX Live adds a single uppercase letter suffix
-- to the version number for each update. A suffix of "A" indicates the first
-- release (this is the most common case), "B" indicates the second release, and
-- so on. If you are a downstream distributor, you can use this field for your
-- own purposes; any string is valid, but it should be unique for each release
-- for any given upstream version of ConTeXt. This is just the suffix though, so
-- the full version number looks something like "1950.02.10 15:41 A", where
-- "1950.02.10 15:41" is the upstream version provided by ConTeXt itself and "A"
-- is the suffix added by TeX Live.
local package_revision = "@@package_revision@@"

-- The location of the distribution's TEXMF tree. The contents stored in this
-- path should not be modified by users, and are solely managed by the
-- distribution itself.
local distribution_path = "selfautoparent:texmf-dist"

-- Where ConTeXt should store any caches. There is a single "system" folder for
-- the entire computer, and this folder is typically only writable by
-- root/administrators. There is a separate "user" folder for each user, and
-- users can freely modify these files. Note that at least one of these folders
-- must be writable by ConTeXt at runtime, or else ConTeXt will refuse to run.
-- These folders should be persistent (so not in a temporary directory);
-- however, it is generally safe to delete them at any time.
local system_cache = "selfautoparent:"
local user_cache   = "home:.texlive2026"

-- Where ConTeXt should search for custom files. "system" and "user" have the
-- same meaning as above. ConTeXt will never write to or otherwise modify these
-- files itself.
local system_data = "selfautoparent:../texmf-local"
local user_data   = "home:texmf"

-- The location of non-TeX files optionally used by ConTeXt. Different paths are
-- separated by semicolons (";"), and a trailing double slash ("//") indicates
-- that the directory should be searched recursively.
local nontex_fonts, nontex_colors
if os.type == "windows" then
    nontex_fonts = "\z
        home:AppData/Local/Microsoft/Windows/Fonts;\z
        C:/Windows/Fonts;\z
    "
    nontex_colors = "" -- No idea where this is on Windows; patches welcome
elseif os.name == "macosx" then
    nontex_fonts = "\z
        home:Library/Fonts;\z
        /Library/Fonts;\z
        /System/Library/Fonts;\z
    "
    nontex_colors = "" -- No idea where this is on macOS; patches welcome
else -- Linux, BSD, etc.
    nontex_fonts = "\z
        home:.local/share/fonts;\z
        /usr/local/share/fonts//;\z
        /usr/share/fonts//;\z
    "
    nontex_colors = "\z
        home:.local/share/icc//;\z
        /usr/local/share/color/icc//;\z
        /usr/share/color/icc//;\z
    "
end

-- Programs that should be allowed to run in restricted mode. Note that this is
-- provided as a convenience feature only, and is **NOT** a security feature.
-- Users must not compile untrusted ConTeXt documents without using external
-- sandboxing mechanisms (Docker, Bubblewrap, systemd-run, etc.). ConTeXt runs
-- in unrestricted mode by default, meaning that this list is ignored entirely
-- and documents can freely execute arbitrary programs.
local allowed_programs = table.concat({
    "bibtex",
    "bibtex8",
    "extractbb",
    "gregorio",
    "kpsewhich",
    "l3sys-query",
    "latexminted",
    "makeindex",
    "memoize-extract.pl",
    "memoize-extract.py",
    "r-mpost",
    "repstopdf",
    "texosquery-jre8",
}, ",")
--- END RECOMMENDED MODIFICATIONS SECTION ---

return {
    -- Metadata about this configuration file. (Copied from the original
    -- "texlivecnf.lua" file in the upstream ConTeXt Standalone Distribution.)
    type    = "configuration",
    version = "1.1.3",
    date    = "2024-02-10",
    time    = "14:59:00",
    comment = "ConTeXt MkIV and LMTX configuration file",
    author  = "Hans Hagen & Max Chernoff",
    target  = "texlive",

    -- Metadata used to identify this distribution of ConTeXt.
    details = {
        name = distribution_name .. distribution_version,
        url = distribution_url,
        version = package_revision,
        comment = "Based off of TeX Live (@@full_version@@)",

        -- Extra non-standard information
        private = {
            distribution_name = distribution_name,
            distribution_version = distribution_version,
            package_revision = package_revision,

            -- In case distributors have modified the above three variables,
            -- we'll add a static variable here so that it's clear whether this
            -- file was based directly off of the original "texmfcnf.lua" file
            -- from the upstream ConTeXt Standalone Distribution, or from the
            -- TeX Live distribution's modified version. (It usually makes the
            -- most sense to rely on the distributor-provided variables, so most
            -- users should prefer inspecting the variables above instead of
            -- this one.)
            derived_from = "TeX Live (@@full_version@@)",
        }
    },

    -- Here are the "real" variables that affect ConTeXt's runtime behaviour.
    content = {
        -- File/directory locations
        variables = {
            -- System trees
            TEXMFDIST      = distribution_path,
            TEXMFLOCAL     = system_data,
            TEXMFSYSCONFIG = system_cache .. "/texmf-config",
            TEXMFSYSVAR    = system_cache .. "/texmf-var",

            -- User trees
            TEXMFCONFIG = user_cache .. "/texmf-config",
            TEXMFVAR    = user_cache .. "/texmf-var",
            TEXMFHOME   = user_data,

            -- Search paths
            TEXMFCACHE = "$TEXMFSYSVAR;$TEXMFVAR",
            TEXMF      = "{\z
                              $TEXMFCONFIG,\z
                              $TEXMFHOME,\z
                              !!$TEXMFSYSCONFIG,\z
                              !!$TEXMFSYSVAR,\z
                              !!$TEXMFLOCAL,\z
                              !!$TEXMFDIST\z
                          }",

            -- Input locations: TeX
            TEXINPUTS = ".;$TEXMF/tex/{context,generic,luatex}//",

            -- Input locations: Fonts
            TTFONTS         = ".;" .. nontex_fonts ..
                              "$TEXMF/fonts/truetype//;$OSFONTDIR",
            OPENTYPEFONTS   = ".;" .. nontex_fonts ..
                              "$TEXMF/fonts/opentype//;$OSFONTDIR",
            FONTCONFIG_PATH = "$TEXMFSYSVAR/fonts/conf",
            OSFONTDIR       = nontex_fonts,

            -- Input locations: Lua
            TEXMFSCRIPTS = ".;$TEXMF/scripts/context//;$TEXINPUTS",
            LUAINPUTS    = ".;$TEXINPUTS;$TEXMF/scripts/context/lua//",
            CLUAINPUTS   = "$SELFAUTOLOC/lib/$engine//", -- No "."; insecure

            -- Input locations: Other
            MPINPUTS    = ".;$TEXMF/metapost//",
            BIBINPUTS   = ".;$TEXMF/bibtex/bib//;$TEXMF/tex/context/bib//",
            ICCPROFILES = ".;" .. nontex_colors ..
                          "$TEXMF/tex/context/colors//;$OSCOLORDIR",
        },

        -- Engine parameters. These were copied from the original ConTeXt file;
        -- don't change these unless you know what you are doing!
        directives = {
            -- LuaMetaTeX engine parameters
            ["luametatex.errorlinesize"]     = { size =      250                 }, -- max =       255
            ["luametatex.halferrorlinesize"] = { size =      250                 }, -- max =       255
            ["luametatex.expandsize"]        = { size =    10000                 }, -- max =   1000000
            ["luametatex.stringsize"]        = { size =   500000, step =  100000 }, -- max =   2097151 -- number of strings
            ["luametatex.poolsize"]          = { size = 10000000, step = 1000000 }, -- max = 100000000 -- chars in string
            ["luametatex.hashsize"]          = { size =   250000, step =  100000 }, -- max =   2097151
            ["luametatex.nodesize"]          = { size = 50000000, step =  500000 }, -- max =  50000000
            ["luametatex.tokensize"]         = { size = 10000000, step =  250000 }, -- max =  10000000
            ["luametatex.buffersize"]        = { size = 10000000, step = 1000000 }, -- max = 100000000
            ["luametatex.inputsize"]         = { size =   100000, step =   10000 }, -- max =    100000 -- aka stack
            ["luametatex.filesize"]          = { size =     2000, step =     200 }, -- max =      2000
            ["luametatex.nestsize"]          = { size =    10000, step =    1000 }, -- max =     10000
            ["luametatex.parametersize"]     = { size =   100000, step =   10000 }, -- max =    100000
            ["luametatex.savesize"]          = { size =   500000, step =   10000 }, -- max =    500000
            ["luametatex.fontsize"]          = { size =   100000, step =     250 }, -- max =    100000
            ["luametatex.languagesize"]      = { size =      250, step =     250 }, -- max =     10000
            ["luametatex.marksize"]          = { size =      250, step =      50 }, -- max =     10000
            ["luametatex.insertsize"]        = { size =      250, step =      25 }, -- max =       250

            -- LuaTeX engine parameters
            ["luatex.errorline"]     =    250,
            ["luatex.halferrorline"] =    125,
            ["luatex.expanddepth"]   =  10000,
            ["luatex.hashextra"]     = 100000,
            ["luatex.nestsize"]      =   1000,
            ["luatex.maxinopen"]     =    500,
            ["luatex.maxprintline"]  =  10000,
            ["luatex.maxstrings"]    = 500000,
            ["luatex.paramsize"]     =  25000,
            ["luatex.savesize"]      = 100000,
            ["luatex.stacksize"]     = 100000,

            -- mtxrun parameters
            ["system.errorcontext"]    = "10",
            ["system.compile.cleanup"] = "no",  -- remove tma files
            ["system.compile.strip"]   = "yes", -- strip tmc files

            -- I/O restrictions
            ["system.outputmode"] = "restricted",
            ["system.inputmode"]  = "any",

            -- Execution restrictions
            ["system.commandmode"]   = "list", -- none | list | all
            ["system.executionmode"] = "list", -- none | list | all
            ["system.commandlist"]   = allowed_programs,
            ["system.executionlist"] = allowed_programs,
            ["system.librarymode"]   = "none", -- none | list | all

            -- Metapost
            ["mplib.texerrors"] = "yes",
        },
    },

}
