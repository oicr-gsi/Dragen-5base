# dragen5Base

Workflow to produce methylation calls from an Illumina instrument's run directory using DRAGEN pipeline

## Overview

## Dependencies

* [dragen5base](https://help.dragen.illumina.com/product-guides/dragen-v4.5/dragen-methylation-pipeline/dragen-5base-pipeline)


## Usage

### Cromwell
```
java -jar cromwell.jar run dragen5Base.wdl --inputs inputs.json
```

### Inputs

#### Required workflow parameters:
Parameter|Value|Description
---|---|---
`reference`|String|Reference id
`sample`|InputGroup|InputGroups with sample-specific data
`outputFileNamePrefix`|String|Output file name prefix for final results


#### Optional workflow parameters:
Parameter|Value|Default|Description
---|---|---|---
`dragenBinPath`|String|"/opt/dragen/4.5.4/bin/"|Path to DRAGEN bin directory on device, we need this to select right version
`timeout`|Int|40|The maximum number of hours this workflow can run for.


#### Optional task parameters:
Parameter|Value|Default|Description
---|---|---|---
`runDragen.firstTileOnly`|Boolean|false|Flag for processing first tile only. Default false
`runDragen.enableDupMarking`|Boolean|true|Boolean flag for enabling/disabling duplicate marking
`runDragen.enableTargeted`|Boolean|true|Enable targeted sequencing
`runDragen.onlyMatchedReads`|Boolean|true|Process only matched reads. Default true
`runDragen.methProtocol`|String|"directional"|Methylation protocol (none|directional|non-directional|directional-complement|pbat),Default: directional
`runDragen.mappingImplementation`|String|"native"|Mapping implementation single-pass|multi-pass. Default multi-pass
`runDragen.additionalParameters`|String?|None|Pass parameters which were not exposed


### Outputs

Output | Type | Description | Labels
---|---|---|---
`annotatedBam`|File|BAM file with additional tags showing methylation status of all Cytosins|vidarr_label: annotatedBam
`annotatedBai`|File|BAM file index|vidarr_label: annotatedBai
`methylationReport`|File|Main report, shows a detailed information on cytosine methylation|vidarr_label: methylationReport
`lambdaControls`|File|Methylation controls, lambda sequences|vidarr_label: lambdaControls
`puc19Controls`|File|Methylation controls, puc19 sequences|vidarr_label: puc19Controls
`ploidyVcf`|File|VCF file with M5mC fields (INFO,FORMAT) showing methylation status|vidarr_label: ploidyVcf
`ploidyIndex`|File|VCF index|vidarr_label: ploidyIndex
`fastqcMetrics`|File|fastQC metrics file|vidarr_label: fastqcMetrics
`mappingMetrics`|File|Mapping metrics file|vidarr_label: mappingMetrics
`methylMetrics`|File|Methylation metrics file|vidarr_label: methylMetrics
`metricsJson`|File|JSON file with methylation metrics|vidarr_label: metricsJson
`ploidyMetrics`|File|Ploidy metrics file|vidarr_label: ploidyMetrics
`timeMetrics`|File|Time metrics file|vidarr_label: timeMetrics
`trimmerMetrics`|File|Trimming metrics file|vidarr_label: trimmerMetrics
`coverageMetrics`|File|Coverage Metrics file|vidarr_label: coverageMetrics


## Commands
This section lists command(s) run by dragen5Base workflow
 
* Running dragen5Base with Cromwell
 
 cromwell.jar submit dragen5base.wdl -i my_inputs.json -h http://myhost.cromwell.ca
 
## Generate indexes for reference and methylation hashtables
 
This really is an optional code which is not supposed to run every time but is here
so that if a need arises to generate new indices for whatever reason - it is available.
 
```
   export PATH=$PATH:~{dragenBinPath}
   dragen --ht-reference ~{refDir}/hg38fa.p12/hg38_random.fa \
   --output-directory ~{refDir}/hg38fa.p12_v4.5 \
   --build-hash-table true \
   --ht-alt-liftover /opt/dragen/4.5.4/resources/ht_builder/hg38/bwa-kit_hs38DH_liftover.sam \
   --enable-cnv true \
   --ht-build-rna-hashtable true
   
   dragen --build-hash-table true \
   --ht-reference ~{refDir}/hg38fa.p12/hg38_random.fa \
   --output-directory ~{refDir}/hg38fa.p12_5base_index \
   --ht-methylated-combined true \
   --methylation-mapping-implementation multi-pass \
   --ht-seed-len 27 \
   --ht-max-seed-freq 16 \
   --ht-num-threads 32
```
 
## runDragen
 
Main function which runs DRAGEN pipeline and produces a number of important outputs, to mention
just a few - 
 
- bam file (and it's index file) with XR:Z, XG:Z and XM:Z tags with important methylation info
- vcf files with INFO and FORMAT M5mC fields also showing base methylation status
- metrics files which are too many to list here. See the metadata part of wdl or Illumina docs
 
We run this on paired fastq files which should come from an experiment actually capable of
producing proper data for this workflow.
 
```
   export PATH=$PATH:~{dragenBinPath}
   dragen -f -r ~{refDir} \
   -1 ~{fastqFile1} \
   -2 ~{fastqFile2} \
   --RGID ~{rgid} \
   --RGSM ~{rgsm} \
   --enable-map-align-output true \
   --enable-duplicate-marking ~{enableDupMarking} \
   --enable-variant-caller false \
   --enable-methylation-calling true \
   --enable-targeted ~{enableTargeted} \
   --methylation-conversion=illumina \
   --build-hash-table false \
   --methylation-protocol ~{methProtocol} \
   --methylation-generate-cytosine-report true \
   --methylation-generate-mbias-report false \
   --validate-pangenome-reference false \
   --output-directory . \
   --output-file-prefix ~{outputFileNamePrefix} ~{additionalParameters}
```
## Support

For support, please file an issue on the [Github project](https://github.com/oicr-gsi) or send an email to gsi@oicr.on.ca .

_Generated with generate-markdown-readme (https://github.com/oicr-gsi/gsi-wdl-tools/)_
