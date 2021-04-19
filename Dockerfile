# This is intended to run in Local Development (dev) and Github Actions (test/prod)
# BUILD_ENV options (dev, test, prod) dev for local testing and test for github actions testing on prod ready code
ARG BUILD_ENV="prod"
ARG MAINTAINER="kimn@ssi.dk;"
ARG BIFROST_COMPONENT_NAME="bifrost_cge_virulencefinder"


#---------------------------------------------------------------------------------------------------
# Programs for all environments
#---------------------------------------------------------------------------------------------------
FROM continuumio/miniconda3:4.8.2 as build_base
ONBUILD ARG BIFROST_COMPONENT_NAME
ONBUILD ARG BUILD_ENV
ONBUILD ARG MAINTAINER
ONBUILD LABEL \
    BIFROST_COMPONENT_NAME=${BIFROST_COMPONENT_NAME} \
    description="Docker environment for ${BIFROST_COMPONENT_NAME}" \
    environment="${BUILD_ENV}" \
    maintainer="${MAINTAINER}"
ONBUILD RUN \
    conda install -yq -c conda-forge -c bioconda -c default snakemake-minimal==5.7.1; \
    # For 'make' needed for kma
    apt-get update && apt-get install -y -qq --fix-missing \
        build-essential \
        zlib1g-dev; \
    # install necessary python packages for the program
    pip install -q \
        cgecore==1.5.6 \
        tabulate==0.8.9 \
        biopython==1.78;
# KMA
ONBUILD WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}
ONBUILD RUN \
    # Updated on 21/04/19
    git clone --branch 1.3.14a https://bitbucket.org/genomicepidemiology/kma.git && \
    cd kma && \
    make;
ONBUILD ENV PATH /bifrost/components/${BIFROST_COMPONENT_NAME}/kma:$PATH
# virulencefinder
ONBUILD WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}
ONBUILD RUN \
    git clone --branch 2.0.4 https://bitbucket.org/genomicepidemiology/virulencefinder.git;
ONBUILD ENV PATH /bifrost/components/${BIFROST_COMPONENT_NAME}/virulencefinder:$PATH
#- Tools to install:end ----------------------------------------------------------------------------

#---------------------------------------------------------------------------------------------------
# Base for dev environement
#---------------------------------------------------------------------------------------------------
FROM build_base as build_dev
ONBUILD ARG BIFROST_COMPONENT_NAME
ONBUILD ARG FORCE_DOWNLOAD
ONBUILD COPY /components/${BIFROST_COMPONENT_NAME} /bifrost/components/${BIFROST_COMPONENT_NAME}
ONBUILD WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}/
ONBUILD RUN \
    pip install -r requirements.txt; \
    pip install --no-cache -e file:///bifrost/lib/bifrostlib; \
    pip install --no-cache -e file:///bifrost/components/${BIFROST_COMPONENT_NAME}/

#---------------------------------------------------------------------------------------------------
# Base for production environment
#---------------------------------------------------------------------------------------------------
FROM build_base as build_prod
ONBUILD ARG BIFROST_COMPONENT_NAME
ONBUILD ARG FORCE_DOWNLOAD
ONBUILD WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}
ONBUILD COPY ./ ./
ONBUILD RUN \
    pip install -e file:///bifrost/components/${BIFROST_COMPONENT_NAME}/

#---------------------------------------------------------------------------------------------------
# Base for test environment (prod with tests)
#---------------------------------------------------------------------------------------------------
FROM build_base as build_test
ONBUILD ARG BIFROST_COMPONENT_NAME
ONBUILD ARG FORCE_DOWNLOAD=true
ONBUILD WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}
ONBUILD COPY ./ ./
ONBUILD RUN \
    pip install -r requirements.txt \
    pip install -e file:///bifrost/components/${BIFROST_COMPONENT_NAME}/

#---------------------------------------------------------------------------------------------------
# Additional resources
# NOTE: with dev the resources folder is copied so many resources may already exist and you can skip 
# the download step here. Code has been added for this but it should be made more general and robust
# Right now it is handled with a FORCE_DOWNLOAD variable and a directory check
#---------------------------------------------------------------------------------------------------
FROM build_${BUILD_ENV}
ARG BIFROST_COMPONENT_NAME
ARG FORCE_DOWNLOAD
WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}/resources
RUN \
    git clone https://git@bitbucket.org/genomicepidemiology/virulencefinder_db.git && \
    cd virulencefinder_db && \ 
# Updated on 22/07/20
    git checkout 0479a98 && \ 
    python3 INSTALL.py kma_index;

#---------------------------------------------------------------------------------------------------
# Run and entry commands
#---------------------------------------------------------------------------------------------------
WORKDIR /bifrost/components/${BIFROST_COMPONENT_NAME}
ENTRYPOINT ["python3", "-m", "bifrost_cge_virulencefinder"]
CMD ["python3", "-m", "bifrost_cge_virulencefinder", "--help"]
