# Master Makefile to compile all Lua/C++ libraries

CWD= $(shell pwd)
include $(CWD)/Makefile.inc

LUAEXT= lua
ifeq ($(OSTYPE),darwin)
REGEX=\( -regex '.*.$(LUAEXT)' -or -regex '.*.$(SHLIBEXT)' -or -regex '.*.sh' \)
else
REGEX=-regex '.*\($(SHLIBEXT)\|$(LUAEXT)\|sh\)'
endif

CROSS= false

ifndef OSTYPE
  OSTYPE = $(shell uname -s|awk '{print tolower($$0)}')
endif

ifndef ARCH
  ARCH= $(shell uname -m)
endif

ifeq ($(CROSS),true)
  CTCDIR = $(NaoqiCTC)
else
  CTCDIR = 
endif

ifeq ($(CTCDIR),)
  ifeq ($(OSTYPE),linux)
    SHLIBEXT= so
  endif
  else
    SHLIBEXT= so
endif

export CTCDIR

all none:
	@echo "Please do:"
	@echo "\tmake setup_robot"

colortable:
	@echo "Compiling Colortable Mex Files...\n"
	@cd $(COLORTABLEDIR) && make && cd $(CWD)
	@echo "\n"

matlab:
	@echo "Compiling MATLAB Mex Files...\n"
	@cd $(MATLABDIR) && make && cd $(CWD)
	@echo "\n"

robot:
	@echo "Compiling Darwin OP Lua/C++ Libraries...\n"
	@cd $(ROBOTDIR) && make && cd $(CWD)
	@echo "\n"

image:
	@echo "Compiling Image Processing Lua/C++ Libraries...\n"
	@cd $(IMAGEDIR) && make && cd $(CWD)
	@echo "\n"

comm::
	@echo "Compiling Communication Lua/C++ Libraries...\n"
	@cd $(COMMDIR) && make && cd $(CWD)
	@echo "\n"

util::
	@echo "Compiling Utility Lua/C++ Libraries...\n"
	@cd $(UTILDIR) && make && cd $(CWD)
	@echo "\n"

velocity::
	@echo "Compiling Velocity Code...\n"
	@cd $(VELODIR) && make && cd $(CWD)
	@echo "\n"

setup_robot: robot setup_util setup_image setup_comm
	@echo "Setting up Darwin OP Lua/C++ Libraries...\n"
	mkdir -p $(INSTDIR)
	find $(ROBOTDIR) $(REGEX) -exec cp -v {} $(INSTDIR) \;
	@echo "\n"

setup_image: image
	@echo "Setting up Image Processing Lua/C++ Libraries...\n"
	mkdir -p $(INSTDIR)
	find $(IMAGEDIR) $(REGEX) -exec cp -v {} $(INSTDIR) \;
	@echo "\n"

setup_util: util
	@echo "Setting up Utility Lua/C++ Libraries...\n"
	mkdir -p $(INSTDIR)
	find $(UTILDIR) $(REGEX) -exec cp -v {} $(INSTDIR) \;

	@echo "\n"

setup_comm: comm
	@echo "Setting up Communication Lua/C++ Libraries...\n"
	mkdir -p $(INSTDIR)
	find $(COMMDIR) $(REGEX) -exec cp -v {} $(INSTDIR) \;
	@echo "\n"

setup_velocity: velocity
	@echo "Setting up Velocity Lua/C++ Libraries...\n"
	mkdir -p $(INSTDIR)
	find $(VELODIR) $(REGEX) -exec cp -v {} $(INSTDIR) \;
	find $(VELODIR) $(REGEX) -exec cp -v {} $(WEBOTSCONTDIR) \;
#	cp $(VELODIR)/testmodel.xml $(INSTDIR)/../Vision/
	@echo "\n"

clean:
	cd $(IMAGEDIR) && make clean && cd $(CWD)
	cd $(COMMDIR) && make clean && cd $(CWD)
	cd $(UTILDIR) && make clean && cd $(CWD)
	cd $(ROBOTDIR) && make clean && cd $(CWD)
	cd $(PLAYERDIR) && rm -rf Lib && cd $(CWD)
