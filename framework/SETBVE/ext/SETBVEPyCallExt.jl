# SETBVE's SUTs written in Python: a package extension, loaded when the code using SETBVE loads PyCall (`using PyCall`).
# It registers the python_normalize SUT.
module SETBVEPyCallExt

using SETBVE, PyCall

function sut_python_normalizer(args_vec::AbstractVector{<:Any})
    # Step 1: Extract the input vector
    vec = args_vec[1]
    # Step 2: Load the Python file and function
    py"""
    import sys
    sys.path.append(".")  # ensures current directory is in path
    from process_array import normalize_array
    """
    # Step 3: Call the Python function
    normalized_array = py"normalize_array"(vec)
    return normalized_array
end

function __init__()
    SETBVE.sut_functions_dic["python_normalize"] = sut_python_normalizer
end

end  # module
