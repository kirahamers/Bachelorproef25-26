FROM debian:bullseye

RUN apt-get update && apt-get install -y --fix-missing \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-lang-european \
    texlive-bibtex-extra \
    biber \
    git \
    texlive-xetex \
    python3-pip \
    latexmk \
    && pip3 install pygments \
    && ln -s /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

COPY fonts/ /usr/share/fonts/opentype
RUN fc-cache -f -v