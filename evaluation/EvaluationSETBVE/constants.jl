# paths 
path_archive = "Archive"
path_autobva = "OriginalAutoBVA"
path_agg_archive = "AggregatedArchive"
path_stats = "Stats"
path_plots = "Plots"

# experimental setup
list_run_duration = [30, 600]
top_rank_quantile = 0.99


# Plots
fig_size = (2400, 1600)
dpi = 2000
purple_color_scheme = cgrad([
    RGB(0.988,0.984,0.992),
    RGB(0.937,0.929,0.961),
    RGB(0.855,0.855,0.922),
    RGB(0.737,0.741,0.863),
    RGB(0.62,0.604,0.784),
]; categorical=true)
blue_color_scheme = cgrad([
    RGB(0.969,0.984,1.0),
    RGB(0.871,0.922,0.969),
    RGB(0.776,0.859,0.937),
    RGB(0.62,0.792,0.882),
    RGB(0.42,0.682,0.839),
]; categorical=true)

method_colors = Dict(
    "30sec:AutoBVA" => :navyblue,
    "30sec:Bituniform0" => :lightskyblue,
    "30sec:Bituniform10" => :lightskyblue,
    "30sec:Curiosity0" => :steelblue2,
    "30sec:Curiosity10" => :dodgerblue,
    "30sec:Fitness0" => :deepskyblue,
    "30sec:Fitness10" => :royalblue3,
    "30sec:Uniform0" => :royalblue,
    "30sec:Uniform10" => :mediumblue,
    "30sec:Random0" => :blue,

    "600sec:AutoBVA" => :maroon,
    "600sec:Bituniform0" => :orchid1,
    "600sec:Bituniform10" => :orchid1,
    "600sec:Curiosity0" => :palevioletred1,
    "600sec:Curiosity10" => :palevioletred3,
    "600sec:Fitness0" => :maroon3,
    "600sec:Fitness10" => :maroon2,
    "600sec:Uniform0" => :plum,
    "600sec:Uniform10" => :plum1,
    "600sec:Random0" => :plum2
)

bd_oan_global_dic = Dict(
    "circle" => Dict(
        "DomainErrorDomainError" => 0, 
        "InexactErrorInexactError" => 1,  
        "inin" =>  2,
        "outout" => 3,

        "DomainErrorInexactError" => 4, 
        "InexactErrorDomainError" => 4, 
        "DomainErrorin" => 5, 
        "inDomainError" => 5, 
        "DomainErrorout" => 6, 
        "outDomainError" => 6, 

        "InexactErrorin" => 7, 
        "inInexactError" => 7, 
        "InexactErrorout" => 8, 
        "outInexactError" => 8, 

        "inout" => 9, 
        "outin" => 9
    ), 

    "bmi" => Dict(
        "DomainErrorDomainError" => 0, 
        "UnderweightUnderweight" => 1,
        "NormalNormal" => 2,
        "OverweightOverweight" => 3, 
        "ObeseObese" => 4, 
        "Severely obeseSeverely obese" => 5,
        
        "DomainErrorUnderweight" => 6, 
        "UnderweightDomainError" => 6, 
        "DomainErrorNormal" => 7, 
        "NormalDomainError" => 7, 
        "OverweightDomainError" => 8, 
        "DomainErrorOverweight" => 8, 
        "DomainErrorObese" => 9, 
        "ObeseDomainError" => 9, 
        "DomainErrorSeverely obese" => 10, 
        "Severely obeseDomainError" => 10, 

        "UnderweightNormal" => 11,
        "NormalUnderweight" => 11, 
        "UnderweightOverweight" => 12, 
        "OverweightUnderweight" => 12, 
        "UnderweightObese" => 13, 
        "ObeseUnderweight" => 13, 
        "UnderweightSeverely obese" => 14, 
        "Severely obeseUnderweight" => 14, 

        "NormalOverweight" => 15, 
        "OverweightNormal" => 15, 
        "NormalObese" => 16, 
        "ObeseNormal" => 16, 
        "NormalSeverely obese" => 17, 
        "Severely obeseNormal" => 17,

        "OverweightObese" => 18, 
        "ObeseOverweight" => 18, 
        "OverweightSeverely obese" => 19, 
        "Severely obeseOverweight" => 19,

        "ObeseSeverely obese" => 20, 
        "Severely obeseObese" => 20,
    ),
    
)

