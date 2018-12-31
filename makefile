NVCC = /usr/local/cuda-8.0/bin/nvcc
CC = g++
GENCODE_FLAGS = -arch=sm_30
CC_FLAGS = -c 
NVCCFLAGS = -m64 -O3 -Xptxas -O3,-v
#uncomment NVCCFLAGS below and comment out above, if you want to use cuda-gdb
#NVCCFLAGS = -g -G -m64 --compiler-options -Wall
OBJS = classify.o wrappers.o h_classify.o
.SUFFIXES: .cu .o .h 
.cu.o:
	$(NVCC) $(CC_FLAGS) $(NVCCFLAGS) $(GENCODE_FLAGS) $< -o $@

all: classify1 classify2 classify3 classify4

classify1: $(OBJS) d_classify1.o
	$(CC) $(OBJS) d_classify1.o -L/usr/local/cuda/lib64 -lcuda -lcudart -o classify1

classify2: $(OBJS) d_classify2.o
	$(CC) $(OBJS) d_classify2.o -L/usr/local/cuda/lib64 -lcuda -lcudart -o classify2

classify3: $(OBJS) d_classify3.o
	$(CC) $(OBJS) d_classify3.o -L/usr/local/cuda/lib64 -lcuda -lcudart -o classify3

classify4: $(OBJS) d_classify4.o
	$(CC) $(OBJS) d_classify4.o -L/usr/local/cuda/lib64 -lcuda -lcudart -o classify4

classify.o: classify.cu wrappers.h h_classify.h d_classify.h config.h histogram.h models.h

h_classify.o: h_classify.cu h_classify.h CHECK.h config.h histogram.h

d_classify1.o: d_classify1.cu d_classify.h CHECK.h config.h histogram.h

d_classify2.o: d_classify2.cu d_classify.h CHECK.h config.h histogram.h

d_classify3.o: d_classify3.cu d_classify.h CHECK.h config.h histogram.h

d_classify4.o: d_classify4.cu d_classify.h CHECK.h config.h histogram.h

wrappers.o: wrappers.cu wrappers.h

clean:
	rm classify1 classify2 classify3 classify4 *.o
