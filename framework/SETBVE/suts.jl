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

function sut_factorial(args_vec::AbstractVector{<:Any})
    arg1 = args_vec[1]
    return Base.factorial(arg1)
end

function sut_float(args_vec::AbstractVector{<:Any})
    arg1 = args_vec[1]
    return Base.float(arg1)
end

function sut_isodd(args_vec::AbstractVector{<:Any})
    arg1 = args_vec[1]
    return Base.isodd(arg1)
end

function sut_count_zeros(args_vec::AbstractVector{<:Any})
    arg1 = args_vec[1]
    return Base.count_zeros(arg1)
end

function sut_digits(args_vec::AbstractVector{<:Any})
    arg1 = args_vec[1]
    return Base.digits(arg1)
end

function sut_hton(args_vec::AbstractVector{<:Any})
    arg1 = args_vec[1]
    return Base.hton(arg1)
end

function sut_div(args_vec::AbstractVector{<:Any})
    arg1, arg2 = args_vec[1], args_vec[2]
    return Base.div(arg1, arg2)
end

function sut_mul_prod(args_vec::AbstractVector{<:Any})
    arg1, arg2 = args_vec[1], args_vec[2]
    return Base.mul_prod(arg1, arg2)
end

function sut_rem(args_vec::AbstractVector{<:Any})
    arg1, arg2 = args_vec[1], args_vec[2]
    return Base.rem(arg1, arg2)
end

function sut_first(args_vec::AbstractVector{<:Any})
    arg1, arg2 = args_vec[1], args_vec[2]
    return Base.first(arg1, arg2)
end

function sut_copysign(args_vec::AbstractVector{<:Any})
    arg1, arg2 = args_vec[1], args_vec[2]
    return Base.copysign(arg1, arg2)
end

function sut_invmod(args_vec::AbstractVector{<:Any})
    arg1, arg2 = args_vec[1], args_vec[2]
    return Base.invmod(arg1, arg2)
end

function sut_minmax(args_vec::AbstractVector{<:Any})
    arg1, arg2 = args_vec[1], args_vec[2]
    return Base.minmax(arg1, arg2)
end

function sut_gcd(args_vec::AbstractVector{<:Any})
    arg1, arg2 = args_vec[1], args_vec[2]
    return Base.gcd(arg1, arg2)
end

function sut_range(args_vec::AbstractVector{<:Any})
    arg1, arg2, arg3 = args_vec[1], args_vec[2], args_vec[3]
    return Base.range(arg1, arg2, arg3)
end

function sut_fma(args_vec::AbstractVector{<:Any})
    arg1, arg2, arg3 = args_vec[1], args_vec[2], args_vec[3]
    return Base.fma(arg1, arg2, arg3)
end

function sut_muladd(args_vec::AbstractVector{<:Any})
    arg1, arg2, arg3 = args_vec[1], args_vec[2], args_vec[3]
    return Base.muladd(arg1, arg2, arg3)
end

function sut_xor(args_vec::AbstractVector{<:Any})
    arg1, arg2, arg3 = args_vec[1], args_vec[2], args_vec[3]
    return Base.xor(arg1, arg2, arg3)
end

function sut_promote(args_vec::AbstractVector{<:Any})
    arg1, arg2, arg3 = args_vec[1], args_vec[2], args_vec[3]
    return Base.promote(arg1, arg2, arg3)
end

function sut_powermod(args_vec::AbstractVector{<:Any})
    arg1, arg2, arg3 = args_vec[1], args_vec[2], args_vec[3]
    return Base.powermod(arg1, arg2, arg3)
end

function sut_element_at_position(args_vec::AbstractVector{<:Any})
    arr, pos = args_vec[1], Integer(args_vec[2])
    return arr[pos]
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
    "factorial" => sut_factorial,
    "float" => sut_float,
    "isodd" => sut_isodd,
    "count_zeros" => sut_count_zeros,
    "digits" => sut_digits,
    "hton" => sut_hton,
    "div" => sut_div,
    "mul_prod" => sut_mul_prod,
    "rem" => sut_rem,
    "first" => sut_first,
    "copysign" => sut_copysign,
    "invmod" => sut_invmod,
    "minmax" => sut_minmax,
    "gcd" => sut_gcd,
    "range" => sut_range,
    "fma" => sut_fma,
    "muladd" => sut_muladd,
    "xor" => sut_xor,
    "promote" => sut_promote,
    "powermod" => sut_powermod,
    "element_at_position" => sut_element_at_position
)

