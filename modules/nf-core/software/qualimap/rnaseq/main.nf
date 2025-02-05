// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process QUALIMAP_RNASEQ {
    tag "$meta.id"
    label 'process_high'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::qualimap=2.2.2d" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/qualimap:2.2.2d--1"
    } else {
        container "quay.io/biocontainers/qualimap:2.2.2d--1"
    }

    input:
    tuple val(meta), path(bam)
    path  gtf

    output:
    tuple val(meta), path("${prefix}"), emit: results
    path  "*.version.txt"             , emit: version

    script:
    def software   = getSoftwareName(task.process)
    prefix         = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    def paired_end = meta.single_end ? '' : '-pe'

    def strandedness = 'non-strand-specific'
    if (meta.strandedness == 'forward') {
        strandedness = 'strand-specific-forward'
    } else if (meta.strandedness == 'reverse') {
        strandedness = 'strand-specific-reverse'
    }
    """
    unset DISPLAY
    mkdir tmp
    export _JAVA_OPTIONS=-Djava.io.tmpdir=./tmp
    qualimap \\
        rnaseq \\
        --java-mem-size=12G \\
        -bam $bam \\
        -gtf $gtf \\
        -p $strandedness \\
        $paired_end \\
        -outdir $prefix

    echo \$(qualimap 2>&1) | sed 's/^.*QualiMap v.//; s/Built.*\$//' > ${software}.version.txt
    """
}
