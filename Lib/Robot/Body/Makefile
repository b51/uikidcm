# Nothing to compile for NaoBody

all:: dynamixel DspCode

dynamixel::
	cd Dynamixel && make && cd $(CWD)
DspCode::
	cd DspCode && make && cd $(CWD)

clean:
	cd Dynamixel && make clean && cd $(CWD)
	cd DspCode && make clean && cd $(CWD)

