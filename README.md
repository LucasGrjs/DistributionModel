# Distribution Model

This document outlines the **DistributionModel** project, which contains proof-of-concept implementations and experiments for distribution models within the **GAMA Platform**.

---

## Requirements

To set up and run this project, you'll need the following:

* **Java 17**
* **mpirun (Open MPI) 4.1.4**: Download from [https://www.open-mpi.org/software/ompi/v4.1/](https://www.open-mpi.org/software/ompi/v4.1/)
* **Apache Maven 3.8.6**
* **Java Binding for Open MPI**: Refer to [https://www.open-mpi.org/faq/?category=java](https://www.open-mpi.org/faq/?category=java) for details.

---

## Compiling the Project

Follow these steps to compile the project:

1.  Navigate to the `gama` directory:
    ```bash
    cd gama
    ```
2.  Run the build script. This process might take some time:
    ```bash
    ./travis/build.sh
    ```
3.  Change to the `Distributed_Evacuation_Model` directory:
    ```bash
    cd ../Distributed_Evacuation_Model/
    ```

---

## Running the Thematic Model (for testing)

To start the Thematic Model for testing purposes, execute the following command:

```bash
./startHeadless ThematicModel/Continuous_Move.xml # Evacuation Model
 ```

## How to Start the Distribution Models

### KMEAN Model ------------------------------------------
For the **KMEAN Model**, the number of processors `M` must be greater than 2 and less than the total number of cores on your machine. You can find this limit using the UNIX command: `grep -m 1 'cpu cores' /proc/cpuinfo`.
To simulate the Evacuation Model using the KMEAN model, use this command:

```bash
./startMpiModel DistributionModel/Distribution_model_K-mean.xml M
```

### GRID Model ------------------------------------------
For the **GRID Model**, the number of processors `N` must be greater than 2 and less than the total number of cores on your machine. You can find this limit using the UNIX command: `grep -m 1 'cpu cores' /proc/cpuinfo`.

To adjust the number of cores used for the GRID Model, you'll need to modify two parameters within the model configuration:

* `int grid_width <- 1; // grid width in cells`
* `int grid_height <- 2; // grid height in cells`

The product of `grid_width` and `grid_height` should always equal the number of processors you intend to use.

**Example:** If you use 6 cores:
* `int grid_width <- 3;`
* `int grid_height <- 2;`
* `// 3 x 2 = 6`

Alternatively, this could also be:
* `int grid_width <- 1;`
* `int grid_height <- 3;`
* `// 1 x 6 = 6`

```bash
./startMpiModel DistributionModel/Distribution_model_grid.xml N      # Simulate the Evacuation Model using the GRID model
```

---
### Results

All results from these simulations will be located in the `Distributed_Evacuation_Model/output.log/` directory after the model execution. Specifically, `/output.log/snapshot/` will contain the snapshots of the simulation from each **Processor**.
