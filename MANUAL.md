# MANUAL FOR USAGE ON PALMA II

This manual shall provide an overview on how to use the cosmic string simulation by Ken Olum. Similar to the [README](README), this manual will provide a step-by-step guide on how to run the simulation on PALMA II in Münster. 

There are two ways to run the software. Firstly, one can run it natively on the system using the local SBCL compiler. This is currently the only way to run the software using the manager-workers pattern. Secondly, one can run the software using Singularity, though this does currently break the communication between workers and manager. However, this should be possible in principle. 


## Simulation structure

The simulation is based on a "semi-parallel" computing technique that is explained in detail in the following publication: https://arxiv.org/pdf/1011.4046. 


## Running the simulation natively

This is recommended if a common lisp compiler such as [Steel Bank Common Lisp](https://www.sbcl.org/) or short SBCL is installed on the system. On PALMA II, this is available as a module that can be loaded when executing the simulation. 

### Step 1: Load the necessary modules

To load the necessary modules execute 
```
module load palma/2022a GCCcore/11.3.0 SBCL/2.3.11 GCC/11.3.0 GSL/2.7
```

Using the SBCL installation, one can install quicklisp. which is a library manager for common lisp (see https://www.quicklisp.org/). To get it, download the file https://beta.quicklisp.org/quicklisp.lisp into your home directory.  Then execute sbcl and enter the command `(load "~/quicklisp")` followed by `(quicklisp-quickstart:install)`.  Each user of this package has to do this, but only once each.

### Step 2: Modifying source code for cluster specifics

To run the simulation, some changes need to be made in the program's source code. The following changes are necessary:

In the file [definitions.lisp](definitions.lisp) add a condition to the `server` parameter: 
```lisp
(defparameter server
  (let ((name (machine-instance)))
    (cond 
     ...
      ((search ".palma.wwu" name) :palma)
	 ...
```
The `:palma` keyword is used to identify the server as a PALMA II node. The identification is used multiple times in the source code to adjust the simulation to the cluster specifics.

To set the sbcl executable: 
```lisp
(defvar lisp-program
    (ecase server
        ...
        (:palma "sbcl")))
```
To set the root directory from which the simulation shall build all directories for output and metadata: 
```lisp
(defparameter batch-root-directory
    (ecase server
        ((:palma (format nil "/scratch/tmp/~A/" (get-current-username))))
```

Similar with the local root directory in [submit.lisp](submit.lisp): 
```lisp
(defparameter local-root-directory
    (ecase server
        ((:palma (format nil "/scratch/tmp/~A/" (get-current-username))))
```
Further, add an entry to the do-submit function
```lisp
(defun do-submit (&rest arguments)
  (apply (ecase server
       ...
	   (:palma #'slurm-submit)
       ...
	  arguments))
```

To see the full diff of the changes, see https://github.com/kdolum/cosmic-string-simulation/compare/main...richeldichel:cosmic-string-simulation:main. Note that probably not all changes here are necessary, but this is the full diff of the changes I made.


### Step 3: Running the simulation

To start the program, execute the following command from within the source code directory: 
```
(load "load.lisp")
```
This compiles and loads the source code. After that, any command can be executed. To use the manager-workers pattern, execute the following command: 
```
(manager "test" t 70 '(do-vv :size 100.0 :log t :split-factor 5))
```
Here, the manager function is executed, which takes some arguments:

- First is the directory to keep the temporary files and write the output.
It is relative to variable batch-root-directory. After the first time you also need the option :OVERWRITE T, or it will complain that that output file already
exists.

- Second is the duration of the run in internal time. The units are roughly units of the initial string spacing.  The symbol T means to
default the time from the size of the run.

- Third is the maximum number of worker processes to allow at once.

- Last comes the (quoted) form that is to be evaluated in each worker. Here, the Vachaspati-Vilenkin initial conditions are used. The function is defined in (test.lisp)[test.lisp]. It will be amended with a :job-number argument to say which job the worker is to do. This form can also be executed as a single process without the need of a manager. 
    - The SIZE argument to DO-VV gives the size of the box (really the minimum distance between identifying points under periodic boundary conditions, because the box is not rectangular).  SPLIT-FACTOR gives the factor by which to divide the size in each linear direction to split up the entire work into jobs. Thus in this case there will be 125 workers in each layer. (See figure 1, 2 and 3 in https://arxiv.org/pdf/1011.4046)
    - There are many other possible arguments to DO-VV.  They are defined by the forms DEFINE-SIMULATE-ARGUMENT and DEFINE-SIMULATE-VARIABLE, which you can look for in the source.  In the example above, LOG means to write a log of loops that were created.

The simulation will run until all the workers are done. The output will be written to the specified directory.

### Step 4: Plotting the data

There are many functions available to organize and plot the data. The plotting functions are defined in [plot.lisp](plot.lisp). To do a simple plot one can execute the following commands: 
```lisp
(bin-loops-files "directory")
(loops-graph "directory")
``` 

## Running the simulation using Singularity

To run a program using the Singularity implementation Apptainer one just needs to load the Apptainer module. 
```
module load Apptainer
```

To run the simulation using Singularity, one can use the provided Singularity container definition [Apptainer.def](Apptainer.def). The singularity file needs to be built on an external system with root access.
```
apptainer build cosmic-string-simulation.sif Apptainer.def
``` 
The container can then be copied to PALMA II and executed using 
```
apptainer run --writable-tmpfs --hostname Container \
-B /usr/lib64/libreadline.so.6,/usr/lib64/libhistory.so.6,/usr/lib64/libtinfo.so.5,\
/var/run/munge,/usr/lib64/libmunge.so.2,/usr/lib64/libmunge.so.2.0.0,/run/munge,\
/etc/munge,/usr/lib64/slurm/,/etc/slurm,/usr/bin/sinfo,/usr/bin/squeue,/usr/bin/sbatch,\
/usr/bin/srun,/usr/bin/salloc --bind /scratch/tmp/r_salo04/simulations/:/mnt \
cosmic-string-simulation.sif
```
This rather lengthy command binds the necessary slurm directories to the container. This way, the container can interact with the slurm scheduler. Furthermore, the output directory is bound to the container. Make sure that you modify the output directory to your needs.

After that, a bash session is available inside the container, where the commands from step 3 and 4 can be executed. 

As in the previous section, the source code needs to be modified in parts to account for the new file structure. The changes follow the same pattern as in the previous section. 

### Problems with the container

Currently, the container does not work as intended due to the submitted workers not being able to communicate with the manager. I suspect that this is due to the way the workers are started, but I have not been able to fix this issue. I used the following site as a source https://info.gwdg.de/wiki/doku.php?id=wiki:hpc:usage_of_slurm_within_a_singularity_container.  

Since the workers are started in a separate process, one needs to modify the start command. This is done in the `slurm-submit` function in [submit.lisp](submit.lisp), where I added a case for the container that starts the workers using the above command. This approach probably needs some further adjustments. I can see that the workers are started and produce output, however, they are idling until being shutdown. 