<<

function cc.keys(t)
    local keys = {}
    for k,v in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end

function cc.intersect(l)
    local r = cc.copy(l[1])

    for i = 2, #l do
        local s = l[i]
        local nr = {}

        for k,v in pairs(r) do
            if s[k] ~= nil then
                nr[k] = v
            end
        end

        r = nr
    end

    return r
end

>>
