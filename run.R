#!/usr/local/bin/Rscript

task <- dyncli::main()

# load libraries
library(dyncli, warn.conflicts = FALSE)
library(dynwrap, warn.conflicts = FALSE)
library(dplyr, warn.conflicts = FALSE)
library(purrr, warn.conflicts = FALSE)

library(dyndimred, warn.conflicts = FALSE)
library(gng, warn.conflicts = FALSE)
library(igraph, warn.conflicts = FALSE)

#####################################
###           LOAD DATA           ###
#####################################
expression <- task$expression
parameters <- task$parameters
priors <- task$priors

# TIMING: done with preproc
timings <- list(method_afterpreproc = Sys.time())

#####################################
###        INFER TRAJECTORY       ###
#####################################
# perform dimensionality reduction
space <- dyndimred::dimred(
  as.matrix(expression), 
  method = parameters$dimred, 
  ndim = parameters$ndim
) # todo: remove as.matrix

# calculate GNG
gng_out <- gng::gng(
  space,
  max_iter = parameters$max_iter,
  max_nodes = parameters$max_nodes,
  assign_cluster = FALSE
)
node_dist <- stats::dist(gng_out$node_space) %>% as.matrix

# transform to milestone network
node_names <- 
  gng_out$nodes %>% 
  mutate(name = as.character(name))

milestone_network <- gng_out$edges %>%
  select(from = i, to = j) %>%
  mutate(
    length = node_dist[cbind(from, to)],
    directed = FALSE
  ) %>%
  select(from, to, length, directed)

# apply MST, if so desired
if (parameters$apply_mst) {
  gr <- igraph::graph_from_data_frame(milestone_network, directed = F, vertices = node_names$name)
  milestone_network <- igraph::minimum.spanning.tree(gr, weights = igraph::E(gr)$length) %>% igraph::as_data_frame()
}

# TIMING: done with method
timings$method_aftermethod <- Sys.time()

#####################################
###     SAVE OUTPUT TRAJECTORY    ###
#####################################
output <-
  wrap_data(
    cell_ids = rownames(expression)
  ) %>%
  add_dimred_projection(
    milestone_ids = rownames(gng_out$node_space),
    milestone_network = milestone_network,
    dimred_milestones = gng_out$node_space,
    dimred = space
  ) %>%
  add_timings(
    timings = timings
  )

dyncli::write_output(output, task$output)
