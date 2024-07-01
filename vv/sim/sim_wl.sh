input_file="../src/vv_support.vhdl"

awk -v c1="$1" -v c2="$2" -v c3="$3" -v c4="$4" -v c5="$5" '
{

    if ($1 == "constant" && $2 == "MAGNITUDE_WL") {
        $6 = c1
        $7 = ";"
    }

    if ($1 == "constant" && $2 == "PARTITIONED_WL") {
        $6 = c2
        $7 = ";"
    }

    if ($1 == "constant" && $2 == "SQUARE_WL") {
        $6 = c3
        $7 = ";"
    }
    if ($1 == "constant" && $2 == "FOURTH_WL") {
        $6 = c4
        $7 = ";"
    }

    if ($1 == "constant" && $2 == "PHASE_WL") {
        $6 = c5
        $7 = ";"
    }


    print
}
' "$input_file" > temp_file && mv temp_file "$input_file"