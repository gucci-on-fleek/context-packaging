-- ConTeXt Packaging Scripts
-- https://github.com/gucci-on-fleek/context-packaging
-- SPDX-License-Identifier: CC0-1.0+
-- SPDX-FileCopyrightText: 2026 Max Chernoff
if not modules then modules = { } end modules ["mtx-use-tlmgr"] = {
    version   = 1.0,
    comment   = "companion to mtxrun.lua",
    author    = "Max Chernoff",
    copyright = "2026 Max Chernoff",
    license   = "CC0-1.0+"
}

local helpinfo = [[
<?xml version="1.0"?>
<application>
 <metadata>
  <entry name="name">mtx-use-tlmgr</entry>
  <entry name="detail">TeX Live wrapper script for disabled commands</entry>
  <entry name="version">1.0</entry>
 </metadata>
</application>
]]

local original_script = (environment.ownscript or "mtx-use-tlmgr.lua"):match("mtx%-(.*)%.lua")

local application = logs.application {
    name     = "mtx-use-tlmgr",
    banner   = ("The ``%s'' script is disabled in TeX Live; please use ``tlmgr'' instead."):format(original_script),
    helpinfo = helpinfo,
}
application.moreinfo = nil

application.help()
os.exit(2)
