TARGET=unique


all: $(TARGET)

$(TARGET): main.o
	ld -s ./main.o -o $(TARGET)

main.o: src/*.asm src/*.mac usage.txt
	nasm -felf64 src/main.asm -o main.o

clean:
	rm -rf *.o
	rm $(TARGET)
