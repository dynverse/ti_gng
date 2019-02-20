FROM dynverse/dynwrappy3:v0.1.0

ARG GITHUB_PAT

RUN apt-get update && apt-get install -y libudunits2-dev

RUN R -e 'devtools::install_github("rcannood/gng")'

COPY definition.yml example.R run.R /code/

ENTRYPOINT Rscript /code/run.R
