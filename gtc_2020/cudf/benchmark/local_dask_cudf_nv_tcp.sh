NUM_WORKERS=6
PACKAGE="dask_cudf"
SCRIPT="local_cudf_benchmarking_nv.py"
SCHEDULER_JSON="/tmp/dask/my-scheduler-gpu.json"

CONDA_ENV_DIR=/datasets/pentschev/miniconda3/envs/r-102-0.15

# I/O - TESTING CHUNKING

#python $SCRIPT --package $PACKAGE --num_dask_workers $NUM_WORKERS --scheduler_json_path $SCHEDULER_JSON --file_size 25G --read_chunk_mb 4096 --stop_at_read True
python $SCRIPT --package $PACKAGE --num_dask_workers $NUM_WORKERS --scheduler_json_path $SCHEDULER_JSON --file_size 25G --stop_at_read True

# Partitioning

python $SCRIPT --package $PACKAGE --num_dask_workers $NUM_WORKERS --scheduler_json_path $SCHEDULER_JSON --file_size 25G

