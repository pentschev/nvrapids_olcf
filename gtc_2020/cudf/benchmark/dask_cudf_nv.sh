NUM_WORKERS=4
PACKAGE="dask_cudf"
SCRIPT="cudf_benchmarking_nv.py"
PROJ_ID="gen119"
SCHEDULER_JSON="$MEMBERWORK/$PROJ_ID/dask/my-scheduler-gpu.json"

module load gcc/7.4.0
module load cuda/10.1.243
module load python/3.7.0-anaconda3-5.3.0

export PATH=$WORLDWORK/stf011/nvrapids_0.14_gcc_7.4.0/bin:$PATH

# I/O - TESTING CHUNKING

#python $SCRIPT --package $PACKAGE --num_dask_workers $NUM_WORKERS --scheduler_json_path $SCHEDULER_JSON --file_size 20G --read_chunk_mb 4096 --stop_at_read True
#python $SCRIPT --package $PACKAGE --num_dask_workers $NUM_WORKERS --scheduler_json_path $SCHEDULER_JSON --file_size 25G --stop_at_read True

# Partitioning

python $SCRIPT --package $PACKAGE --num_dask_workers $NUM_WORKERS --scheduler_json_path $SCHEDULER_JSON --file_size 25G
