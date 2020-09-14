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

$CONDA_ENV_DIR/bin/python -m distributed.cli.dask_scheduler --port $PORT_SCHED --dashboard-address $HOSTNAME:$PORT_DASH --interface ib0 --scheduler-file $SCHEDULER_FILE &

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
CUDA_VISIBLE_DEVICES=0,1,2,3,4,5 $CONDA_ENV_DIR/bin/python -m dask_cuda.cli.dask_cuda_worker --scheduler-file $SCHEDULER_FILE  --nthreads 1 --memory-limit 85GB --device-memory-limit 30GB --rmm-pool-size 30GB --death-timeout 60 --interface ib0 --local-directory $DASK_DIR/tmp
