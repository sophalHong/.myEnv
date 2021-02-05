# Bash is required as the shell
SHELL := /usr/bin/env bash

# Set Makefile directory in variable for referencing other files
MFILECWD = $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
BASHRC ?= $(MFILECWD)shell_profile/bash/mybashrc
ZSHRC ?= $(MFILECWD)shell_profile/zsh/mybashrc
TMUX_DIR ?= $(MFILECWD)tmux
VIM_DIR ?= $(MFILECWD)vim
VIMRC ?= $(HOME)/.vimrc

APT ?= $(shell command -v apt)
YUM ?= $(shell command -v yum)

INSTALLER := $(if $(APT),$(APT),$(YUM))

profile: ## Configure my profile
ifeq (,$(wildcard $(BASHRC)))
	$(error `$(BASHRC)` NOT FOUND)
endif
ifneq (,$(wildcard $(HOME)/.bashrc))
	@grep -q $(BASHRC) $(HOME)/.bashrc && \
		echo "'$(BASHRC)' is already added to '$(HOME)/.bashrc'" || \
		echo "source $(BASHRC)" >> $(HOME)/.bashrc;
	$(info Execute: 'source $(HOME)/.bashrc' to activate my profile)
else
	$(error `$(HOME)/.bashrc` file does NOT exist)
endif

tmux: ## Setup and configure tmux
	@command -v tmux &> /dev/null || sudo $(INSTALLER) install -y tmux
ifneq (,$(wildcard $(HOME)/.tmux.conf))
	@mv $(HOME)/.tmux.conf $(HOME)/.tmux.conf_bak`date +%Y%m%d_%H%M`
endif
ifneq (,$(wildcard $(HOME)/.tmux.conf.local))
	@mv $(HOME)/.tmux.conf.local $(HOME)/.tmux.conf.local_bak`date +%Y%m%d_%H%M`
endif
	@cp -v $(TMUX_DIR)/tmux.conf $(HOME)/.tmux.conf
	@cp -v $(TMUX_DIR)/tmux.conf.local $(HOME)/.tmux.conf.local

vimrc: ## Setup and configure vim
	@command -v vim &> /dev/null || sudo $(INSTALLER) install -y vim
ifneq (,$(wildcard $(HOME)/.vim/.*))
	@mv $(HOME)/.vim $(HOME)/.vim_bak`date +%Y%m%d_%H%M`
endif
ifneq (,$(wildcard $(HOME)/.vimrc))
	@mv $(HOME)/.vimrc $(HOME)/.vimrc_bak`date +%Y%m%d_%H%M`
endif
	@mkdir -p $(HOME)/.vim
	@cp -v $(VIM_DIR)/vimrc_basic $(VIMRC)

vim-plug: ## Get and install vim-plug
	@command -v curl &> /dev/null || sudo $(INSTALLER) install -y curl
	$(eval PLUG-VIM := $(HOME)/.vim/autoload/plug.vim)
	@test -f $(PLUG-VIM) || curl -fLo $(PLUG-VIM) --create-dirs \
		https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	@command -v sed &> /dev/null || sudo $(INSTALLER) install -y sed
	@grep -q '^call plug#begin' $(VIMRC) || \
		sed -i "1icall plug#begin('~/.vim/plugged')\ncall plug#end()\n" $(VIMRC)

vim-install-plugin: vim-plug ## Add nerdtree vim-plug
ifndef PLUGIN
	$(error Pluging 'PLUGIN=<name>' is NOT provided!)
endif
	@grep -q '^call plug#begin' $(VIMRC) || $(MAKE) vim-plug;
	$(eval LINE := $(shell awk '/^call plug#begin/{print NR; exit}' $(VIMRC)))
	@if [ "$(LINE)" == "" ]; then \
		echo "[ERROR] Cannot get find call plug\#being() function in '$(VIMRC)'"; \
		exit 1; \
	fi
	@if grep -q "^Plug '$(PLUGIN)'" $(VIMRC); then \
		echo "[INFO] vim plugin '$(PLUGIN)' is already installed!"; \
	else \
		command -v sed &> /dev/null || sudo $(INSTALLER) install -y sed; \
		sed -i "$(LINE) a Plug '$(PLUGIN)'" $(VIMRC); \
		vim +slient +VimEnter +PlugInstall +qall; \
		echo "[INFO] vim plugin '$(PLUGIN)' is successfully installed!"; \
	fi

vim-nerdtree: ## Install 'nerdtree' vim-plug
	$(eval NAME := preservim/nerdtree)
	$(eval MAPPING := Mapping Ctrl+i to NERDTreeToggle)
	@PLUGIN=$(NAME) $(MAKE) vim-install-plugin --no-print-directory
	@if ! grep -q '$(MAPPING)' $(VIMRC); then \
		echo "[INFO] $(MAPPING)"; \
		echo -e '\n"$(MAPPING)' >> $(VIMRC); \
		echo 'autocmd VimEnter * if exists(":NERDTreeToggle") | exe "map <C-i> :NERDTreeToggle<CR>" | endif' >> $(VIMRC); \
	fi

vim-tagbar: ## Install 'tagbar' vim-plug
	@command -v ctags-exuberant &> /dev/null || sudo $(INSTALLER) install exuberant-ctags -y
	$(eval NAME := preservim/tagbar)
	$(eval MAPPING := Mapping <space> to TagbarToggle)
	@PLUGIN=$(NAME) $(MAKE) vim-install-plugin --no-print-directory
	@if ! grep -q '$(MAPPING)' $(VIMRC); then \
		echo "[INFO] $(MAPPING)"; \
		echo -e '\n"$(MAPPING)' >> $(VIMRC); \
		echo 'autocmd VimEnter * if exists(":TagbarToggle") | exe "nnoremap <Space> :TagbarToggle<CR>" | endif' >> $(VIMRC); \
	fi

help: ## Show this help menu.
	@echo "Usage: make [TARGET ...]"
	@echo
	@grep -E '^[a-zA-Z_%-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
.EXPORT_ALL_VARIABLES:
.PHONY: help profile tmux vim vim-plug
