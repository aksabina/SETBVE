# general 
batch_size = 1
total_args_num = Dict(
    "circle" => 4, 
    "date" => 6,
    "bmi" => 4,
    "bytecount" => 2, 
    "two_circles" => 4,
    "power_by_squaring" => 4,
    "tailjoin" => 4,
    "max" => 4,
    "cld" => 4,
    "fldmod1" => 4,
    "fld" => 4
)

# SUTs
circle_center_x, circle_center_y = 0, 0
circleA_center_x, circleA_center_y = 100, 100
circleB_center_x, circleB_center_y = 300, 300
radius = 80 
radiusA = 20
radiusB = 80

# search
datatypes = [UInt8, UInt16, UInt32, UInt64, UInt128,  
            Int8, Int16, Int32, Int64, Int128,
            Bool]

default_parent_id = 0  # used to init Emitters when there are no parents

local_search_neighbors_num = 30
local_search_delta_calc_rows = 30 
local_search_vv_ratio = 0.5
local_search_ve_ratio = 0.4
local_search_ee_ratio = 0.1

# filepaths
dir_archive = "Archive/"
dir_plots = "Plots/Solutions/"

# plots
fig_size_dic = Dict(
    "circle" => (1000, 1000),
    "two_circles" => (800, 800),
    "bmi" => (1200, 1000),
    "date" => (1200, 1000), 
    "bytecount" => (1200, 1000), 
    "default" => (1000, 1000)
)

range_zoomed_dic = Dict(
    "circle" => [-200, 200],
    "two_circles" => [0, 400],
    "bmi" => [-10, 300], 
    "date" => [-10, 35]
)

fitness_plot_threshold = 0.1
output_color_map = Dict(
    "DomainError" => :gray,
    "ArgumentError" => :gray,
    "ValidDate" => :green,
    "in" => :green,
    "out" => :orange,
    "Normal" => :green,
    "Overweight" => :yellow,
    "Obese" => :orange,
    "Severely obese" => :red,
    "Underweight" => :lightblue,
    "insideA" => :purple,
    "insideB" => :yellow,
    "outsideBoth" => :red)

