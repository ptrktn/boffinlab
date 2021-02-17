VENV      = $(HOME)/venv
VENV_PKGS = numpy pandas matplotlib seaborn sklearn tensorflow jupyterlab

.PHONY: all
all: $(VENV) install-venv

$(VENV):
  python3 -m venv $(HOME)/venv

.PHONY: install-venv
install-venv: $(VENV)
	(source $(VENV)/bin/activate && pip install --upgrade pip)
	(source $(VENV)/bin/activate && pip install $(VENV_PKGS))
