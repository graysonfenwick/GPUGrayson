#!/bin/bash

executable=$1

imageDir="images"
for filename in $imageDir/*.ppm; do
   echo " "
   echo "$executable $filename"
   ./$executable $filename
   sleep 1
done
