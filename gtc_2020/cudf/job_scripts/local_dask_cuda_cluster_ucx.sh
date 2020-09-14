#!/usr/bin/env bash

CONDA_ENV_DIR=/datasets/pentschev/miniconda3/envs/r-102-0.15
DASK_DIR=/tmp/dask

if [ ! -d "$DASK_DIR" ] 
then
    mkdir -p $DASK_DIR
fi

# clean previous contents
rm -fr $DASK_DIR/*

export SCHEDULER_FILE=$DASK_DIR/my-scheduler-gpu.json

# Several dask schedulers could run in the same batch node by different users,
# create a random port to reduce port collisions
PORT_SCHED=$(shuf -i 4000-6000 -n 1)
PORT_DASH=$(shuf -i 7000-8999 -n 1)

# saving ports to use them if  launching jupyter lab
echo $PORT_SCHED >> $DASK_DIR/port_sched
echo $PORT_DASH  >> $DASK_DIR/port_dash

# $HOSTNAME=hostname
echo "Hostname:" $HOSTNAME
echo "Scheduler port:" $PORT_SCHED
echo "Dashboard port:" $PORT_DASH
echo "Scheduler JSON Path:" $SCHEDULER_FILE
echo "Dask dir:" $DASK_DIR

DASK_UCX__CUDA_COPY=True DASK_UCX__NVLINK=True DASK_UCX__INFINIBAND=False DASK_UCX__NET_DEVICES=ib0 $CONDA_ENV_DIR/bin/python -m distributed.cli.dask_scheduler --protocol ucx --port $PORT_SCHED --dashboard-address $HOSTNAME:$PORT_DASH --interface ib0 --scheduler-file $SCHEDULER_FILE &
#DASK_UCX__CUDA_COPY=True DASK_UCX__NVLINK=True DASK_UCX__INFINIBAND=True DASK_UCX__NET_DEVICES=ib0 DASK_RMM__POOL_SIZE=1GB $CONDA_ENV_DIR/bin/python -m distributed.cli.dask_scheduler --protocol ucx --port $PORT_SCHED --dashboard-address $HOSTNAME:$PORT_DASH --interface ib0 --scheduler-file $SCHEDULER_FILE &

# Give the scheduler a chance to spin up.
sleep 10

echo Starting workers

# Count the unique host names and subtract the batch node to get
# the actual number of nodes allocated to this job.
#let num_nodes=(`cat $LSB_DJOB_HOSTFILE | sort | uniq | wc -l` - 1)
num_nodes=1

# We want six workers per node
let num_workers=($num_nodes * 6)

export NUM_WORKERS=$num_workers

echo "Num workers: " $NUM_WORKERS

NRS=$( (( $NUM_WORKERS <= 6 )) && echo "$NUM_WORKERS" || echo "6" )

# Only use 6 workers to match Summit's topology

# NVLink only
CUDA_VISIBLE_DEVICES=0,1 $CONDA_ENV_DIR/bin/python -m dask_cuda.cli.dask_cuda_worker --scheduler-file $SCHEDULER_FILE  --nthreads 1 --memory-limit 85GB --device-memory-limit 28GB  --rmm-pool-size 28GB --death-timeout 60 --interface ib0  --enable-nvlink --local-directory $DASK_DIR/tmp &
CUDA_VISIBLE_DEVICES=2,3 $CONDA_ENV_DIR/bin/python -m dask_cuda.cli.dask_cuda_worker --scheduler-file $SCHEDULER_FILE  --nthreads 1 --memory-limit 85GB --device-memory-limit 29GB  --rmm-pool-size 28GB --death-timeout 60 --interface ib1  --enable-nvlink --local-directory $DASK_DIR/tmp &
CUDA_VISIBLE_DEVICES=4,5 $CONDA_ENV_DIR/bin/python -m dask_cuda.cli.dask_cuda_worker --scheduler-file $SCHEDULER_FILE  --nthreads 1 --memory-limit 85GB --device-memory-limit 28GB  --rmm-pool-size 28GB --death-timeout 60 --interface ib2  --enable-nvlink --local-directory $DASK_DIR/tmp

# NVLink + IB
#CUDA_VISIBLE_DEVICES=0,1 $CONDA_ENV_DIR/bin/python -m dask_cuda.dask_cuda_worker --scheduler-file $SCHEDULER_FILE  --nthreads 1 --memory-limit 85GB --device-memory-limit 16GB  --death-timeout 60 --interface ib0 --enable-infiniband --net-devices="ib0" --enable-nvlink --rmm-pool-size="30GB" --local-directory $DASK_DIR/tmp &
#CUDA_VISIBLE_DEVICES=2,3 $CONDA_ENV_DIR/bin/python -m dask_cuda.dask_cuda_worker --scheduler-file $SCHEDULER_FILE  --nthreads 1 --memory-limit 85GB --device-memory-limit 16GB  --death-timeout 60 --interface ib1 --enable-infiniband --net-devices="ib1" --enable-nvlink --rmm-pool-size="30GB" --local-directory $DASK_DIR/tmp &
#CUDA_VISIBLE_DEVICES=4,5 $CONDA_ENV_DIR/bin/python -m dask_cuda.dask_cuda_worker --scheduler-file $SCHEDULER_FILE  --nthreads 1 --memory-limit 85GB --device-memory-limit 16GB  --death-timeout 60 --interface ib2 --enable-infiniband --net-devices="ib2" --enable-nvlink --rmm-pool-size="30GB" --local-directory $DASK_DIR/tmp
