//If you want to change the number of bins, you will need to change the
//header files.  But you won't be able to change the headers in the
//shared images directory.  Instead, you'll need to create your own
//local images directory, copy the images into that, and then continue
//with these directions below these.
//Get rid of the link:
//  rm images
//Create your own images directory:
//  mkdir images
//Copy the images into your local directory:
//  cp /u/css/classes/3530/images/* images


//If you want to change the number of bins, the lines below 
//need to be commented out and the lines below that need to be uncommented.
//Scrow down and you'll see the lines I'm referring to.
//Then type a make and  ./buildHdrs.sh
//After that, re-edit this file to uncomment out the top part 
//and comment out the lines at the bottom

//include the models
//each of these define a histogram
#include "images/Batman1.h"
#include "images/Batman2.h"
#include "images/Batman3.h"
#include "images/Batman4.h"
#include "images/Batman5.h"
#include "images/Batman6.h"
#include "images/Batman7.h"
#include "images/Batman8.h"
#include "images/Batman9.h"
#include "images/Batman10.h"
#include "images/Batman11.h"
#include "images/Batman12.h"
#include "images/Batman13.h"
#include "images/Batman14.h"
#include "images/Batman15.h"
#include "images/Batman16.h"
#include "images/Batman17.h"
#include "images/Batman18.h"
#include "images/Batman19.h"
#include "images/Batman20.h"
#include "images/Batman21.h"
#include "images/Batman22.h"
#include "images/Batman23.h"
#include "images/Batman24.h"
#include "images/Batman25.h"
#include "images/Batman26.h"
#include "images/Batman27.h"
#include "images/Batman28.h"
#include "images/Batman29.h"
#include "images/Batman30.h"
#include "images/Batman31.h"
#include "images/Batman32.h"
#include "images/Batman33.h"
#include "images/Batman34.h"
#include "images/Batman35.h"
#include "images/Batman36.h"
#include "images/Batman37.h"
#include "images/Batman38.h"
#include "images/Batman39.h"
#include "images/Batman40.h"
#include "images/Batman41.h"
#include "images/Batman42.h"
#include "images/Batman43.h"
#include "images/Batman44.h"
#include "images/Batman45.h"
#include "images/Batman46.h"
#include "images/Batman47.h"
#include "images/Batman48.h"
#include "images/Batman49.h"
#include "images/Batman50.h"
#include "images/Batman51.h"
#include "images/Batman52.h"
#include "images/Batman53.h"
#include "images/Batman54.h"
#include "images/Batman55.h"
#include "images/Batman56.h"
#include "images/Batman57.h"
#include "images/Batman58.h"
#include "images/Batman59.h"
#include "images/Batman60.h"
#include "images/Batman61.h"
#include "images/Batman62.h"
#include "images/Batman63.h"
#include "images/Batman64.h"
#include "images/Batman65.h"
#include "images/Batman66.h"
#include "images/Batman67.h"
#include "images/Batman68.h"
#include "images/Batman69.h"
#include "images/Batman70.h"
#include "images/Batman71.h"
#include "images/Batman72.h"
#include "images/Batman73.h"
#include "images/Batman74.h"
#include "images/Batman75.h"
#include "images/Batman76.h"
#include "images/Batman77.h"
#include "images/Batman78.h"
#include "images/BlackWidow1.h"
#include "images/BlackWidow2.h"
#include "images/C3PO1.h"
#include "images/C3PO2.h"
#include "images/CaptainAmerica1.h"
#include "images/CaptainAmerica2.h"
#include "images/DarthVader1.h"
#include "images/DarthVader2.h"
#include "images/Flash1.h"
#include "images/Flash2.h"
#include "images/Hawkeye1.h"
#include "images/Hawkeye2.h"
#include "images/Hulk1.h"
#include "images/Hulk2.h"
#include "images/Ironman1.h"
#include "images/Ironman2.h"
#include "images/Ironman3.h"
#include "images/Loki1.h"
#include "images/Loki2.h"
#include "images/Magneto1.h"
#include "images/Magneto2.h"
#include "images/Spiderman1.h"
#include "images/Spiderman2.h"
#include "images/SpidermanVenom1.h"
#include "images/SpidermanVenom2.h"
#include "images/Superman1.h"
#include "images/Superman2.h"
#include "images/Thor1.h"
#include "images/Thor2.h"
#include "images/Wolverine1.h"
#include "images/Wolverine2.h"
#include "images/WonderWoman1.h"
#include "images/WonderWoman2.h"

#define MODELS 35

histogramT * models[MODELS] = {&Batman1, &Batman2, &BlackWidow1,
       //&Batman3, &Batman4, &Batman5, &Batman6, &Batman7,
       //40
       //&Batman8, &Batman9, &Batman10, &Batman11, &Batman12,
       //&Batman13, &Batman14, &Batman15, &Batman16, &Batman17,
       //50
       
      
       
       //110
       
       


       &BlackWidow2, &C3PO1, &C3PO2, &CaptainAmerica1, 
       &CaptainAmerica2, &DarthVader1, &DarthVader2, &Hawkeye1, 
       &Hawkeye2, &Flash1, &Flash2, &Hulk1, &Hulk2, &Ironman1, 
       &Ironman2, &Loki1, &Loki2, &Ironman3, &Magneto1, &Magneto2, 
       &Spiderman1, &Spiderman2, &SpidermanVenom1, &SpidermanVenom2, 
       &Superman1, &Superman2, &Thor1, &Thor2, &Wolverine1, &Wolverine2, 
       &WonderWoman1, &WonderWoman2
       
      
       };

/*

//Uncomment this if you want to change the size of the bins and thus
//need to build new models.

#define MODELS 0
histogramT * models[1] = {NULL};

*/


