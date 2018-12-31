#!/bin/bash

imageDir="images"
for filename in $imageDir/*.ppm; do
   suffix=`echo $filename | sed 's/.ppm//'`
   echo "./classify -s $suffix.h $filename"
   ./classify -s $suffix.h $filename
   sleep 1
done
