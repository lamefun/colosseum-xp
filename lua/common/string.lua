<<

function cc.starts_with(a, b)
   return string.sub(a, 1, string.len(b)) == b
end

function cc.ends_with(a, b)
   return b == '' or string.sub(a, -string.len(b)) == b
end

>>
