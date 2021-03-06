# Benchmarking cudf on Summit

## System configuration

* IBM Power System AC922. 2x POWER9 CPU (84 smt cores each) 512 GB RAM, 6x NVIDIA Volta GPU with 16 GB HBM2
* GCC v6.4
* CUDA v10.1.168
* NVIDIA Driver v418.67
* NVIDIA Rapids v0.11
* cudf v0.11.0b0+7.g3498c7e.dirty
* dask-cudf v0.11.0b0+7.g3498c7e.dirty
* dask v2.9.1
* pandas v0.25.3

## Running the benchmark

First, run the appropriate job script that provisions the compute allocation and a dask cluster:
* `dask-cudf`: [dask cuda scheduler + dask cuda workers](./job_scripts/launch_dask_cuda_cluster.lsf) 
* `dask`: [dask scheduler + dask workers](./job_scripts/launch_dask_cuda_cluster.lsf)
* `cudf`: [job script that also runs a benchmark](./job_scripts/launch_cudf.lsf)
* `pandas`: [job script that also runs a benchmark](./job_scripts/launch_pandas.lsf)

Next, run benchmarking script by following the help: 

```bash
python cudf_benchmarking.py --help
```

## 1. Groupby Results

### 1.1. Baseline 
![alt text](./figures/pandas_benchmarks.png "Pandas baseline")
**Figure 1**: Summary of durations for (left) loading a csv file, (center) calculate the number of unique values, and (right) groupby on a single column using the ``pandas`` package that is capable of only using one CPU socket (IBM Power 9 CPU in this case) and potentially multiple threads. 

![alt text](./figures/cudf_benchmarks.png "cudf baseline")
**Figure 2**: Summary of durations for (left) loading a csv file, (center) calculate the number of unique values, and (right) groupby on a single column using the ``cudf`` package that is capable of using a single NVIDIA GPU (Volta V100 in this case).

### 1.2. Optimally reading a csv

**Two Summit nodes (total of 12 NVIDIA Volta V100 GPUs each with 16 GB memory, 84 physical cores on IBM Power 9 CPUs, and 1.024 TB of CPU addressable memory) were used for all dask and dask-cudf experiments, unless stated otherwise**

Both `dask-cudf` and `dask` are capable of reading `.csv` files in blocks or chunks. Using the optimal block or chunk size can substantially change the speed with which large `.csv` files are read into memory. 

![alt text](./figures/Dask-cudf_chunk_sizes_load_times_3.png  "dask cudf chunksize")
**Figure 3**: The `chunksize` parameter in `dask-cudf.read_csv()` was varied from `32 MB` to `4 GB` for spreadsheets ranging from `1 GB` to `25 GB` as shown in the legend. For obvious reasons, `chunksize`s larger than the size of the data file were not used in experiments. Also, very small `chunksize`s relative to the size of the `csv` file were also not used. The figures show that the loading time varies inversely with the `chunksize` and directly with the number of effective `partitions`. Here `partitions` are the number of chunks dask chops the `csv` file and can be calculated as the quotient of the file size and the `chunksize`. Experiments with the default parameters (`chunksize` = `256 MB`) are shown as larger markers with a black border to separate them from experiments where the `chunksize` was manually altered. Thus, it appears that the `chunksize` should be roughly `1/2` to `1/4` the size of the size of the file for the fastest loading time. Since the default `chunksize` is fixed, the performance improvements of changing the `chunksize` are more pronunced as the dataframe size increases beyond `5 GB`.

![alt text](./figures/Dask_block_sizes_load_times_3.png  "dask blocksize")
**Figure 4**: The `blocksize` parameter in `dask.dataframe.read_csv()` was varied from `32 MB` to `1 GB` when reading  spreadsheets ranging from `1 GB` to `25 GB` as shown in the legend. For obvious reasons, `blocksize`s larger than the size of the data file were not used in experiments. Also, very small `blocksize`s relative to the size of the `csv` file were also not used. Note that, in these experiments, it was not possible to use `blocksize` greater than `1 GB`. The time to load spreadsheets varies inversely with the `blocksize`. Very substantial improvements to the loading time can be obtained by increasing the `blocksize` to the supposed maximum of `1 GB` from the default value of `64 MB`. 

### 1.3. Partitioning the dataframe to maximize performance

![alt text](./figures/Dask_cudf_partition_size_vs_unique_groupby_time_2.png  "dask cudf partitions")
**Figure 5**: The dataframe was repartitioned after loading from csv to study the effects of such repartitoning on the time taken to compute the number of unique values in a particular column and performing a few groupby operations. Given that the experiments were run on `2` Summit nodes having a total of `12 GPUs`, the dataframes were partitioned into fractions or multiples of the number of GPUs since each dask-cuda worker was pinned to a single GPU and CPU core. In other words, the dataframe was partitioned into `3`, `6`, `12`, `24`, `48`, and `96` partitions. The size per partition was calculated as the quotient of the size of the csv file and the number of partitions. By default `dask-cudf` uses partitions that are `256 MB` in size and such data-points have been marked as large circles with black borders. The top right plot shows a very clear minima at ~ `256 MB` indicating that the best performance for finding the number of unique values in a column can only be achieved by using the default partitioning parameters. The plot on the bottom left indicates that the time required to perform the groupby operation varies directly with the number of partitions. However, having too few partitions (`3` in this case) can adversely affect the performance. The best performance was obtained when the dataset was partitioned to `1/2` the number of GPU workers (`6` in this case). Note that the performance difference between the best and worst partition sizes (studied in these epxeriments) can range over two orders of magnitude. in the case of the computatioanlly expensive groupby operation being studied here, the benefits of shrinking the number of partitions grows more substantially with the size of the dataset in question.

![alt text](./figures/Dask_cudf_groupby_timing_vs_partitions.png "dask cudf what partitions") 
**Figure 6**: This figure plots the time require to complete the `unique()` and `groupby()` operations as a function of the size of the dataset where the dataframe was partitioned into `3`, `6`, `12`, `24`, `48`, and `96` partitions. The plot for `unique()` on the left shows that the default partition size offers the best performance while the plot on the right for `groupby()` shows that setting the number of partitions to `6` or `1/2` the total number of GPU workers (`12`), delivers the best performance.  

![alt text](./figures/Dask_partition_size_vs_unique_groupby_time_2.png "dask partitions") 
**Figure 7**: The dataframe was repartitioned after loading from csv to study the effects of such repartitoning on the time taken to compute the number of unique values in a particular column and performing a few groupby operations. Given that the experiments were run on `2` Summit nodes having a total of `84` dask workers (one pinned to each physical CPU core), the dataframes were partitioned into fractions or multiples of the total number of CPU cores. In other words, the dataframe was partitioned into `2`, `5`, `10`, `21`, `42`, `84`, `168`, `336`, and `672` partitions. The size per partition was calculated as the quotient of the size of the csv file and the number of partitions. By default `dask` uses partitions that are `64 MB` in size and such data-points have been marked as large circles with black borders. The top right plot shows that the time to find the unique entities in a column varies quadratically with the size of the paritions with a minima that itself increases slightly with the size of the dataframe. In other words, the best performance for a `1 GB` dataframe was obtained with a partiton size of `200 MB`, while that for a `25 GB` dataframe was obtained for partitions of size ~ `600 MB`. Similar trends are observed for the `groupby` operation as seen in the bottom right figure. Thus, modest improvements in computational performance can be obtained by shrinking the number of partitions such that the size of the partitions lie between `256 MB` and `1024 MB`. 

![alt text](./figures/Dask_groupby_timing_vs_partitions.png "dask what partitions") 
**Figure 8**: This figure plots the time require to complete the `unique()` and `groupby()` operations as a function of the size of the dataset where the dataframe was partitioned into `2`, `5`, `10`, `21`, `42`, `84`, `168`, `336`, and `672` partitions. Both plots indicate that the performance of the default partitioning is close to that where the number of partitions were fixed to `5` or roughly `1/16` the number of dask workers. Besides the case for `1 GB` datasets, both plots appear to show that the best performance can be obtained when the dataframes are partitioned to `21` (`1/4` as many dask workers) or `42` (`1/2` the total number of dask workers). 

### 1.4. Comparing all packages
![alt text](./figures/groupby_packages_comparison.png "Summary of Groupby")
**Figure 9**: Summary of durations for (left) loading a csv file, (center) calculate the number of unique values, and (right) groupby on a single column. Results from experiments that use the best ``blocksize``, ``chunksize`` and ``parititons`` parameters are used in the above plots. Overall, the multi-threaded, dask-counterparts of the single-threaded (CPU-only) pandas and (NVIDIA GPU) cudf packages are substantially faster at reading the single csv file. Note again that the dask and dask-cuda experiments used 2 full nodes of Summit

## 2. Scaling

### 2.1 Dask-cudf
![alt text](./figures/dask_cudf_scaling.png "Dask-cudf scaling")
**Figure 10**: These plots show the time required to (top left) load a `.csv` spreadsheet, (top right) perform a `unique()` operation,  (bottom left) perform a set of `groupby()` operations, and (bottom right) an indexed join operation on the dataframe as a function of both the size of the dataset and the number of GPUs (from `1` to `100`) using the `dask-cudf` package. The plot on the top-left shows that reading time does not vary significantly with the number of GPUs. In this case the `chunksize` was set to `1 GB` following findings reported above. This may explain the comparable read times for datasets that vary by little over 1 magnitude in size. The plot on the top-right shows a decrease in the time required to perform the `unique()` operation as more GPUs become available regardless of dataset size. However, for all dataframe sizes, a sudden jump in computational time is observed followed by plateuing of the compute time. This point of jump may be related to a drop in the number of partitions per GPU or data size per GPU below a threshold. The plot on the bottom-left shows exponentially decreasing time to perform a set of `groupby()` operations as the number of GPUs are increased. Eventually, the compute time reaches an asymptote for all dataset sizes.  Interestingly, the plot on the bottom-right shows that the time required for the indexed-join remains constant regardless of the number of GPUs available for computation. Furthermore, there is a marked jump in the compute time when the size of the dataframe was increased from `2.5 GB` to `5 GB`.

### 2.1 Dask
![alt text](./figures/dask_scaling.png "Dask-dataframe scaling")
**Figure 11**: These plots show the time required to (top left) load a `.csv` spreadsheet, (top right) perform a `unique()` operation,  (bottom left) perform a set of `groupby()` operations, and (bottom right) an indexed join operation on the dataframe as a function of both the size of the dataset and the number of CPU cores (from `1` to `100`) and corresponding memory using the `dask.dataframe` package. The figure on the top-left and top-right reveal a nearly-constant time required to read the spreadsheet file and to calculate the unique number of entities in a column. The plots on the bottom reveal an inverse exponential relationship between the time required to perform the groupby or indexed-join operation and the available number of CPU cores. 
