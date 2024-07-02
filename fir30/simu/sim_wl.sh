
input_file="./simu/fir_tb.sv"

awk -v c1="$1" -v c2="$2" -v c3="$3" -v c4="$4" -v c5="$5" -v c6="$6" -v c7="$7" -v c8="$8" -v c9="$9" -v c10="${10}" -v c11="${11}" -v c12="${12}" -v c13="${13}" -v c14="${14}" -v c15="${15}"  '
{

    if ($1 == "localparam" && $3 == "PRODUCT_FRAC_WL_ARRAY"){
        
         $6 = "{"  c1 "," c2 "," c3 "," c4 "," c5 "," c6 "," c7 "," c8 "," c9 "," c10 "," c11 "," c12 "," c13 "," c14 "," c15 "}"
    }

    print
}
' "$input_file" > temp_file && mv temp_file "$input_file"