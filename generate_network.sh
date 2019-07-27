# args are:
#   $1 => MODEL_DIR
#   $2 => FILT_SIZES
#   $3 => Incr act
MODEL_DIR=$1
PREC=6
A_PREC=8
B_PREC=14
D3_PREC=6
FILT_SIZES=$2
NU_CONV=1.2
NU_DENSE=0.7

SCRIPT="""
from math import ceil;
filt_str = \"$FILT_SIZES\";
try:
  no_filt = int(filt_str);
except ValueError:
  no_filt = int(filt_str.split(\",\")[6]);
print( no_filt );
"""
NO_FILT=$(python3 -c "$SCRIPT")

D1_IN=$(python3 -c "from math import ceil; print(ceil(8*$NO_FILT/512))")

# extract the values from tensorflow
python3 train_tnn/extract_weights_from_vgg.py --model_name $MODEL_DIR --nu_conv $NU_CONV --nu_dense $NU_DENSE --twn_incr_act $3 --d3_rshift $D3_PREC

# create BN csvs
for i in {1..7}
do
  python3 verilog_generation/generate_bn_vecs.py $MODEL_DIR/vgg_bn_lyr$i.csv $MODEL_DIR/bn$i.sv $i $A_PREC $B_PREC
done
for i in {1..2}
do
  python3 verilog_generation/generate_bn_vecs.py $MODEL_DIR/vgg_bn_dense_$i.csv $MODEL_DIR/bnd$i.sv d$i $A_PREC $B_PREC
done

# run cse and create convs
python3 verilog_generation/generate_tw_vgg10.py $MODEL_DIR

# generate dense vars: input_weights, output_file, lyr_idx, right_shift, bitwidth, no_inputs/cyc
python3 verilog_generation/generate_dense_vecs.py $MODEL_DIR/vgg_dense_1.csv $MODEL_DIR/dense_1.sv 1 0 2 $D1_IN
python3 verilog_generation/generate_dense_vecs.py $MODEL_DIR/vgg_dense_2.csv $MODEL_DIR/dense_2.sv 2 0 2 1
python3 verilog_generation/generate_dense_vecs.py $MODEL_DIR/vgg_dense_3.csv $MODEL_DIR/dense_3.sv 3 $D3_PREC 16 1

# generate test vectors
python3 train_tnn/compute_vgg_with_csv.py --model_name $MODEL_DIR --nu_conv $NU_CONV --nu_dense $NU_DENSE --no_filt $FILT_SIZES --prec $PREC --bn_p $A_PREC \
--wr_files --results_name $MODEL_DIR/tmp_res.csv
python3 verilog_generation/generate_test_vecs.py $MODEL_DIR/input_img.csv $MODEL_DIR/input_hex.sv IN $PREC
#python3 verilog_generation/generate_test_vecs.py $MODEL_DIR/conv_mp_img_lyr1.csv $MODEL_DIR/mp1_hex.sv OUT $PREC
#python3 verilog_generation/generate_test_vecs.py $MODEL_DIR/conv_mp_img_lyr7.csv $MODEL_DIR/mp7_hex.sv OUT $PREC
#python3 verilog_generation/generate_test_vecs.py $MODEL_DIR/dense_img_lyr1.csv $MODEL_DIR/dense_1_hex.sv OUT $PREC
#python3 verilog_generation/generate_test_vecs.py $MODEL_DIR/dense_img_lyr2.csv $MODEL_DIR/dense_2_hex.sv OUT $PREC
#python3 verilog_generation/generate_test_vecs.py $MODEL_DIR/dense_bn_relu_img_lyr2.csv $MODEL_DIR/dense_2_bn_hex.sv OUT $PREC
python3 verilog_generation/generate_test_vecs.py $MODEL_DIR/pred_output.csv $MODEL_DIR/dense_3_hex.sv OUT $PREC

