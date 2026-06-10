# =============================================================================
# Makefile for strreplace
# =============================================================================

.PHONY: all install test clean

# Installation target directory
PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin

all:
	@echo "Available commands:"
	@echo "  make install  - Install strreplace.sh to $(BINDIR)/strreplace"
	@echo "  make test     - Run test suite"

install:
	@echo "Installing strreplace to $(BINDIR)..."
	mkdir -p "$(BINDIR)"
	install -m 0755 strreplace.sh "$(BINDIR)/strreplace"
	@echo "Installation successful. Please ensure $(BINDIR) is in your PATH."

test:
	@echo "Running tests..."
	./test_strreplace.sh

clean:
	@echo "Nothing to clean."
