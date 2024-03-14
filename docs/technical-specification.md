# Technical specification

## Introduction

Nima is an agent based modeling framework for cluster computing written in nim.

Designing a new framework has to strike a balance between performance and ease-of-use. In this regard Nima is built to make it easier for simulation engineers to test ideas at scale. These engineers are not expected to have a HPC support staff or a devops team to setup RDMA, VPNs, ELK-stack for analysis, so nima is built with the initial assumption that additional system administration overhead is problematic or at best a distraction.

## Comparison

Comparison of key differences between Nima approach and traditional MPI-based HPC systems, highlighting the simplicity and flexibility of Nima method while acknowledging the strengths of MPI HPC:

| Feature | Nima | MPI HPC |
|---------|---------------|---------|
| **Communication** | Uses WebSockets for flexible, web-friendly communication. | Employs MPI for highly optimized, low-latency inter-process communication. |
| **Deployment** | Direct process management across known hosts, minimizing overhead and complexity. | Often requires specialized HPC infrastructure and configurations for optimal performance. |
| **Security** | Simplified security model, with direct control over process isolation and network access. | May require complex configurations for secure communication, especially in shared or public networks. |
| **Scalability** | Designed to scale across diverse environments, including cloud and mixed-compute resources. | Best scalability within dedicated HPC clusters with specialized networking hardware. |
| **Fault Tolerance** | Built-in mechanisms for error handling and recovery, focusing on robustness. | Limited built-in fault tolerance, often reliant on external tools for checkpoint/restart capabilities. |
| **Simplicity** | Emphasizes minimal cognitive load with a focus on doing one thing well. | Can be complex to set up and manage, requiring deep knowledge of parallel computing concepts. |
| **Flexibility** | Offers a flexible architecture, easily adapted to various computational tasks and environments. | Highly specialized for parallel computing tasks, with less flexibility outside traditional HPC applications. |
| **Tooling** | Leverages common tools and protocols for ease of use and accessibility. | May require specialized tools and libraries specific to HPC environments. |
| **Performance** | Optimizes for a balance between performance and simplicity, adequate for a wide range of applications. | Optimizes for maximum performance in compute-intensive tasks, possibly at the cost of higher complexity. |

This table is designed to present a balanced view, recognizing the strengths of both approaches while highlighting the benefits of simplicity and ease of use in your design. It's important to choose the approach that best aligns with the specific needs and constraints of each project, whether those prioritize the utmost in performance (as with MPI HPC) or favor simplicity, flexibility, and broader accessibility (as with Nima).

## Design Objectives

Nima seeks to reduce cognitive load, making systems easier to understand, troubleshoot, and maintain, especially important in complex environments like distributed simulations or high-performance computing.

Nima's objectives are therefore:

- ease of use with millions of agents (actor model).
- decoupled, scalable and lock-free.
- light-weight extendible modular plug-in architecture.
- commodity hardware.
- full parallelism and concurrency
- shared memory
- thread safety
- locality & NUMA aware threads.
- automated load balancing
- linux only.
- safe and operationally isolated using cgroups and namespaces. 
- lightweight real-time monitoring, like top or htop
- detailed logging disregard both for crashes and successful runs.

## Workflow

Before talking about workflow a few concepts must be declared:

|Name|Description|
|:---|:---|
|Central Authority (CA)|The control node from where the distributed system is managed. |
|Node|A machine registered with the CA|
|Dispatcher| A time-aware message brooker |
|Thread| A nim subprocess that updates agents |

### Getting started.

Nima expects as a minimum a 4 logical cores, but can run with up to 1M compute nodes. 


### 1. SSH
The user must connect to all workers using SSH so that known hosts is up-to-date. Root access is not required as memory limits and namespace isolation is achieved through linux kernel virtualization such as cgroups and namespaces.

### 2. cluster.cfg
The user creates a file `cluster.cfg` with the known hosts to be included in the cluster and a network topology of the cluster. The default topology is a tree where CA connects to all Nodes but nothing more.
The default communication pattern is to send non-local messages upstream for reassignment, however if two or more nodes could benefit from direct communication, adding these edges to the `cfg`-topology will offload work for the CA.

### 3. launch processes
Nima runs through the `cluster.cfg` and performs an analysis on each `Node`:

If nodes architecture has Non-uniform memory access (NUMA), the logical cores are mapped such that local and remote memory access is determined.

For each NUMA-region, a `dispatcher` is launched. For each logical core in each numa region, a `thread` is launched. During operation `thread`s will only send messages to their local dispatcher, whilst inter-regional messaging is handled by `dispatchers`.

Each dispatcher also connects to the CA (and all other nodes according to the topology) using websockets.

Example:
```yaml
Node1: 96 core AMD Threadripper with 468 Gb RAM.
  Central Authority: Yes.
  4 NUMA regions:
    4 dispatchers with 23 worker threads each.
Node2: 96 core AMD Threadripper with 468 Gb RAM.
  Central Authority: No.
  4 NUMA regions:
    4 dispatchers with 23 worker threads each. 
```

Threads are pinned to specific cores.


### 4. ready to do work

After launch, the threads in each NUMA-region will be waiting for work.

Work is triggered by messages that are stored in shared memory.

The role of the dispatcher is to give work (messages) to threads that then update the agents.

- From the perspective of each agent, the thread will read a message and update the agent.
- From the threads perspective a message arrives as a pointer to shared memory which the thread will read and process.
- From the dispatchers perspective a pointer to memory was given by a thread (indicating the thread was done and has created a new message). If the message is local, the dispatcher will forward the pointer to an idle thread. If the message is to a remote agent, the message will be sent to the remote agents dispatcher.

It is important to note that locks are not needed as the dispatcher GIVES the batch of messages for each agent to the thread. Agent updates are thereby atomic and threadsafe.

If you seek to speed an agent up by doing parallel processing within the memory space of the agent, the correct design is to break the agent into sub-agents and let the super-agent act as a messaging gateway.

### 5. run!

The simulation is coordinated using a clock, in the following way:

The time is set by the CA and communicated using Websockets (`ws`) to all dispatchers as a **global timestamp**. 
The dispatcher releases all messages to threads for locally queued messages up to the global timestamp.

Whilst messages are being processed by the threads, time does not advance. Once all messages have been exchanged and the message queue is empty, the dispatcher sends the first timestamp where it can continue its work via `ws` as **next event time** (NET-signal).

When the CA has received NET-signals from all dispatchers, it responds by sending the smallest NET-signal to all dispatchers. The dispatchers will then update their local clock to the NET-signal value. This assures that the time advances without jitter and that time stands still during messages exchange for both local agents, inter-node and inter-NUMA-messages. 
It also guarantees that a dispatcher that may have been waiting for a later event, can be updated to an earlier event if the messages it receives (whilst idle) may influence this.

Whilst dispatchers are idle, they write logs to local NVMe's. This has few benefits:
- fewer IO operations by centralizing them with the dispatcher than if agents logged individually.
- a dispatcher that is very buzy isn't slowed down as it only writes logs locally when idle.
- by avoiding real-time transmission of logs network and I/O overhead is minimized during the simulation, allowing the system to focus resources on computation and synchronization.
- Storing logs locally on NVMe drives leverages their high throughput and low latency, making this approach scalable with the volume of logs and the number of nodes in the simulation.

This strategy effectively minimizes the performance impact during the simulation's critical runtime. 

### Stopping

Nima stops the entire simulation upon any agent raising an exception. First because this is a straightforward approach to error handling that prioritizes consistency. While this makes the system more sensitive to individual failures, it simplifies the error handling logic.

As the clean-up process after the simulation automatically gathers the logs, detailed post-mortem analysis is easy to perform.

The CA process enables a set of signals for the user:

- stop (sim)
- pause (sim)
- checkpoint (sim)
- move agent `mv /virtual/path/to/agent /new/virtual/path`
- collect (logs)
- CTRL+C automatically kills the cluster.

### Monitoring

As the CA has very little work, during the simulation, it handles real-time monitoring similar to `top` or `htop`, where the  absolute minimum of information is transfered using the existing websockets.  

(built using `Rich`)

The CA is listening for real-time log messages, with the default granularity of 1%. This means that if the CPU load, RAM usage, network bandwith, disk I/O or disk usage has not changed more than 1%, no message is sent from the dispatchers.


### Load balancing

If the statistics on the CA reveal that a dispatcher is slower than others, the CA can instruct the dispatcher to offload agents to other dispatchers. The CA does this by monitoring the latency from a NET-signal is given until the NET-signal is confirmed. Although the CA will try to load balance, the `cfg` file can disable this, if the user is confident about how to partition the agents (also registered in the `cfg` file). 

The benefit of letting the CA dictate what is launched where simplifies deployment and simultanously eliminates the need for dynamic service discovery.


### Logs

Disregarding whether the simulation raised an exception or ran to completion, the logs will be assembled by the central authority as a cleanup process.

Further more if any node reaches more than 95% memory utilization (default) the logs are immediately dumped to disk.

To minimize the network traffic, logs are compressed before the cleanup transfer to the CA node.

For analysis of the logs I recommend using DuckDB with csv-import of the following reasons: DuckDB for log analysis offers a lightweight, efficient, and user-friendly alternative to more complex solutions like the ELK stack. 

- **Simplicity and Ease of Use**: DuckDB is designed to be an easy-to-deploy, OLAP (online analytical processing) database system. It requires minimal configuration, making it accessible for users with varying levels of system administration expertise.
- **Efficient Data Analysis**: DuckDB supports SQL queries for data analysis, allowing you to leverage familiar SQL syntax to perform complex analyses on your log data efficiently. Its columnar storage model is optimized for analytical queries, making it fast and suitable for log analysis.
- **Integration with Data Science Tools**: DuckDB can integrate with popular data science tools and languages, such as Python and R, facilitating advanced data analysis and visualization directly from the log data.


## How to build the simulation

The user only needs to worry about the design of the agents Nima takes care of:

- parallelism using `threads` and `async/await`
- thread safety without the need for locks or atomics.
- load balancing as agents that communicate a lot are colocated. This results in CPU cache coherence, which significantly increases performance.
- memory management, where nim is compiled with `--gc:orc` or `--gc:arc` for more deterministic memory management.
- message passing is done in a non-blocking manner using `channels` on the same node or using `ws` between nodes. 
- serialization of messages.

Things you may want to look into are:

- **Compile-time Optimizations**: Use Nim's compile-time features, like templates and macros, to generate optimized code for repetitive tasks.

- **Profiling**: Use profiling tools to identify bottlenecks. Nim's built-in profiler (`--profiler:on` and `--stackTrace:on`) can help, but also consider system-level tools like `perf` on Linux.


### Practical Steps:

1. **Prototype**: Start with a small prototype that uses a subset of your cores and memory. This allows you to iron out issues without dealing with the full complexity of your target setup.

2. **Incrementally Scale**: Gradually increase the load, both in terms of CPU utilization and memory usage, while monitoring performance and bottlenecks.

3. **Optimization**: Apply specific optimizations based on profiling results. This might include algorithmic changes, memory layout adjustments, or concurrency model tweaks.

4. **Testing and Validation**: Ensure that your simulation's results are accurate and reliable across different scales of operation. Implement comprehensive testing to catch synchronization issues or memory corruption early.

This approach requires a deep understanding of Nim's capabilities, a careful design that considers parallel execution from the ground up, and an iterative process of development, testing, and optimization.