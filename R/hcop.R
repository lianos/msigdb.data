
#' Retrieves and parses the latest HCOP data
#'
#' HCOPS is the HGNC Comparison of Orthology Predictions.
#' This code was taken and modifed from the msigdbr::msigdbr-prepare.R script
#' We would have just stuck with that, however they dump the ensembl identifiers
#' and I want to keep them
#'
#' We use the human hcop file because MSigDB's genesets (as far as I understand)
#' are referenced to human identifiers first.
#'
#' This script is not exported on purpose
#'
#' @seealso https://www.genenames.org/help/hcop/
#' @noRd
generate_hcop_orthologs <- function(hcop_txt_url = NULL) {
  if (!test_file_exists(hcop_txt_url)) {
    message("Downloading hcop file ================================")
    hcop_txt_url = file.path(
      "ftp://ftp.ebi.ac.uk/pub/databases/genenames/hcop",
      "human_all_hcop_sixteen_column.txt.gz")
  }
  hcop = readr::read_tsv(hcop_txt_url)

  # Keep mapping only genes found in multiple ortholog/homolog databases
  msigdbr_orthologs =
    hcop %>%
    dplyr::select(
      human_entrez_gene,
      human_ensembl_gene,
      human_gene_symbol = human_symbol,
      species_id = ortholog_species,
      entrez_gene = ortholog_species_entrez_gene,
      ensembl_gene = ortholog_species_ensembl_gene,
      gene_symbol = ortholog_species_symbol,
      sources = support
    ) %>%
    dplyr::filter(
      human_entrez_gene != "-",
      entrez_gene != "-",
      gene_symbol != "-"
    ) %>%
    dplyr::mutate(
      human_entrez_gene = as.integer(human_entrez_gene),
      entrez_gene = as.integer(entrez_gene),
      num_sources = stringr::str_count(sources, ",") + 1
    ) %>%
    dplyr::filter(
      # human_entrez_gene %in% msigdb_entrez_genes,
      # num_sources > 1
      num_sources >= 0
    )

  # Names and IDs of common species
  species_tbl <- filter(species_info(hcops_only = FALSE), common_name != "human")

  # Add species names
  msigdbr_orthologs = dplyr::inner_join(
    species_tbl,
    msigdbr_orthologs, by = "species_id")

  # For each gene, only keep the best ortholog (found in the most databases)
  orthologs =
    msigdbr_orthologs %>%
    dplyr::group_by(human_entrez_gene, species_name) %>%
    dplyr::top_n(1, num_sources) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(human_entrez_gene = as.character(human_entrez_gene),
           entrez_gene = as.character(entrez_gene),
           species_id = as.integer(species_id))
  attr(orthologs, "creation_date") <- format(Sys.time())
  orthologs
}