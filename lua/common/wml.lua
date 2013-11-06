<<

-- Finds the first sub-tag with the given name in tag's content (tag[2]).
function wml_find_tag(cfg, name)
    for i,tag in ipairs(cfg) do
        if tag[1] == name then
            return tag
        end
    end

    return nil
end

-- Finds the first sub-tag with the given name in the given tag content
-- (tag[2]), and returns its content (subtag[2]).
function wml_find_cfg(cfg, name)
    local tag = wml_find_tag(cfg, name)

    if tag ~= nil then
        return tag[2]
    end

    return nil
end

-- Finds all sub-tags with the given name in tag's content (tag[2]).
function wml_find_many_tags(cfg, name)
    local tags = {}

    for i,tag in ipairs(cfg) do
        if tag[1] == name then
            table.insert(tags, tag)
        end
    end

    return tags
end

>>
