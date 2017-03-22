VFILES=$(wildcard *.v)

cpu : $(VFILES) Makefile
	iverilog -o cpu $(VFILES)

clean :
	rm -rf cpu mem.hex test.ok

test : $(sort $(patsubst %.ok,%,$(wildcard test?.ok)))

test% : cpu mem%.hex
	@echo -n "test$* ... "
	@cp mem$*.hex mem.hex
	@cp test$*.ok test.ok
	@timeout 10 ./cpu > test.raw 2>&1
	-@egrep "^#" test.raw > test.out
	-@egrep "^@" test.raw > test.cycles
	@((diff -b test.out test.ok > /dev/null 2>&1) && echo "pass `cat test.cycles`") || (echo "fail" ; echo "\n\n----------- expected ----------"; cat test.ok ; echo "\n\n------------- found ----------"; cat test.out)
