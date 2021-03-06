------------------------
-- @module vex
-- Verbal Expressions for Lua (vex) Documentation
-- ==============================================
-- vex is a Verbal Expressions module for Lua that utilizes the [rex](http://math2.org/luasearch/rex.html) module to supply developers with an easy to use implementation of Regular Expressions.
-- Following the [implementation guidelines](https://github.com/VerbalExpressions/implementation/wiki/List-of-methods-to-implement),
-- vex allows the chaining of vex objects for both simplicity and readability.
--
-- To use vex, just require it in your project and use it like so
-- @usage
--   local vex = require("vex")
--   local testURL = "https://www.google.com"
--   local tester = vex():startOfLine():find("http"):maybe("s"):find("://"):maybe("www."):anythingBut(" "):endOfLine()
--   local match = tester:match(testURL)
--   print(match) -- Prints the test URL

local rex = require("rex_pcre")

local vex = {}
local meta =     {
                    ["__index"]        =    vex,
                    ["__metatable"]    =    true,
                    ["__concat"]       =    function(p, a)
                                            local v = {}
                                                v.pattern_compiled = p:pattern() .. a:pattern()

                                                v.oneline = p.oneline or a.oneline
                                                v.findone = p.findone or a.findone
                                                v.caseless = p.caseless or a.caseless
                                                v.capturelevel = p.capturelevel + a.capturelevel
                                                v.grouplevel = p.grouplevel + a.grouplevel

                                                setmetatable(v, meta)
                                                return v
                                            end,
                    ["__tostring"]    =     function(self)
                                                return self:pattern()
                                            end
                }

setmetatable(vex,    {
                            ["__call"]  =   function() return vex.new() end
                        })

local function escape_regex(input)
    return input:gsub("[%[%]%\\%^%$%.%|%?%*%+%-%(%)]", "\\%1")
end

------------------------
-- Creates and returns a new Verbal Expressions object.
--
-- Note: You can also create a new Verbal Expressions object by calling the vex table directly.
-- @usage
--  v = vex.new()
--  v = vex() -- Same as vex.new()
-- @static
function vex.new()
    local v = {}
    v.pattern_buffer = nil
    v.pattern_compiled = ""

    -- Flags
    v.oneline = false
    v.findone = false
    v.caseless = false
    v.capturelevel = 0
    v.grouplevel = 0

    setmetatable(v, meta)
    return v
end

function vex:pattern()
    if self.pattern_buffer then
        self.pattern_compiled = self.pattern_compiled .. table.concat(self.pattern_buffer)
        self.pattern_buffer = nil
    end
    return self.pattern_compiled
end

function vex:append_pattern(pattern)
    assert(type(pattern) == "string", "append_pattern: argument #1 expected string")
    self.pattern_buffer = self.pattern_buffer or {}
    table.insert(self.pattern_buffer, pattern)
    return self
end

function vex:set_pattern(pattern)
    assert(type(pattern) == "string", "set_pattern: argument #1 expected string")
    self.pattern_buffer = nil
    self.pattern_compiled = pattern
    return self
end

------------------------
-- Concatenates vex objects, combining their expressions and flags.
--
-- Concatenated vex objects take the highest value when it comes to flags. That is to say, if a flag is set in one of the operands,
-- it will be set in the resulting vex object.
-- @function vex.__concat
-- @tparam table p A vex object
-- @tparam table a A vex object
-- @usage
--   local p = vex():beginCapture():find("http"):maybe("s"):endCapture():then("://")
--   local s = vex():beginCapture():word():endCapture():then(".")
--   local t = vex():beginCapture():word():endCapture():anything()
--   local tester = p .. s .. s .. t
--   local url = "https://www.google.com/"
--   print(tester:match(url)) -- Prints "https    www    google    com"

--- Anchors.
-- Anchors attach an expression to the beginning or end of a line of text.
-- @section anchors

------------------------
-- Specify that the expression should match at the start of a line of text.
function vex:startofline()
    if self:pattern():sub(1, 1) ~= "^" then
        self:set_pattern("^" .. self:pattern())
    end

    return self
end

------------------------
-- Specify that the expression should match at the end of a line of text.
function vex:endofline()
    if self:pattern():sub(-1, -1) ~= "$" then
        self:append_pattern("$")
    end

    return self
end

--- Character Matchers.
-- Character matchers are used to match against certain kinds of text after the previous matcher or group.
-- If the character matcher matcher(v) existed, its usage could be described with
-- @usage v = vex():matcher("text")
-- @section matchers

------------------------
-- Find the specified text after the last matcher.
-- @tparam string v The text to match
-- @treturn table The vex object (for chaining)
function vex:find(v)
    return self:append_pattern("(?:" .. escape_regex(tostring(v)) .. ")")
end

------------------------
-- Find the specified text after the last matcher, but don't stop if it's not there.
-- @tparam string v The text to match
-- @treturn table The vex object (for chaining)
function vex:maybe(v)
    return self:append_pattern("(?:" .. escape_regex(tostring(v)) .. ")?")
end

------------------------
-- Find anything.
-- @usage local v = vex():anything() -- Matches against anything (including nothing).
-- @treturn table The vex object (for chaining)
function vex:anything()
    return self:append_pattern("(?:.*)")
end

------------------------
-- Find anything except for the specified text.
-- @tparam string v The text to not match
-- @treturn table The vex object (for chaining)
function vex:anythingbut(v)
    return self:append_pattern("(?:[^" .. escape_regex(tostring(v)) .. "]*)")
end

------------------------
-- Find at least one thing.
-- @usage local v = vex():something() -- Matches against anything (except nothing).
-- @treturn table The vex object (for chaining)
function vex:something()
    return self:append_pattern("(?:.+)")
end

------------------------
-- Find a line break.
-- @usage local v = vex():linebreak()
-- @treturn table The vex object (for chaining)
function vex:linebreak()
    return self:append_pattern("(?:(?:\n)|(?:\r\n))")
end

------------------------
-- @function vex:br
-- @see vex:linebreak
vex["br"] = vex["linebreak"]


------------------------
-- Find a tab character.
-- @usage local v = vex():tab()
-- @treturn table The vex object (for chaining)
function vex:tab()
    return self:append_pattern("(?:\t)")
end

------------------------
-- Find a word made up of letters.
-- @usage local v = vex():word()
-- @treturn table The vex object (for chaining)
function vex:word()
    return self:append_pattern("(?:\\w+)")
end

------------------------
-- Find any of the specified characters.
-- @tparam string v The characters to match
-- @treturn table The vex object (for chaining)
function vex:anyof(v)
    return self:append_pattern("(?:[" .. escape_regex(tostring(v)) .. "])")
end

------------------------
-- @function vex:any
-- @tparam string v The characters to match
-- @see vex:anyof
vex["any"] = vex["anyof"]

------------------------
-- Find any range of characters.
-- @tparam string ... A set of characters to build a set of ranges.
-- @usage local v = vex():range("0", "9", "A", "F", "a", "f") -- Finds any character ranging from 0 to 9, A to F, or a to f.
-- @treturn table The vex object (for chaining)
function vex:range(...)
    local args = {...}
    local buff = {}
    
    assert(#args % 2 == 0, "Incomplete range (expected an even number of arguments, got " .. #args .. ")")
    for i, v in ipairs(args) do
        assert(type(v) == "string", "bad argument #" .. i .. " to 'range' (string expected, got " .. type(v) .. ")")
        if i % 2 ~= 0 then
            table.insert(buff, escape_regex(v:sub(1, 1)))
        elseif i % 2 == 0 then
            table.insert(buff, "-")
            table.insert(buff, escape_regex(v:sub(1, 1)))
        end
    end

    return self:append_pattern("(?:[" .. table.concat(buff) .. "])")
end

------------------------
-- Match a number of the specified text.
-- @tparam string v The text to match
-- @tparam number n The minimum quantity to match
-- @tparam[opt] number m The maximum quantity to match
-- @treturn table The vex object (for chaining)
function vex:multiple(v, n, m)
    assert(type(n) == "number", "bad argument #1 to 'between' (number expected, got " .. type(n) .. ")")
    assert(type(m) == "number" or m == nil, "bad argument #2 to 'between' (number expected, got " .. type(m) .. ")")
    assert(n > 0, "bad argument #1 to 'between' (minimum amount must be greater than or equal to 0)")
    assert(m > n or m == nil, "bad argument #2 to 'between' (maximum amount must be greater than the minimum amount)")

    self:find(v)

    if m ~= nil then
        return self:between(n, m)
    else
        return self:atleast(n)
    end
end

--- Quantifiers.
-- Quantifiers allow you to specify that the last group or matcher should be repeated or optional.
-- If the quantifier quantifier(n) existed, its usage could be described with
-- @usage v = vex():matcher("text"):quantifier(4)
-- @section quantifiers

------------------------
-- Match an exact number of the last group or matcher.
-- @tparam number n The quantity to match
-- @treturn table The vex object (for chaining)
function vex:exactly(n)
    assert(type(n) == "number", "bad argument #1 to 'exactly' (number expected, got " .. type(n) .. ")")
    assert(n > 0, "bad argument #1 to 'exactly' (amount must be greater than 0)")
    return self:append_pattern("{" .. n .. "}")
end

------------------------
-- Match a number of the last group or matcher between 'n' and 'm' (inclusive).
-- @tparam number n The minimum quantity to match
-- @tparam number m The maximum quantity to match
-- @treturn table The vex object (for chaining)
function vex:between(n, m)
    assert(type(n) == "number", "bad argument #1 to 'between' (number expected, got " .. type(n) .. ")")
    assert(type(m) == "number", "bad argument #2 to 'between' (number expected, got " .. type(m) .. ")")
    assert(n > 0, "bad argument #1 to 'between' (minimum amount must be greater than or equal to 0)")
    assert(m > n, "bad argument #2 to 'between' (maximum amount must be greater than the minimum amount)")
    return self:append_pattern("{" .. n .. "," .. m .. "}")
end

------------------------
-- Match at least a number of the last group or matcher.
-- @tparam number n The quantity to match
-- @treturn table The vex object (for chaining)
function vex:atleast(n)
    assert(type(n) == "number", "bad argument #1 to 'atleast' (number expected, got " .. type(n) .. ")")
    assert(n > 0, "bad argument #1 to 'atleast' (amount must be greater than or equal to 0)")
    return self:append_pattern("{" .. n .. ",}")
end

------------------------
-- Match no more than a number of the last group or matcher.
-- @tparam number n The quantity to match
-- @treturn table The vex object (for chaining)
function vex:nomorethan(n)
    assert(type(n) == "number", "bad argument #1 to 'noMoreThan' (number expected, got " .. type(n) .. ")")
    assert(n > 0, "bad argument #1 to 'noMoreThan' (amount must be greater than or equal to 0)")
    return self:append_pattern("{0," .. n .. "}")
end

--- Groups and Captures.
-- Groups and captures help you group expressions together and grab certain elements to be returned later when a match is made.
-- The difference between groups and captures is that groups are used to group expressions together to be modified by quantifiers or the vex:alternatively function while
-- captures are used to specify that the part of the text that an expression matches should be returned later.
-- @section groups

------------------------
-- Specifies that either the previous matcher or group or the following matcher or group is acceptable.
-- @treturn table The vex object (for chaining)
function vex:alternatively()
    return self:append_pattern("|")
end

------------------------
-- Marks the beginning of a capture.
-- @treturn table The vex object (for chaining)
function vex:begincapture()
    self.capturelevel = self.capturelevel + 1
    return self:append_pattern("(")
end

------------------------
-- Marks the end of a capture.
-- @treturn table The vex object (for chaining)
function vex:endcapture()
    assert(self.capturelevel > 0, "No more open captures")
    self.capturelevel = self.capturelevel - 1
    return self:append_pattern(")")
end

------------------------
-- Marks the beginning of a group.
-- @treturn table The vex object (for chaining)
function vex:begingroup()
    self.grouplevel = self.grouplevel + 1
    return self:append_pattern("(?:")
end

------------------------
-- Marks the end of a group.
-- @treturn table The vex object (for chaining)
function vex:endgroup()
    assert(self.grouplevel > 0, "No more open groups")
    self.grouplevel = self.grouplevel - 1
    return self:append_pattern(")")
end

--- Flags.
-- Flags are used to specify that certain properties should be applied to an expression.
-- @section flags

------------------------
-- Matches the expression against any character case.
-- @treturn table The vex object (for chaining)
function vex:withanycase()
    self.caseless = true
    return self
end

------------------------
-- Forces the expression to stop once it's found a match.
-- @treturn table The vex object (for chaining)
function vex:stopatfirst()
    self.findone = true
    return self
end

------------------------
-- Forces the expression to stop at the end of a line.
-- @treturn table The vex object (for chaining)
function vex:searchoneline()
    self.oneline = true
    return self
end

--- Work Functions.
-- These functions operate on text to resolve the expression that a vex object is carrying.
-- @section workfunctions

------------------------
-- Matches a vex expression against a string.
-- @tparam string s The string to match against
-- @tparam number init The position in the string to begin matching
-- @treturn string The results of the match as multiple strings
-- @see string.match
function vex:match(s, init)
    init = init or 1

    assert(type(s) == "string", "bad argument #1 to 'match' (string expected, got " .. type(s) .. ")")
    assert(type(init) == "number", "bad argument #2 to 'match' (number expected, got " .. type(init) .. ")")

    return rex.match(s, self:pattern(), init, (self.caseless and 1 or 0) + (self.oneline and 2 or 0))
end

------------------------
-- Find the position of the first match in a string.
-- @tparam string s The string to match against
-- @tparam number init The position in the string to begin matching
-- @treturn number The index at which the first match is at
-- @see rex.find
function vex:seek(s, init)
    assert(type(s) == "string", "bad argument #1 to 'seek' (string expected, got " .. type(s) .. ")")
    assert(type(init) == "number", "bad argument #2 to 'seek' (number expected, got " .. type(init) .. ")")

    return rex.find(s, self:pattern(), init, (self.caseless and 1 or 0) + (self.oneline and 2 or 0))
end

------------------------
-- Returns an interator that returns the next match in the string every time it is called.
-- @tparam string s The string to match against
-- @treturn function [rex](http://math2.org/luasearch/rex.html) match iterator
-- @see rex.gmatch
-- @see string.gmatch
function vex:gmatch(s)
    assert(type(s) == "string", "bad argument #1 to 'gmatch' (string expected, got " .. type(s) .. ")")

    return rex.gmatch(s, self:pattern(), (self.caseless and 1 or 0) + (self.oneline and 2 or 0))
end

------------------------
-- Replaces all occurances of each match in a string with another string, the return value of a function, or the corresponding value in a table.
-- @tparam string s The string to operate on
-- @tparam string|function|table repl What to replace matches with
-- @tparam[opt=nil] number n The maximum number of matches to search for (or unlimited if nil)
-- @treturn string The string with replacements made
-- @treturn number The number of matches found
function vex:gsub(s, repl, n)
    assert(type(s) == "string", "bad argument #1 to 'gsub' (string expected, got " .. type(s) .. ")")
    assert(type(repl) == "string" or type(repl) == "function" or type(repl) == "table", "bad argument #2 to 'gsub' (string, function, or table expected, got " .. type(repl) .. ")")

    m = tonumber(n)
    return rex.gsub(s, self:pattern(), repl, n, (self.caseless and 1 or 0) + (self.oneline and 2 or 0))
end

------------------------
-- @function vex:replace
-- @see vex:gsub
vex["replace"] = vex["gsub"]

return vex
