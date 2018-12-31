
counter=68
while [ $counter -le 78 ]
do
    cp "Batman1.h" "Batman$counter.h"
    cp "Batman1.ppm" "Batman$counter.ppm"
    sed -i "1s/.*/histogramT Batman$counter =/" "Batman$counter.h"
    sed -i "3s/.*/\"Batman$counter.ppm\",/" "Batman$counter.h"
    ((counter++))
done
