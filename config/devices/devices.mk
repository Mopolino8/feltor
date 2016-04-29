ifeq ($(strip $(device)),gpu)
CC = nvcc
OPT=-O2
CFLAGS+= --compiler-options -Wall $(NVCCARCH)
CFLAGS+= -Xcompiler $(OMPFLAG)
CFLAGS+= -DTHRUST_HOST_SYSTEM=THRUST_HOST_SYSTEM_OMP
#CFLAGS+= -DCUSP_DEVICE_BLAS_SYSTEM=CUSP_DEVICE_BLAS_CUBLAS -lcublas
#CFLAGS+= -DCUSP_USE_TEXTURE_MEMORY
backend_:=$(MPICC)
MPICC=nvcc --compiler-bindir $(backend_)
MPICFLAGS+= -DTHRUST_DEVICE_SYSTEM=THRUST_DEVICE_SYSTEM_CUDA
MPICFLAGS+= --compiler-options -Wall $(NVCCARCH)
MPICFLAGS+= --compiler-options $(OPT)
else # if device = cpu
CFLAGS+=-Wall -x c++
CFLAGS+= -DTHRUST_DEVICE_SYSTEM=THRUST_DEVICE_SYSTEM_OMP
MPICFLAGS+=$(CFLAGS) #includes values in CFLAGS defined later
endif
ifeq ($(strip $(device)),omp)
CFLAGS+= $(OMPFLAG) 
endif
ifeq ($(strip $(device)),mic)
CFLAGS+= $(OMPFLAG) -mmic 
endif