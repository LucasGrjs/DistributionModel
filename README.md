# DistributionModel

Proof of concepts for distribution model

# Requirements  
Java 17

mpirun (Open MPI) 4.1.4 (https://www.open-mpi.org/software/ompi/v4.1/)

Java Binding for Open MPI (https://www.open-mpi.org/faq/?category=java)

# How to start examples : N > 2 and < 6*  (* the limit is the number of core on your machine)

./startMpiModel distributed_comodel/Distribution_model_KMEAN.xml N

./startMpiModel distributed_comodel/Distribution_model_GRID.xml 4

# Results 

All the results of these examples can be found in /output.log after the execution of above model.
/output.log/1/N/stdout will contains the logs of Processor N
/output.log/snapshot/N/ will contain the snapshot of the simualtion on Processor N
