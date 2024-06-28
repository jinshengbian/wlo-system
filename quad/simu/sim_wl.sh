
input_file="./simu/quad.sv"

awk -v c1="$1" -v c2="$2" -v c3="$3" '
{

    if ($1 == "parameter" && $2 == "FWL_A"){
        
         $4 = c1
    }
    if ($1 == "parameter" && $2 == "FWL_B"){
        
         $4 = c2
    }
    if ($1 == "parameter" && $2 == "FWL_C"){
        
         $4 = c3
    }

    print
}
' "$input_file" > temp_file && mv temp_file "$input_file"