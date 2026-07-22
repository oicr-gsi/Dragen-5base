version 1.0

struct InputGroup {
  File fastqR1
  File fastqR2
  String readGroup
}

struct GenomeResources {
    String dbSNP
    String referenceDirectory
    String dragenVersion
}

workflow dragen5Base {
  input {
    String reference
    Array[InputGroup] samples 
    String outputFileNamePrefix
    String dragenBinPath = "/opt/dragen/4.5.4/bin/"
    Int timeout = 40
  }
  parameter_meta {
    reference: "Reference id"
    dragenBinPath: "Path to DRAGEN bin directory on device, we need this to select right version"
    outputFileNamePrefix: "Output file name prefix for final results"
    samples: "Array of InputGroups with sample-specific data"
    timeout: "The maximum number of hours this workflow can run for."
  }

  Map[String,GenomeResources] dragen_resources_by_genome = {
    "hg38": {
      "dbSNP": "/.mounts/labs/gsiprojects/gsi/Dragen/reference/dbSNP.151/common_all_dbSNP151_hg38p7_sorted.vcf.gz",
      "referenceDirectory": "/.mounts/labs/gsiprojects/gsi/Dragen/reference/hg38fa.p12_v4.5/",
      "dragenVersion": "4.5.4"
    },
    "hg38_noAlt": {
      "dbSNP": "/.mounts/labs/gsiprojects/gsi/Dragen/reference/dbSNP.151/common_all_dbSNP151_hg38p7_noalt_sorted.vcf.gz",
      "referenceDirectory": "/.mounts/labs/gsiprojects/gsi/Dragen/reference/hg38_noAlt-p12",
      "dragenVersion": "4.5.4"
    } 
    }

  meta {
    author: "Peter Ruzanov"
    email: "pruzanov@oicr.on.ca"
    description: "Workflow to produce methylation calls from an Illumina instrument's run directory using DRAGEN pipeline"
    dependencies: [{
      name: "dragen5base", 
      url: "https://help.dragen.illumina.com/product-guides/dragen-v4.5/dragen-methylation-pipeline/dragen-5base-pipeline"
    }]
    output_meta: {
      annotatedBam: {
        description: "BAM file with additional tags showing methylation status of all Cytosins",
        vidarr_label: "annotatedBam"
      },
      annotatedBai: {
        description: "BAM file index",
        vidarr_label: "annotatedBai"
      },
      methylationReport: {
        description: "Main report, shows a detailed information on cytosine methylation",
        vidarr_label: "methylationReport"
      },
      lambdaControls: {
        description: "Methylation controls, lambda sequences",
        vidarr_label: "lambdaControls"
      },
      puc19Controls: {
        description: "Methylation controls, puc19 sequences",
        vidarr_label: "puc19Controls"
      },
      ploidyVcf: {
        description: "VCF file with M5mC fields (INFO,FORMAT) showing methylation status",
        vidarr_label: "ploidyVcf"
      },
      ploidyIndex: {
        description: "VCF index",
        vidarr_label: "ploidyIndex"
      },
      fastqcMetrics: {
        description: "fastQC metrics file",
        vidarr_label: "fastqcMetrics"
      },
      mappingMetrics: {
        description: "Mapping metrics file",
        vidarr_label: "mappingMetrics"
      },
      methylMetrics: {
        description: "Methylation metrics file",
        vidarr_label: "methylMetrics"
      },
      metricsJson: {
        description: "JSON file with methylation metrics",
        vidarr_label: "metricsJson"
      },
      ploidyMetrics: {
        description: "Ploidy metrics file",
        vidarr_label: "ploidyMetrics"
      },
      timeMetrics: {
        description: "Time metrics file",
        vidarr_label: "timeMetrics"
      },
      trimmerMetrics: {
        description: "Trimming metrics file",
        vidarr_label: "trimmerMetrics"
      },
      coverageMetrics: {
        description: "Coverage Metrics file",
        vidarr_label: "coverageMetrics"
      }

    }
  }

  # For multi-lane sequencing we absolutely need this:
  scatter(t in samples) {
    call extractInfoLine {
      input:
      fastqInput = object{fastqR1: t.fastqR1, fastqR2: t.fastqR2, readGroup: t.readGroup}
    }
  }

  # Compose the list for DRAGEN:
  call composeList {
    input:
      inputLines = extractInfoLine.outputLine,
      outputFileName = "dragen_inputs.csv"
  }

  # Run Dragen (5base analysis) 
  call runDragen {
    input:
      csv = composeList.inputList,
      dragenBinPath = dragenBinPath,
      timeout = timeout,
      refDir = dragen_resources_by_genome[reference].referenceDirectory,
      outputFileNamePrefix = outputFileNamePrefix
  }

  output {
     File annotatedBam = runDragen.annotatedBam
     File annotatedBai = runDragen.annotatedBai
     File methylationReport = runDragen.methylationReport
     File lambdaControls = runDragen.lambdaControls
     File puc19Controls  = runDragen.puc19Controls
     File ploidyVcf = runDragen.ploidyVcf
     File ploidyIndex = runDragen.ploidyIndex
     File fastqcMetrics = runDragen.fastqcMetrics
     File mappingMetrics = runDragen.mappingMetrics
     File methylMetrics = runDragen.methylMetrics
     File metricsJson = runDragen.metricsJson
     File ploidyMetrics = runDragen.ploidyMetrics
     File timeMetrics = runDragen.timeMetrics
     File trimmerMetrics = runDragen.trimmerMetrics
     File coverageMetrics = runDragen.coverageMetrics

  }
}

# =====================================================================
# A scripted extraction of info from RG line to dragen-compliant string
# =====================================================================
task extractInfoLine {
   input {
       InputGroup fastqInput
       String parsingScript = "$DRAGEN_SCRIPTS_ROOT/bin/composeList.py"
       Int timeout = 4
       Int jobMemory = 4
       String modules = "dragen-scripts/0.3"
   }

   parameter_meta {
     fastqInput: "InputGroup struct entry with fastq files"
     parsingScript: "Script for parsing inputs into a line"
     timeout: "Timeout for the job"
     jobMemory: "Job allocated RAM"
     modules: "dependency modules"
   }

   command <<<
    python3 ~{parsingScript} -i ~{write_json(fastqInput)}
   >>>

   runtime {
     timeout: "~{timeout}"
     modules: "~{modules}"
     memory:  "~{jobMemory} GB"
   }

   output {
     String outputLine = read_string(stdout())
   }

   meta {
     output_meta: {
       outputLine: "Output line to use in a list of fastq files in dragen-compliant format"
     }
   }
}

# =====================================================================
#  Compose a dragen-compliant list of inputs to use with snv caller
# =====================================================================
task composeList {
   input  {
      Array[String] inputLines
      String listWritingScript = "$DRAGEN_SCRIPTS_ROOT/bin/writeFile.py"
      String outputFileName
      Int jobMemory = 4
      Int timeout = 4
      String modules = "dragen-scripts/0.3"
   }

   parameter_meta {
     inputLines: "Array of input lines to print"
     listWritingScript: "Script for writing out list of inputs"
     outputFileName: "Name of an output file, list of inputs"
     jobMemory: "Job allocated RAM"
     timeout: "Timeout for the job"
     modules: "dependency modules"
   }

   command<<<
   python3 ~{listWritingScript} -o ~{outputFileName} -l "~{sep=';' inputLines}"
   >>>


   runtime {
      timeout: "~{timeout}"
      modules: "~{modules}"
      memory:  "~{jobMemory} GB"
   }

   output {
     File inputList = "~{outputFileName}"
   }

   meta {
     output_meta: {
       inputList: "Output file to use with dragen SNV caller"
     }
   }
}

# =====================================================================
# Build index (optional task)
# Generate the DRAGEN hashtable reference using the following commands.
# =====================================================================
task buildDragenIndex {
  input {
    String refDir = "/.mounts/labs/gsiprojects/gsi/Dragen/reference"
    String dragenBinPath
    Int timeout = 12
  }

  parameter_meta {
    refDir: "Reference directory"
  }

  command <<<
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
  >>>

  runtime {
    backend: "DRAGEN"
    timeout: "~{timeout}"
  }

}

# ==========================================================
#      Main task. Make those calls!
# ==========================================================
task runDragen {
  input {
    String refDir
    File csv
    String dragenBinPath
    Boolean firstTileOnly = false
    Boolean enableDupMarking = true
    Boolean enableTargeted = true
    Boolean onlyMatchedReads = true
    String outputFileNamePrefix
    String methProtocol = "directional"
    Int timeout = 40
    String mappingImplementation = "native"
    String? additionalParameters
  }

  parameter_meta {
    csv: "Formatted csv input for Dragen, containing fastq files and read-group information"
    refDir: "The reference genome directoty"
    methProtocol: "Methylation protocol (none|directional|non-directional|directional-complement|pbat),Default: directional"
    dragenBinPath: "path to the bin directory with dragen executable"
    enableDupMarking: "Boolean flag for enabling/disabling duplicate marking"
    enableTargeted: "Enable targeted sequencing"
    firstTileOnly: "Flag for processing first tile only. Default false"
    onlyMatchedReads: "Process only matched reads. Default true"
    timeout: "Timeout for this task. Default 40"
    outputFileNamePrefix: "Output file name prefix"
    mappingImplementation: "Mapping implementation single-pass|multi-pass. Default multi-pass" 
    additionalParameters: "Pass parameters which were not exposed"
  }

  command <<<
  export PATH=$PATH:~{dragenBinPath}
  dragen -f -r ~{refDir} \
  --fastq-list ~{csv} \
  --fastq-list-all-samples true \
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
  >>>

  runtime {
    backend: "DRAGEN"
    timeout: "~{timeout}"
  }
  
  output { 
     File annotatedBam = "~{outputFileNamePrefix}.bam"
     File annotatedBai = "~{outputFileNamePrefix}.bam.bai"
     File methylationReport = "~{outputFileNamePrefix}.CX_report.txt.gz"
     File lambdaControls = "~{outputFileNamePrefix}.lambda_unmethylated_control.control.M-bias.txt"
     File puc19Controls  = "~{outputFileNamePrefix}.puc19_methylated_control.control.M-bias.txt"
     File ploidyVcf = "~{outputFileNamePrefix}.ploidy.vcf.gz"
     File ploidyIndex = "~{outputFileNamePrefix}.ploidy.vcf.gz.tbi"
     File fastqcMetrics = "~{outputFileNamePrefix}.fastqc_metrics.csv"
     File mappingMetrics = "~{outputFileNamePrefix}.mapping_metrics.csv"
     File methylMetrics = "~{outputFileNamePrefix}.methyl_metrics.csv"
     File metricsJson = "~{outputFileNamePrefix}.metrics.json"
     File ploidyMetrics = "~{outputFileNamePrefix}.ploidy_estimation_metrics.csv"
     File timeMetrics = "~{outputFileNamePrefix}.time_metrics.csv"
     File trimmerMetrics = "~{outputFileNamePrefix}.trimmer_metrics.csv"
     File coverageMetrics = "~{outputFileNamePrefix}.wgs_coverage_metrics.csv"
   }
}

