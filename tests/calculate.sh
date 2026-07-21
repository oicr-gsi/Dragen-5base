#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

# For bam file we do the md5sum
module load samtools/1.14
#enter the workflow's final output directory ($1)
cd $1

# For json file we do the md5sum
find . -name '*.json' | xargs md5sum

#find all bam files, return their samtools flagstat
find -name *.bam -xtype f -exec samtools flagstat {} \;

#find all .csv files, run md5sums
find -name "*.csv" | xargs md5sum
