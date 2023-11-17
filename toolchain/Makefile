
# Specifies version to install
SJASMPLUS_VERSION := v1.20.3
SJASMPLUS_URL := https://github.com/z00m128/sjasmplus.git

SJASMPLUS_DIR := ./sjasmplus

.PHONY:	all sjasmplus_local clean

all:	sjasmplus_local

clean:
	rm -drf $(SJASMPLUS_DIR)

sjasmplus_local:	$(SJASMPLUS_DIR)/sjasmplus


$(SJASMPLUS_DIR):
	git clone --recursive -b $(SJASMPLUS_VERSION) $(SJASMPLUS_URL) $@

$(SJASMPLUS_DIR)/sjasmplus: | $(SJASMPLUS_DIR)
	$(MAKE) -C $(SJASMPLUS_DIR)


