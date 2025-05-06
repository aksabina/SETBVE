using Printf
function sut_circle(args_vec::AbstractVector{<:Any})
    x, y = Integer(args_vec[1]), Integer(args_vec[2])

    distance = sqrt((x - circle_center_x)^2 + (y - circle_center_y)^2)

    if x == 0 && y == 0
        throw(DomainError("The point should not be at the origin (0, 0)"))
    elseif distance <= radius
        return "in"
    else
        return "out"
    end

end

function sut_two_circles(args_vec::AbstractVector{<:Any})
    x, y = Integer(args_vec[1]), Integer(args_vec[2])

    distanceA = sqrt((x - circleA_center_x)^2 + (y - circleA_center_y)^2)
    distanceB = sqrt((x - circleB_center_x)^2 + (y - circleB_center_y)^2)

    if distanceA  <= radiusA
        return "insideA"
    elseif distanceB <= radiusB
        return "insideB"
    else 
        return "outsideBoth"
    end
end


function sut_date(args_vec::AbstractVector{<:Any})
    day, month, year = args_vec[1], args_vec[2], args_vec[3]
    return Date(year, month, day)
end


function sut_bmi(args_vec::AbstractVector{<:Any})
    height, weight = args_vec[1], args_vec[2]
    if height < 0 || weight < 0
        throw(DomainError("Height or Weight cannot be negative."))
    end

    height_meters = height / 100 # Convert height from cm to meters
    bmivalue = round(weight / height_meters^2, digits=1) # official standard expects 1 decimal after the comma

    if bmivalue < 0
        throw(DomainError(bmivalue, "BMI was negative. Check your inputs: $(height) cm; $(weight) kg"))
    elseif bmivalue < 18.5
        return "Underweight"
    elseif bmivalue < 23
        return "Normal"
    elseif bmivalue < 25
        return "Overweight"
    elseif bmivalue < 30
        return "Obese"
    else
        return "Severely obese"
    end

    return ""  # default value
end

function sut_bytecount(args_vec::AbstractVector{<:Any})
    bytes = args_vec[1]
    si = true
    unit = si ? 1000 : 1024
    absBytes = bytes == typemax(Int64) ? typemax(Int64) : abs(bytes)

    if bytes < unit
        return string(bytes) * "B"
    end

    exp = floor(Int, log(bytes) / log(unit))
    th = trunc(Int128,unit^exp * (unit - 0.05))

    if (exp < 6 && absBytes >= th - ((th & 0xfff) == 0xd00 ? 52 : 0))
        exp = exp + 1
    end

    pre = (si ? "kMGTPE" : "KMGTPE")[exp] * (si ? "" : "i")
    if (exp > 4)
        bytes = div(bytes, unit)
        exp = exp - 1
    end

    @sprintf("%.1f %sB", bytes / (unit^exp), pre)
end


# Julia Base SUTs

function sut_power_by_squaring(args_vec::AbstractVector{<:Any})
    arg1, arg2 = Integer(args_vec[1]), Integer(args_vec[2])
    return Base.power_by_squaring(arg1, arg2)
end

function sut_tailjoin(args_vec::AbstractVector{<:Any})
    arg1, arg2 = Integer(args_vec[1]), Integer(args_vec[2])
    return Base.tailjoin(arg1, arg2)
end

function sut_max(args_vec::AbstractVector{<:Any})
    arg1, arg2 = Integer(args_vec[1]), Integer(args_vec[2])
    return Base.max(arg1, arg2)
end

function sut_cld(args_vec::AbstractVector{<:Any})
    arg1, arg2 = Integer(args_vec[1]), Integer(args_vec[2])
    return Base.cld(arg1, arg2)
end

function sut_fldmod1(args_vec::AbstractVector{<:Any})
    arg1, arg2 = args_vec[1], args_vec[2]
    return Base.fldmod1(arg1, arg2)
end

function sut_fld(args_vec::AbstractVector{<:Any})
    arg1, arg2 = args_vec[1], args_vec[2]
    return Base.fld(arg1, arg2)
end



sut_functions_dic = Dict(
    "circle" => sut_circle,
    "date" => sut_date,
    "bmi" => sut_bmi, 
    "bytecount" => sut_bytecount,
    "two_circles" => sut_two_circles,
    "power_by_squaring" => sut_power_by_squaring,
    "tailjoin" => sut_tailjoin,
    "max" => sut_max,
    "cld" => sut_cld,
    "fldmod1" => sut_fldmod1,
    "fld" => sut_fld,
)

