
all: test

syntax-check:
	ruby -c zengraph.rb

test: syntax-check
	echo no tests yet

run:
	ruby zengraph.rb test.rb

clean:

x:
	ruby test.rb
