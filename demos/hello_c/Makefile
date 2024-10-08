CC := occlum-gcc

.PHONY: all clean

all: hello_world

hello_world: hello_world.c
	$(CC) $^ -o $@ -g

clean:
	rm -rf hello_world
