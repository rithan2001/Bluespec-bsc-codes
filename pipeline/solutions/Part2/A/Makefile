# This Makefile can be used from each of the Part subdirectories
# For example:    'make s1'

BSC=bsc

# ----------------------------------------------------------------
# Bluesim targets

.PHONY: s1 s2 s3

s1:
	$(BSC)  -sim  -u -g mkTestbench  -show-schedule  Testbench.bsv

s2:
	$(BSC)  -sim  -e mkTestbench  -o testbench.exe  *.ba

s3:
	./testbench.exe  -m 20

# ----------------------------------------------------------------
# Verilog sim targets (note: v2 assumes iverilog)

.PHONY: v1 v2 v3

v1:
	$(BSC)  -verilog  -u -g mkTestbench  -show-schedule  Testbench.bsv

v2:
	$(BSC)  -verilog  -vsim iverilog  -e mkTestbench  -o testbench.exe  *.v

v3:
	./testbench.exe


# ----------------------------------------------------------------
.PHONY: clean fullclean

# Clean all intermediate files
clean:
	rm -f  *~  *.bi  *.bo  *.ba  *.h  *.cxx  *.o

# Clean all intermediate files, plus Verilog files, executables, schedule outputs
fullclean:
	rm -f  *~  *.bi  *.bo  *.ba  *.h  *.cxx  *.o
	rm -f  *.exe   *.so  *.sched  *.v  *.vcd
