using StringDistances, InformationDistances

distance_stringlength(a, b) =
    abs(length(string(a)) - length(string(b)))


distance_jaccard(a, b; gram=2) = begin
    adjusted_gram = length(string(a)) == 1 ? 1 : gram
    StringDistances.Jaccard(adjusted_gram)(string(a), string(b))
end

function distance_ncd(a, b)
    d = NormalizedCompressionDistance()
    return d(string(a), string(b))
end