BOFFIN    = boffin
VENV      = $(HOME)/venv
VENV_PKGS = numpy pandas matplotlib seaborn sklearn jupyterlab \
            sqlalchemy mysql-connector-python psycopg2-binary

.PHONY: all
all: $(VENV) install-venv configure-services doc

$(VENV):
	python3 -m venv $(HOME)/venv

.PHONY: install-venv
install-venv: $(VENV)
	(. $(VENV)/bin/activate && pip install --upgrade pip)
	(. $(VENV)/bin/activate && pip install $(VENV_PKGS))

$(HOME)/.jupyter/jupyter_lab_config.py: Makefile
	install -d $(HOME)/.jupyter
	( echo "c.NotebookApp.ip = '*'" ; \
	echo "c.ServerApp.open_browser = False" ; \
	echo "c.ExtensionApp.open_browser = False" ; \
	echo "c.ServerApp.password = 'sha1:b84766345c0a:919e47d306a5dccf1b4647dfaff2a14e79b9ed8c'" ; \
	echo "c.ServerApp.password_required = True" ) > $@

$(HOME)/.config/systemd/user/jupyter.service: Makefile
	install -d $(HOME)/.config/systemd/user/default.target.wants
	( echo "[Unit]" ; \
	echo "Description=Jupyter Notebook" ; \
	echo "[Service]" ; \
	echo "Type=simple" ; \
	echo "ExecStart=_@@@VENV@@@_/bin/jupyter-lab" ; \
	echo "[Install]" ; \
	echo "WantedBy=default.target" ) > $@

.PHONY: configure-irkernel
configure-irkernel:
	(. $(VENV)/bin/activate && R -e "IRkernel::installspec()" )

.PHONY: configure-services
configure-services: \
	$(HOME)/.config/systemd/user/jupyter.service \
	$(HOME)/.jupyter/jupyter_lab_config.py \
	configure-irkernel
	sed -i "s:_@@@VENV@@@_:$(VENV):g" $(HOME)/.config/systemd/user/jupyter.service
	rm -f $(HOME)/.config/systemd/user/default.target.wants/jupyter.service
	ln -s $(HOME)/.config/systemd/user/jupyter.service $(HOME)/.config/systemd/user/default.target.wants/jupyter.service

.PHONY: start-services
start-services:
	systemctl --user stop jupyter.service
	systemctl --user start jupyter.service

.PHONY: doc
doc: $(HOME)/Documents/boffinlab/1805.05052.pdf

$(HOME)/Documents/boffinlab/1805.05052.pdf:
	mkdir -p $(HOME)/Documents/boffinlab
	curl -sL https://arxiv.org/pdf/1805.05052 > $@

.PHONY: deps
deps:
	test "0" = "`id -u`"
	apt-get install -y openssh-server python3-pip python3-venv \
	    mariadb-client postgresql-client libmariadb-dev \
        texlive texlive-latex-recommended texlive-xetex \
        emacs gnuplot rsync curl wget git screen \
        dpkg-sig libclang-dev dirmngr apt-transport-https ca-certificates \
        software-properties-common gnupg2 libxml2-dev \
        libcurl4-openssl-dev libidn11-dev libkrb5-dev libldap2-dev \
        librtmp-devlibssh2-1-dev
	mkdir -p /var/lib/systemd/linger
	touch /var/lib/systemd/linger/$(BOFFIN)
	sed -i.orig -e 's/.*KillUserProcesses=.*/KillUserProcesses=no/g' /etc/systemd/logind.conf
	sed -i.orig -e 's/.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
	apt-key adv --keyserver keys.gnupg.net --recv-key 'E19F5F87128899B192B1A2C2AD5F960A256A04AF'
	add-apt-repository 'deb http://cloud.r-project.org/bin/linux/debian bullseye-cran40/'
	apt-get update || /bin/true
	apt-get install -y -t bullseye-cran40 r-base
	R -e "install.packages('IRkernel')"
	R -e "install.packages('RMariaDB')"
	R -e "install.packages('curl')"
	R -e "install.packages('R.methodsS3')"
	R -e "install.packages('R.oo')"
	R -e "install.packages('R.utils')"
	R -e "install.packages('fastmap')"
	R -e "install.packages('sourcetools')"
	R -e "install.packages('xtable')"
	R -e "install.packages('httpuv')"
	R -e "install.packages('shiny')"
	R -e "install.packages('shinyjs')"
	R -e "install.packages('miniUI')"
	R -e "install.packages('testthat')"
	R -e "install.packages('httr')"
	R -e "install.packages('devtools')"
	R -e "devtools::install_github('testmycode/tmc-r-tester/tmcRtestrunner')"
	R -e "devtools::install_github('testmycode/tmc-rstudio/tmcrstudioaddin')"
	gpg --keyserver keys.gnupg.net --recv-keys 3F32EE77E331692F
	cd /tmp && curl -sLf -O https://download1.rstudio.org/desktop/bionic/amd64/rstudio-1.4.1103-amd64.deb && dpkg-sig --verify rstudio-1.4.1103-amd64.deb && dpkg -i rstudio-1.4.1103-amd64.deb
	cd /tmp && curl -sLf -O https://download2.rstudio.org/server/bionic/amd64/rstudio-server-1.4.1103-amd64.deb && dpkg-sig --verify rstudio-server-1.4.1103-amd64.deb && dpkg -i rstudio-server-1.4.1103-amd64.deb
