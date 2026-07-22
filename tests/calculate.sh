#!/bin/bash
set -o nounset
set -o errexit
set -o pipefail

# For bam file we do the md5sum
module load samtools/1.14
#enter the workflow's final output directory ($1)
cd $1

#find all bam files, return their samtools flagstat
find -name *.bam -xtype f -exec samtools flagstat {} \;

#find all .csv files, run md5sums
for c in *metrics.csv;do wc -l $c;done | sort -k 2
