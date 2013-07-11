#!/bin/bash

BASE_IMAGE=/home/hduser/base.img
BASE_XML=/home/hduser/base.xml
PASSWD=lhcwhu

for i in $(cat phosts.txt | grep -Ev "^$|#")
do
    sshpass -p$PASSWD scp copy_base.sh hduser@$i:~/
done

echo "done"
