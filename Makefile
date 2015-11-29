# ----------------------------------------
# Disciplina: MC404 - 1o semestre de 2015
# Professor: Edson Borin
#
# Descrição: Makefile para o segundo trabalho
# ----------------------------------------

# ----------------------------------
# SOUL object files -- Add your SOUL object files here
SOUL_OBJS=soul.o

# ----------------------------------
# Compiling/Assembling/Linking Tools and flags
AS=arm-eabi-as
AS_FLAGS=-g

CC=arm-eabi-gcc
CC_FLAGS=-g

LD=arm-eabi-ld
LD_FLAGS=-g

# ----------------------------------
# Default rule
all: disk.img

# ----------------------------------
# Generic Rules
%.o: %.s
	$(AS) $(AS_FLAGS) $< -o $@

%.o: %.c
	$(CC) $(CC_FLAGS) -c $< -o $@

# ----------------------------------
# Specific Rules
SOUL.x: $(SOUL_OBJS)
	$(LD) $^ -o $@ $(LD_FLAGS) --section-start=.iv=0x778005e0 -Ttext=0x77800700 -Tdata=0x77801800 -e 0x778005e0

ronda.x: ronda.o bico.o
	$(LD) $^ -o $@ $(LD_FLAGS) -Ttext=0x77802000

disk.img: SOUL.x ronda.x
	mksd.sh --so SOUL.x --user ronda.x

clean:
	rm -f SOUL.x ronda.x segue-parede.x disk.img *.o
	
# ----------------------------------
# Segue-parede

segue-parede.x: segue-parede.o bico.o
	$(LD) $^ -o $@ $(LD_FLAGS) -Ttext=0x77802000

segue-parede: SOUL.x segue-parede.x
	mksd.sh --so SOUL.x --user segue-parede.x
