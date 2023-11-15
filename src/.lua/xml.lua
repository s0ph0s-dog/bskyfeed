--- A Tiny XML Library for Redbean
-- The API for this library is designed to be small and to move many errors to
-- compile/interpretation time, rather than letting them occur at runtime.
--
-- Here's how to produce a very small example document:
--
-- local example = tag(
--     "example", false, { xmlns = "http://example.com/example" },
--     tag(
--         "elementWithAttributes", true, { a = "hello", b = "world" }
--     ),
--     tag(
--         "elementWithChildren", false,
--         tag(
--             "child", false, text(1)
--         ),
--         tag(
--             "child", false, cdata(2)
--         )
--     )
-- )
--
-- This example produces the following XML:
-- <example xmlns="http://example.com/example">
--   <elementWithAttributes a="hello" b="world"/>
--   <elementWithChildren>
--     <child>1</child>
--     <child><![CDATA[2]]></child>
--   </elementWithChildren>
-- </example>
--
-- Note that the example here has been pretty-printed to increase readability.
-- To minimize the size of network payloads, the output of this library contains
-- no whitespace characters that you do not explicitly insert.

--- Escape characters that should not be in XML attribute values.
-- The prohibited characters are single- and double-quotes.
-- @param value The attribute value to escape.
-- @return A new string containing similar data, suitably escaped.
local function escapeAttr(value)
    return string.gsub(value, '["\']', { ["'"] = "&#39;", ['"'] = "&quot;" })
end

--- Create an XML text node.
-- @param value The text value to add.
-- @return A string that contains similar text, with appropriate escaping to
--         ensure it does not contain valid elements.
local function text(value)
    return EscapeHtml(value)
end

--- Create an XML CDATA node.
-- @param value The CDATA value to add.
-- @return A string starting with `<![CDATA[` and ending with `]]>` that may
--         represent one or more CDATA notes, in order to ensure that any
--         instances of `]]>` in the input value do not escape containment.
local function cdata(value)
    local no_gt = string.gsub(value, "]]>", "]]&gt;")
    return string.format("<![CDATA[%s]]>", no_gt)
end

--- Create an arbitrary XML element.
-- @param tagName The name of the tag (ex: `rss`, `b`, `img`, etc.)
-- @param selfClosing True if the tag is self-closing, false if it may have
--        children.  Passing `true` will cause any child arguments to be
--        silently ignored.
-- @param attrsOrFirstChild Either a table of attributes for the element, or a
--        string representing the value of the first child (likely created by
--        calling this function or another function in this library.)
-- @param ... More strings representing additional children.
-- @return A string containing (probably) valid XML representing the tag, any
--         attributes, and children (when appropriate).
local function tag(tagName, selfClosing, attrsOrFirstChild, ...)
    local children = { ... }

    if not tagName or type(tagName) ~= "string" or #tagName == 0 then
        error("tag: tagName is not a string (or is emptystr)")
    end
    if string.match(tagName, "%s") then
        error("tag: tagName cannot contain whitespace")
    end
    if selfClosing and (#children > 0 or type(attrsOrFirstChild) == "string") then
        error("tag: self closing tags cannot have children")
    end

    local attrs = {}
    if type(attrsOrFirstChild) == "string" then
        table.insert(children, 1, attrsOrFirstChild)
        attrsOrFirstChild = {}
    end
    if attrsOrFirstChild ~= nil and type(attrsOrFirstChild) == "table" then
        for key, value in pairs(attrsOrFirstChild) do
            if type(value) ~= "boolean" then
                table.insert(
                    attrs,
                    string.format(' %s="%s"', key, escapeAttr(value))
                )
            elseif value then
                table.insert(attrs, " " .. key)
            end
        end
    end

    local opening = string.format("<%s%s", tagName, table.concat(attrs))
    if selfClosing then
        return opening .. "/>"
    else
        return string.format("%s>%s</%s>", opening, table.concat(children), tagName)
    end
end

return {
    escapeAttr = escapeAttr,
    text = text,
    cdata = cdata,
    tag = tag
}
