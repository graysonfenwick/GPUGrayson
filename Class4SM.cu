#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <cuda_runtime.h>
#include "config.h"
#include "histogram.h"
#include "d_classify.h"
#include "CHECK.h"
#include "wrappers.h"

//Our CUDA machine has compute capability 6.1
//These are the number of memory banks of a machine with that capability
//according to the Nvidia documentation
#define NUM_BANKS 32
#define LOG_NUM_BANKS 5
#define CONFLICT_FREE_OFFSET(n) ((n) >> LOG_NUM_BANKS)
#define CLASSBLOCKDIM 512
//shared memory size needs to be twice CLASSBLOCKDIM + one integer for
//every 32 integers
#define SHAREDMEMSIZE ((CLASSBLOCKDIM << 1) + ((CLASSBLOCKDIM << 1) >> LOG_NUM_BANKS))  
static __device__ void bankBelloch(float *histogram, int *histSz);

//parameters for building the histogram from the image
//TILEWIDTH is number of pixels in a row that a single thread will handle
#define TILEWIDTH 8 
#define HISTBLOCKDIM 32

//prototypes for functions local to this file
static float histogramOnGPU(histogramT *, unsigned char *, int, int, int);
static float classifyOnGPU(float *, int *, int modelCt);
static void normalizeHost(float *, int *);
//prototypes for the kernels
static __global__ void d_histoKernel(histogramT *, unsigned char *, int, int, int);
static __global__ void d_classifyKernel(float *, float *, int *);
static __global__ void emptyKernel();

//prototypes of functions called by d_classifyKernel

static __device__ void normalizeHist(float *, int);
static __device__ void intersection(float * normHistograms, float * intersect);

//for debugging
static __device__ void printFloatArray(float * array, int startIdx, int length);
__device__ void printIntArray(int * data, int length, const char * label);

/*
    d_classify
    Performs image classification on the GPU by first building a histogram
    to represent the image and then comparing the histogram to each of the
    histogram models.

    Outputs:
    Phisto - pointer to histogramT struct containing the bins 
    dresult - comparisonT array of structs; one element per model

    Inputs:
    models - an array of pointers to histogramT structs; one element per
             model to be compared to the input
    Pin - array contains the color pixels of the image to be used for 
          building a histogram and doing the classification
    width and height - dimensions of the image
    pitch - size of each row
 
    Returns the amount of time it takes to build the histogram and
      classify the image
*/
float d_classify(histogramT * Phisto, comparisonT * dresult, 
                 histogramT ** models, int modelCt, unsigned char * Pin,
                 int height, int width, int pitch) 
{
    float gpuMsecTime1, gpuMsecTime2;

    //launch an empty kernel to get more accurate timing
    emptyKernel<<<1024, 1024>>>();

    //build a histogram of the input image
    gpuMsecTime1 = histogramOnGPU(Phisto, Pin, height, width, pitch);

    //allocate array to hold all histograms, including the histogram for the input
    int * histograms = (int *) Malloc(sizeof(int) * (modelCt + 1) * TOTALBINS);

    //copy the histogram for the input to the beginning of the array
    memcpy(histograms, Phisto->histogram, sizeof(int) * TOTALBINS);

    //copy the remaining histograms
    for (int i = 1; i <= modelCt; i++) 
        memcpy(&histograms[i*TOTALBINS], models[i - 1]->histogram, sizeof(int) * TOTALBINS);

    //allocate an array of floats to hold the comparisons
    float * comparisons = (float *) Malloc(sizeof(int) * modelCt);

    //perform the classification
    gpuMsecTime2 = classifyOnGPU(comparisons, histograms, modelCt);

    //copy the results into the output
    for (int i = 0; i < modelCt; i++)
    {
        dresult[i].comparison = comparisons[i];
        strncpy(dresult[i].fileName, models[i]->fileName, NAMELEN);
    }

    return gpuMsecTime1 + gpuMsecTime2;
}

/*
   histogramOnGPU
   Builds a histogram to represent the input image.

   Outputs:
   Phisto - pointer to the histogramT struct containing the bins

   Inputs:
   Pin - array contains the color pixels of the image to be used for 
         building a histogram
   width and height -  dimensions of the image
   pitch - size of each row
 
   Returns the amount of time it takes to build the histogram 
*/
float histogramOnGPU(histogramT * Phisto, unsigned char * Pin, int height, 
                     int width, int pitch)
{
    //THIS CODE IS COMPLETE

    cudaEvent_t start_gpu, stop_gpu;
    float gpuMsecTime = -1;
    
    //Use cuda functions to do the timing 
    //create event objects
    CHECK(cudaEventCreate(&start_gpu));
    CHECK(cudaEventCreate(&stop_gpu));

    unsigned char * d_Pin;
    int numPinBytes = sizeof(unsigned char) * pitch * height * CHANNELS;
    histogramT * d_Phisto;
    
    //create the array on the GPU to hold input
    CHECK(cudaMalloc((void **)&d_Pin, numPinBytes));
    CHECK(cudaMemcpy(d_Pin, Pin, numPinBytes, cudaMemcpyHostToDevice));

    //create the array on the GPU to hold the histogram
    CHECK(cudaMalloc((void **)&d_Phisto, sizeof(histogramT)));
    CHECK(cudaMemcpy(d_Phisto, Phisto, sizeof(histogramT),
          cudaMemcpyHostToDevice));
    
    //build the histogram
    CHECK(cudaEventRecord(start_gpu));

    //each thread calculates TILEWIDTH elements in a row
    dim3 grid(ceil(width/(float)(HISTBLOCKDIM * TILEWIDTH)),
              ceil(height/(float)HISTBLOCKDIM), 1);
    dim3 block(HISTBLOCKDIM, HISTBLOCKDIM, 1);

    d_histoKernel<<<grid, block>>>(d_Phisto, d_Pin, height, width, pitch);

    CHECK(cudaEventRecord(stop_gpu));
    CHECK(cudaMemcpy(Phisto, d_Phisto, sizeof(histogramT),
          cudaMemcpyDeviceToHost));
    //record the ending time and wait for event to complete
    CHECK(cudaEventSynchronize(stop_gpu));
    //calculate the elapsed time between the two events 
    CHECK(cudaEventElapsedTime(&gpuMsecTime, start_gpu, stop_gpu));

    return gpuMsecTime;
}

/*
   d_histoKernel
   Kernel code executed by each thread on its own data when the kernel is
   launched. Each thread operates on TILEWIDTH pixels in a row.

   Inputs:
   Pin - array contains the color pixels to be used to build the histogram
   width and height - dimensions of the image
   pitch - size of each row

   Output:
   histo - pointer to a histogramT struct that contains an array of bins
*/
__global__
void d_histoKernel(histogramT * histo, unsigned char * Pin, int height,
                  int width, int pitch)
{
    //THIS CODE IS COMPLETE.  You can replace it with a faster version
    //if you like, but the shared memory version won't work with all
    //TOTALBINS sizes.  If you use that one, the largest BIN value can
    //only be 8.

    int colStart = (blockIdx.x * blockDim.x + threadIdx.x) * TILEWIDTH;
    int row = blockIdx.y * blockDim.y + threadIdx.y;
    int col;

    //use a privatization technique to reduce the number of atomic adds
    int accumulator = 0;
    int prevBin = -1;
    int currBin;

    //go through each pixel in the tile
    for (int i = 0; i < TILEWIDTH; i++)
    {
        col = colStart + i;
        if (row < height && col < width)
        {
            //flatten the 2D indices
            int pIndx = row * CHANNELS * pitch + col * CHANNELS;

            unsigned char redVal = Pin[pIndx];
            unsigned char greenVal = Pin[pIndx + 1];
            unsigned char blueVal = Pin[pIndx + 2];
            currBin = (redVal/TONESPB)*BINS*BINS + (blueVal/TONESPB)*BINS
                       + greenVal/TONESPB;
            if (currBin != prevBin)
            {
                if (accumulator > 0) 
                    atomicAdd(&(histo->histogram[prevBin]), accumulator); 
                prevBin = currBin;
                accumulator = 1;
            } else accumulator++;
        }
    }
    if (accumulator > 0)
    {
        atomicAdd(&(histo->histogram[prevBin]), accumulator); 
    }
}

/*
    classifyOnGPU
    Performs image classification on the GPU

    Outputs:
    comparisons - an array of size modelCt. comparisons[i] is set to the
                  result of comparing the input image to model i
                  The size of this array is modelCt.

    Inputs:
    histograms - an array of histograms. 
        The histogram for the input image is in:
        histograms[0] ... histogram[TOTALBINS - 1]
        The histogram for model 0 is in:
        histograms[TOTALBINS] ... histogram[2*TOTALBINS - 1]

        The histogram for the last model is in:
        histograms[modelCt*TOTALBINS] ... histogram[modelCt*TOTALBINS - 1]
        Thus, note that the array contains the input histogram and the
        model histograms and thus is of size (modelCt + 1) * TOTALBINS
   
    modelCt - count of the number of models used for the classification 
 
    Returns the amount of time it takes to classify the image
*/
float classifyOnGPU(float * comparisons, int * histograms, int modelCt)
{
    cudaEvent_t start_gpu, stop_gpu;
    float gpuMsecTime = -1;

    //allocate an float array on the GPU to hold the normalized histograms
    //It needs to be big enough to hold the histogram of the input image and
    //and the histograms of all of the models.
    float * dNormHistograms;
    float * normHistograms = (float *) Malloc(sizeof(float) * (modelCt + 1) * TOTALBINS);
    CHECK(cudaMalloc((void **)&dNormHistograms, sizeof(float) * TOTALBINS * (modelCt + 1)));

    int * dhistograms;

    normalizeHost(normHistograms, histograms);
    //allocate an int array on the GPU to hold the original histograms
    //It needs to be big enough to hold the histogram of the input image and
    //and the histograms of all of the models.
    CHECK(cudaMalloc((void **)&dhistograms, sizeof(int) * TOTALBINS * (modelCt + 1)));

    //copy input histograms into dhistograms
    CHECK(cudaMemcpy(dhistograms, histograms, sizeof(int) * TOTALBINS * (modelCt + 1),
          cudaMemcpyHostToDevice));
    CHECK(cudaMemcpy(dNormHistograms, normHistograms, sizeof(float) * TOTALBINS * (modelCt + 1),
          cudaMemcpyHostToDevice));
 
    float * dcomparisons;
    //allocate a float array on the GPU to hold the comparisons
    //there needs to be one element per model
    CHECK(cudaMalloc((void **)&dcomparisons, sizeof(float) * modelCt ));
    
    //Use cuda functions to do the timing 
    //create event objects
    CHECK(cudaEventCreate(&start_gpu));
    CHECK(cudaEventCreate(&stop_gpu));

    //record the starting time
    CHECK(cudaEventRecord(start_gpu));

    //each model is handled by a single block of threads
    //an extra block of threads is needed to normalize the input histogram
    dim3 grid(modelCt + 1, 1, 1);
    //don't make block any larger than the number of bins
    dim3 block(min(TOTALBINS, CLASSBLOCKDIM), 1);
    //dim3 block(1024, 1);
    d_classifyKernel<<<grid, block>>>(dcomparisons, dNormHistograms, dhistograms);

    CHECK(cudaEventRecord(stop_gpu));

    //copy the device comparison array into the host comparison array
    CHECK(cudaMemcpy(comparisons, dcomparisons, sizeof(float) * modelCt,
          cudaMemcpyDeviceToHost));

    //record the ending time and wait for event to complete
    CHECK(cudaEventSynchronize(stop_gpu));
    //calculate the elapsed time between the two events 
    CHECK(cudaEventElapsedTime(&gpuMsecTime, start_gpu, stop_gpu));

    return gpuMsecTime;
}
void normalizeHost(float * normHist, int * hist) {
    int i;
    int sum = 0;
    for (i = 0; i < TOTALBINS; i++) {
        sum += hist[i];
    }
    for (i = 0; i < TOTALBINS; i++) {
        normHist[i] = (hist[i]/(float)sum) * NORMMAX;
    }
}

/*
    d_classifyKernel
    Kernel used to do the image classification on the GPU.  Each block of
    threads normalizes a single histogram. After that, every block except
    for block 0 will perform the intersection and store a
    result in the comparisons array.
    Thus, each block (except for 0) produces one result for the comparisons
    array.  Each thread in a block handles TOTALBINS/blockDim.x elements
 
    Inputs: 
    histograms - array of size gridDim.x * TOTALBINS. It contains
                 gridDim.x histograms each of size TOTALBINS.  The first one 
                 is the input histogram.
    Outputs:
    comparisons - comparison[i] is set to the value of the comparison of the
                  input histogram and the histogram of model i; for example,
                  comparison[0] is set to comparison of the input and model 0.
    normHistograms - array of size gridDim.x * TOTALBINS.  It contains
                     gridDim.x histograms that are equal to the normalization
                     of the input histograms.
*/

__device__ int blockSync = 0;   //need this to provide synchronization among blocks
__global__ void d_classifyKernel(float * comparisons, float * normHistograms, int * histograms) 
{
    __shared__ float sNormHistograms[TOTALBINS * 2];
    __shared__ int histSz;
    __shared__ float intersect;

    //thread 0 in the block should initialize histSz and intersect to 0
    if (threadIdx.x == 0)
    {
       intersect = 0;
       histSz = 0;
    }
    __syncthreads();

    int idx;
    int * x = &histograms[TOTALBINS * (blockIdx.x + 1)];
    for (idx = threadIdx.x; idx < TOTALBINS; idx += blockDim.x) {
        sNormHistograms[idx] = normHistograms[idx];
        sNormHistograms[idx + TOTALBINS] = x[idx];
    }
    
    int prevSz;
    int i = 0;
    int bins = TOTALBINS;
    int factor = 2;   //each thread handles 2 elements in the bankBelloch
    while (bins > 0)
    {  
       bankBelloch(&sNormHistograms[TOTALBINS + i * blockDim.x * factor], 
                   &prevSz);
       __syncthreads();
       if (threadIdx.x == 0) 
       {
          histSz = histSz + prevSz;
       }
       bins -= (blockDim.x * factor);
       i+=1;
       __syncthreads();
    }
    //normalize the histogram 
    normalizeHist(sNormHistograms, histSz);
    __syncthreads();

    intersection(sNormHistograms, &intersect);
    __syncthreads();
    if (threadIdx.x == 0) 
    { 
        comparisons[blockIdx.x] = intersect/NORMMAX;
    }
}



/* 
   intersection
   Calculates the intersection of the input histogram and a model histogram
   after they have been normalized.
   The input histogram is in normHistograms[0] ... normHistograms[TOTALBINS - 1]
   The model histogram is in normHistograms[TOTALBINS * blockIdx.x] ...
   normHistograms[TOTALBINS * blockIdx.x - 1]

Inputs:
normHistograms - array of TOTALBINS * gridDim.x bins (gridDim.x histograms)
intersect - pointer to the shared intersect value

Outputs:
shared intersect variable is incremented by the intersection calculated by the
thread running this code 
 */
__device__ void intersection(float * normHistograms, float * intersect)
{
    float * normHistogramTile = &normHistograms[TOTALBINS];
    int tdx = threadIdx.x;
    while (tdx < TOTALBINS)
    {
        float minTwo = fmin(normHistogramTile[tdx], normHistograms[tdx]);
        atomicAdd(intersect, minTwo);
        tdx += blockDim.x;
    }
}

__device__ void printIntArray(int * data, int length, const char * label)

{
    long i, j = 0;
    printf("%s\n", label);
    for (i = 0; i < length; i++, j++)
    {
        if ((j % 10) == 0) printf("\n%3d: ", i);
        printf("%5d ", data[i + CONFLICT_FREE_OFFSET(i)]);
    } 
    printf("\n");
}        

__device__ void bankBelloch(float *histogram, int *histSz)
{
    //add one integer of padding every 32 elements
    __shared__ int shHistogram[SHAREDMEMSIZE];  // allocated on invocation
    int thid = threadIdx.x;
    int offset = 1;
    long n = CLASSBLOCKDIM * 2; 

    long ai = 2*thid;
    long bi = 2*thid + 1;
    long bankOffsetA = CONFLICT_FREE_OFFSET(ai);
    long bankOffsetB = CONFLICT_FREE_OFFSET(bi); 
    shHistogram[ai + bankOffsetA] = histogram[ai];
    shHistogram[bi + bankOffsetB] = histogram[bi];
    /*
       __syncthreads();
       if (threadIdx.x == 0 && blockIdx.x == 0)
       {
       printIntArray(shHistogram, n, "4) After shared memory load");
       }
       __syncthreads();
       return;
     */

    for (int d = n>>1; d > 0; d >>= 1)     // build sum in place up the tree
    { 
        __syncthreads();
        if (thid < d)
        {
            long ai = offset*(2*thid+1)-1;
            long bi = offset*(2*thid+2)-1;
            ai += CONFLICT_FREE_OFFSET(ai);
            bi += CONFLICT_FREE_OFFSET(bi);    
            shHistogram[bi] += shHistogram[ai];
        }

        offset *= 2;
    }

    if (thid==0) { shHistogram[n - 1 + CONFLICT_FREE_OFFSET(n - 1)] = 0;}
    /*   
         __syncthreads();
         if (threadIdx.x == 0 && blockIdx.x == 0)
         {
         printIntArray(shHistogram, n, "4) After down sweep");
         }
         __syncthreads();
         return;
     */

    for (int d = 1; d < n; d *= 2) // traverse down tree & build scan
    {
        offset >>= 1;
        __syncthreads();
        if (thid < d)                     
        {
            long ai = offset*(2*thid+1)-1;
            long bi = offset*(2*thid+2)-1;
            ai += CONFLICT_FREE_OFFSET(ai);
            bi += CONFLICT_FREE_OFFSET(bi);    

            int t = shHistogram[ai];
            shHistogram[ai] = shHistogram[bi];
            shHistogram[bi] += t; 
        }
    }

    __syncthreads();
    /*
       if (threadIdx.x == 0 && blockIdx.x == 0)
       {
       printIntArray(shHistogram, n, "4) After up sweep");
       }
       __syncthreads();
       return;
     */
    if (threadIdx.x == 0)
    {
        (*histSz) = shHistogram[n - 1 + CONFLICT_FREE_OFFSET(n - 1)] +
            histogram[n - 1];
    }
}

/*
   normalizeHist
   Normalizes the histogram so that every bin value is between 0 and NORMMAX.
   The histogram to be normalized is in elements
   histograms[blockIdx.x * TOTALBINS] ... histograms[(blockIdx.x + 1) * TOTALBINS]
   The result will be stored in normHistograms[blockIdx.x * TOTALBINS] ... 
   normHistograms[(blockIdx.x + 1) * TOTALBINS]

Inputs:
histograms - array that holds the histogram to be normalized
histSz - size of the input histogram (sum of its bins)

Outputs:
normHistograms - array to hold the normalized histogram
 */
__device__ void normalizeHist(float * normHistograms, int histSz)
{
    int tdx = threadIdx.x;
    float * normHistogramTile = &normHistograms[TOTALBINS];
    while (tdx < TOTALBINS)
    {
        normHistogramTile[tdx] = (normHistogramTile[tdx]/(float)histSz) * NORMMAX;
        tdx += blockDim.x;
    }
} 

//this can be used for debugging
__device__ void printFloatArray(float * array, int startIdx, int length)
{
    int i, j = 0;
    for (i = startIdx; i < startIdx + length; i++, j++)
    {
        if ((j % 16) == 0) printf("\n%3d: ", i);
        printf("%6.1f ", array[i]);
    } 
}        

//launched to get more accurate timing
__global__ void emptyKernel()
{
}
