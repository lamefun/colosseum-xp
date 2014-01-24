<<

function cc.choice_index(t)
    if #t == 0 then
        return nil
    end

    return math.floor(math.random(1, #t) + 0.5)
end

function cc.choice(t)
    if #t == 0 then
        return nil
    end

    local i = math.floor(math.random(1, #t) + 0.5)
    return t[i]
end

-- usage:
--
-- weighted_choice {
--   { weight, value }
-- }
--
function cc.weighted_choice(t)
    local sum = 0

    if #t == 0 then
        return nil
    end

    for i,v in ipairs(t) do
        sum = sum + v[1]
    end

    local cur = math.random(0, sum)
    local i = 1

    while i <= #t do
        local v = t[i]
        if cur <= v[1] then
            return v[2]
        else
            cur = cur - v[1]
        end
        i = i + 1
    end

    return t[1][1]
end

>>
