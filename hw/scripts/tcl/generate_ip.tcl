source [file join [file dirname [info script]] "util.tcl"]

proc get_ip_config {ip} {
    set config [dict create]

    switch $ip {
        ip_clk_wizard_spdif {
            # Xilinx clock wizard for generating S/PDIF tx clk
            dict set config "name"    "clk_wiz"
            dict set config "vendor"  "xilinx.com"
            dict set config "library" "ip"
            dict set config "version" "6.0"
            dict set config "props" [dict create                \
                CONFIG.CLKOUT1_JITTER             {571.196}     \
                CONFIG.CLKOUT1_PHASE_ERROR        {386.048}     \
                CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {6.144}       \
                CONFIG.CLKOUT2_JITTER             {419.254}     \
                CONFIG.CLKOUT2_PHASE_ERROR        {409.632}     \
                CONFIG.CLKOUT2_USED               {false}       \
                CONFIG.CLK_OUT1_PORT              {o_spdif_clk} \
                CONFIG.MMCM_CLKFBOUT_MULT_F       {44.375}      \
                CONFIG.MMCM_CLKOUT0_DIVIDE_F      {120.375}     \
                CONFIG.MMCM_CLKOUT1_DIVIDE        {1}           \
                CONFIG.MMCM_DIVCLK_DIVIDE         {6}           \
                CONFIG.NUM_OUT_CLKS               {1}           \
                CONFIG.PRIMARY_PORT               {i_spdif_clk} \
                CONFIG.USE_LOCKED                 {false}       \
                CONFIG.USE_RESET                  {false}       \
                CONFIG.PRIM_SOURCE                {No_buffer}   \
            ]
        }

        default {
            exit_with_code "unknown IP: \"${ip}\""
        }
    }

    return $config
}

proc generate_ip {ip part} {

    # Fetch IP configuration params
    set config  [get_ip_config $ip]
    set name    [dict get $config "name"]
    set vendor  [dict get $config "vendor"]
    set library [dict get $config "library"]
    set version [dict get $config "version"]
    set props   [dict get $config "props"]

    # Setup in-memory project
    create_project -in_memory -part $part
    set_property -dict [dict create \
        TARGET_LANGUAGE VHDL        \
    ] [current_project]
    
    # Create .xci file
    set files [create_ip  \
        -name $name       \
        -vendor $vendor   \
        -library $library \
        -version $version \
        -module_name $ip  \
    ]

    # Apply properties from config
    set_property -dict $props [get_ips $ip]

    # Generate all targets for newly created IP
	generate_target all $files

    # Synthesize IP
    synth_ip [get_ips $ip]
}

set spec [dict create]
dict set spec "description" \
    "configures and generates IP, writing resulting *.xci file to disk"
dict set spec "args" {
    {
        "part"
        "--part|-p"
        "str"
    }
    {
        "ip"
        "--ip|-i"
        "str"
    }
}
set args [parse_cli_args $spec]

set part [dict get $args "part"]
set ip [dict get $args "ip"]

generate_ip $ip $part
