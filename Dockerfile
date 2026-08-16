# Statistical Analysis Studio - portable demo image
FROM rocker/shiny:4.3.2

RUN R -e "install.packages(c( \
      'bslib','ggplot2','dplyr','DT','scales','DBI','RSQLite', \
      'jsonlite','rmarkdown','tidyr','testthat' \
    ), repos = 'https://cloud.r-project.org')"

WORKDIR /srv/shiny-server/app
COPY . /srv/shiny-server/app

# Initialize the (empty) database schema at build time so the image
# starts ready-to-demo. Datasets/analyses are populated as users use the
# app - there's no model-training step to pre-run here, unlike the
# healthcare project's image.
RUN Rscript db/init_db.R --reset

EXPOSE 3838
CMD ["R", "-e", "shiny::runApp('/srv/shiny-server/app/app.R', host='0.0.0.0', port=3838)"]
