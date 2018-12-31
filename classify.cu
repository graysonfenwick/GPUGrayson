/*  
In addition to implementing the device code, answer the following questions:

1) The current value for BINS in config.h is 16.  If you reduce the value for BINS to
8 or 4, how is this going to impact the speedups?  Why?  (You can try this
out if you like.  See models.h for directions.)


2) If more models are added to the program, how is this going to impact 
the speedups?  Why?

3) In regards to the classification, what is the advantage of having fewer
bins then the image pixel space (256 * 256 * 256)?


4) What can go wrong if there are too few bins?

*/

#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
//config.h contains a number of needed definitions
#include "config.h"  
#include "histogram.h"
#include "wrappers.h"
#include "h_classify.h"
#include "d_classify.h"

#include "models.h"

//prototypes for functions in this file 
static void parseCommandArgs(int, char **, char **, int *, char *);
static void printUsage();
static void readPPMImage(char *, unsigned char **, int *, int *, int *, int, int *);
static void writeHistogram(histogramT *, char *);
static void writeBin(FILE *, int *, int);
static void buildName(const char * , char name[NAMELEN]);
static void compareHistograms(histogramT *, histogramT *, int);
static void compareComparisons(comparisonT *, comparisonT *, int);
static void initHistogram(char *, histogramT *, int);
static void printTopTwo(comparisonT *);
static void printTitle(const char *);

/*
    main 
    Opens the ppm file and reads the contents.  Uses the CPU
    to build a histogram of the image, optionally outputting
    the histogram to a file in the form of a C struct initialization.  
    If the save option is not provided the program will also classify
    the image on the CPU and histogram and classify the image on the GPU.
    It compares the CPU and GPU results to make sure they match
    and outputs the times it takes on the CPU and the GPU to build the 
    histogram and perform the classification.
*/
int main(int argc, char * argv[])
{
    unsigned char * hPin, *dPin; 
    histogramT * h_hgram, * d_hgram;
    char * inputfile;
    char outputfile[NAMELEN];
    int width, height, color, pitch, saveOutput;
    float cpuTime, gpuTime;
    int gpuStride = 32, cpuStride = 4;

    printTitle(argv[0]);

    //need an array of these; one for each model
    //one array for the GPU and one array for the CPU
    comparisonT * hresult = (comparisonT *) Malloc(sizeof(comparisonT) * MODELS);
    comparisonT * dresult = (comparisonT *) Malloc(sizeof(comparisonT) * MODELS);

    parseCommandArgs(argc, argv, &inputfile, &saveOutput, outputfile);

    //create histogram structs for the host and the device
    h_hgram = (histogramT *) Malloc(sizeof(histogramT));
    d_hgram = (histogramT *) Malloc(sizeof(histogramT));
    initHistogram(inputfile, h_hgram, TOTALBINS);


    //read and pitch the image for the CPU
    readPPMImage(inputfile, &hPin, &width, &height, &color, cpuStride, &pitch);

    if (saveOutput) 
    {
       //if save is requested, just save results of histogram to file
       //and don't continue
       printf("\nComputing histogram of %s.\n", inputfile);
       histoOnCPU(h_hgram, hPin, height, width, pitch);
       writeHistogram(h_hgram, outputfile);
       printf("Storing result in %s.\n", outputfile);
       return EXIT_SUCCESS;
    }

    printf("\nComputing histogram and classifying %s.\n", inputfile);

    //use the CPU to build the histogram and classify it
    cpuTime = h_classify(h_hgram, hresult, models, MODELS, hPin, height, width, pitch); 
    printf("\tCPU time: \t\t%f msec\n", cpuTime);

    //read and pitch the image for the GPU
    readPPMImage(inputfile, &dPin, &width, &height, &color, gpuStride, &pitch);

    //use the GPU to build the histogram and classify it
    initHistogram(inputfile, d_hgram, TOTALBINS);
    gpuTime = d_classify(d_hgram, dresult, models, MODELS, dPin, height, width, pitch);
    compareHistograms(d_hgram, h_hgram, TOTALBINS);
    compareComparisons(dresult, hresult, MODELS);
    printf("\tGPU time: \t\t%f msec\n", gpuTime);
    printf("\tSpeedup: \t\t%f\n", cpuTime/gpuTime);
    printTopTwo(dresult);

    free(d_hgram);
    free(h_hgram);
    free(hPin);
    free(dPin);
    return EXIT_SUCCESS;
}

void printTitle(const char * executable)
{
    /*
   if (strcmp(executable, "./classify1") == 0)
      printf("Classify using a naive sum to calculate the histogram size\n");
   else if (strcmp(executable, "./classify2") == 0)
      printf("Classify using a Kogge-Stone sum to calculate the histogram size\n");
   else if (strcmp(executable, "./classify3") == 0)
      printf("Classify using a Belloch sum to calculate the histogram size\n");
   else if (strcmp(executable, "./classify4") == 0)
      printf("Classify using a Belloch sum with reduced bank conflicts to calculate the histogram size\n");
    */
}
   




/*
    initHistogram
    Initializes a histogram struct by setting the bin values to 0 and setting
    the fileName field to the name of the file containing the image to histogram.
*/
void initHistogram(char * fileName, histogramT * histP, int length)
{
    int i;
    strncpy(histP->fileName, fileName, sizeof(histP->fileName));
    for (i = 0; i < length; i++)
    {
       histP->histogram[i] = 0;
    }
}

/*
    printTopTwo
    Finds and prints the top two matches in the comparison struct.
    comparison values will range from 0 to 1.
    An exact match will have a comparison value of 1.0, which indicates
    the model matches the input image exactly.  
    A comparison value of .8 means that %80 of the pixels in the
    model and the input image are the same.
*/
   
void printTopTwo(comparisonT * result)
{
    int first = -1, second = -1;
    int i;
    for (i = 0; i < MODELS; i++)
    {
        if (first == -1)  //both first and second are -1
            first = i;
        else if (second == -1) //first is not -1
        {
            if (result[i].comparison > result[first].comparison)
            {
                second = first;
                first = i;
            } else
            {
                second = i;
            }
        } else if (result[i].comparison > result[first].comparison)
        {
            second = first;
            first = i;
        } else if (result[i].comparison > result[second].comparison)
        {
            second = i;
        }
    }
    printf("\nMatches\n");
    printf("-------\n");
    printf("\tFirst:  %s    \t%5.1f%%\n", result[first].fileName, 
           (result[first].comparison * 100));
    printf("\tSecond: %s    \t%5.1f%%\n", result[second].fileName, 
           (result[second].comparison * 100));
}

/* 
    compareHistograms
    This function takes two histogramT structs. One histogramT 
    contains bins calculated  by the GPU. The other histogramT
    contains bins calculated by the CPU. This function examines
    each bin to see that they match.

    d_Pout - histogram calculated by GPU
    h_Pout - histogram calculated by CPU
    length - number of bins in histogram
    
    Outputs an error message and exits program if the histograms differ.
*/
void compareHistograms(histogramT * d_Pout, histogramT * h_Pout, int length)
{
    int i;
    for (i = 0; i < length; i++)
    {
        if (d_Pout->histogram[i] != h_Pout->histogram[i])
        {
            printf("Histograms don't match.\n");
            printf("host bin[%d] = %d\n", i, h_Pout->histogram[i]);
            printf("device bin[%d] = %d\n", i, d_Pout->histogram[i]);
            exit(EXIT_FAILURE);
        }
    }
}

/* 
    compareComparisons
    This function takes two comparisonT structs. One comparisonT 
    contains a comparison array calculated  by the GPU.  The other 
    comparsionT contains a comparison array calculated
    by the CPU.  This function examines each comparison array
    element to see that they match.

    d_Pout - comparison calculated by GPU
    h_Pout - comparison calculated by CPU
    length - number of comparison
    
    Outputs an error message and exits program if the comparisons differ.
*/
void compareComparisons(comparisonT * d_Pout, comparisonT * h_Pout, int length)
{
    int i;
    for (i = 0; i < length; i++)
    {
        if (abs(d_Pout[i].comparison - h_Pout[i].comparison) > 0.01)
        {
            printf("Comparisons don't match for %s.\n", d_Pout[i].fileName);
            printf("host comparison[%d] = %f\n", i, h_Pout[i].comparison);
            printf("device comparison[%d] = %f\n", i, d_Pout[i].comparison);
            exit(EXIT_FAILURE);
        }
    }
}

/* 
    writeHistogram
    Writes a histogram to an output file.

*/
void writeHistogram(histogramT * histP, char * outfile)
{
    FILE *fp = fopen(outfile, "w");
    if (fp == NULL)
    {
        printf("\nUnable to open output file: %s\n", outfile);
        printUsage();
    }
    char varname[NAMELEN];
    buildName(histP->fileName, varname);
    fprintf(fp, "histogramT %s =\n{\n\"%s.ppm\",\n", varname, varname);
    writeBin(fp, histP->histogram, TOTALBINS);
    fprintf(fp, "\n};");
    fclose(fp);
}

/*
   buildName
   Used to strip off the final four characters (.ppm) in a file
   name and any leading characters up to and including the
   last / to build a name that is then stored in the output file
   with the histogram.

   example: buildName("images/CaptainAmerica1.ppm", varname)
            stores "CaptainAmerica1" in varname
*/ 
void buildName(const char * outfile, char varname[NAMELEN])
{
    int endPoint = strlen(outfile) - 4;
    int startPoint = endPoint;
    //decrement startPoint until it reaches beginning of string
    //or a /
    while (startPoint > 0)
    {
        if (outfile[startPoint] == '/') {startPoint++; break;}
        startPoint--;
    }
    strcpy(varname, &outfile[startPoint]);
    varname[strlen(varname)-4] = '\0';
    
}

/*
   writeBin
   Outputs the bin to the output file.
*/
void writeBin(FILE * fp, int * bin, int length)
{
   int i;
   fprintf(fp, "{\n");
   for (i = 0; i < length - 1; i++)
   {
        fprintf(fp, "%d, ", bin[i]);
        if ((i + 1) % 32 == 0) fprintf(fp, " /* %d-%d */\n", i - 31, i);
   }
   fprintf(fp, "%d /* %d-%d */\n}", bin[i], i - 31, i);
}

/*
    readPPMImage
    This function opens a ppm file and reads the contents.  A ppm file
    is of the following format:
    P6
    width  height
    color
    pixels

    Each pixel consists of bytes for red, green, and blue.  If color
    is less than 256 then each color is encoded in 1 byte.  Otherwise,
    each color is encoded in 2 bytes. This function fails if the color
    is encoded in 2 bytes.
    
    The array Pin is initialized to the pixel bytes.  width, height,
    and color are pointers to ints that are set to those values.
    filename - name of the .ppm file

    If stride is not 1 then the array to hold the pixels is pitched
    so that the pitch is greater than or equal to width and also a 
    multiple of the stride.  The stride represents the memory burst length.
*/
void readPPMImage(char * filename, unsigned char ** Pin, 
                  int * width, int * height, int * color, 
                  int stride, int * pitch)
{
    int ht, wd, ptch, colr;
    char P6[3];
    FILE * fp = fopen(filename, "rb"); //read binary
    int count = fscanf(fp, "%s\n%d %d\n%d\n", P6, &wd, &ht, &colr);

    //should have read four values
    //first value is the string "P6"
    //color value must be less than 256 and greater than 0
    if (count != 4 || strncmp(P6, "P6", CHANNELS) || colr <= 0 || colr > 255)
    {
        printf("\nInvalid file format.\n\n");
        printUsage();
    }

    //pitch is a multiple of the stride
    ptch = ceil(wd/(float)stride) * stride;
       
    (*Pin) = (unsigned char *) Malloc(sizeof(unsigned char) * ptch * ht * CHANNELS);
    for (int i = 0; i < ht; i++)
    {
        if (fread(&(*Pin)[i * ptch * CHANNELS], 
                  sizeof(unsigned char) * wd * CHANNELS, 1, fp) != 1)
        {
            printf("Invalid file format.\n\n");
            printUsage();
        }
    }

    (*width) = wd;
    (*height) = ht;
    (*color) = colr;
    (*pitch) = ptch;
    fclose(fp);
}

/*
    parseCommandArgs
    This function parses the command line arguments. The program can be executed 
    like this:
    ./classify [-s <outfile>]  <file>.ppm
    or
    ./classify <file>.ppm
    If the -s option is provided, the histogram is simply built using the CPU
    and the result is stored in the output file. No classification is performed.
    In addition, it checks to see if the last command line argument
    is a ppm file and sets (*fileNm) to argv[i] where argv[i] is the name of the ppm
    file.  
*/
void parseCommandArgs(int argc, char * argv[], char ** fileNm, int * saveOutput,
                      char outputFile[NAMELEN])
{
    int fileIdx = argc - 1, save = 0;
    struct stat buffer;

    for (int i = 1; i < argc - 1; i++)
    {
        
        if (strncmp("-s", argv[i], 3) == 0) 
        {
            save = 1;
            if (i+1 >= argc - 1) 
            {
                printf("Invalid output file name: %s.\n", argv[i+1]);
                printUsage();
            }
            strncpy(outputFile, argv[i+1], NAMELEN);
            i++;
        } else if (strncmp("-h", argv[i], 3) == 0) 
        {
            printUsage();
        } else  
            printUsage();
    } 

    //check the input file name (must end with .ppm)
    int len = strlen(argv[fileIdx]);
    if (len < 5) printUsage();
    if (strncmp(".ppm", &argv[fileIdx][len - 4], 4) != 0) printUsage();

    //stat function returns 1 if file does not exist
    if (stat(argv[fileIdx], &buffer)) printUsage();
    (*fileNm) = argv[fileIdx];
    (*saveOutput) = save;
}

/*
    printUsage
    This function is called if there is an error in the command line
    arguments or if the .ppm file that is provided by the command line
    argument is improperly formatted.  It prints usage information and
    exits.
*/
void printUsage()
{
    printf("This application takes as input the name of a .ppm\n");
    printf("file containing a color image and creates a histogram\n");
    printf("of the image. It then computes an intersection of this histogram\n");
    printf("and the other histograms defined in 'models.h'. It outputs the\n");
    printf("names of the two best matching images. This work is\n");
    printf("performed on the CPU and the GPU. Their results are timed and\n");
    printf("compared.\n");
    printf("\nusage: ./classify [-s <outfile>] <name>.ppm\n");
    printf("       If the -s argument is provided, the histogram is saved\n");
    printf("              in the output file and no classification is performed.\n");
    printf("              This is used to build model histograms for this program.\n");
    printf("       <name>.ppm is the name of the input ppm file.\n");
    printf("Examples:\n");
    printf("./classify images/WonderWoman1.ppm\n");
    printf("./classify -s WonderWoman1.h images/WonderWoman1.ppm\n");
    exit(EXIT_FAILURE);
}
