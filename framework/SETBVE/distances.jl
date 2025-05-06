using StringDistances

distance_stringlength(o1, o2) =
    abs(length(string(o1)) - length(string(o2)))


distance_jaccard(o1, o2; gram=2) = begin
    adjusted_gram = length(string(o1)) == 1 ? 1 : gram
    StringDistances.Jaccard(adjusted_gram)(string(o1), string(o2))
end